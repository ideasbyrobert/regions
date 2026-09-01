import AppKit
import CoreGraphics
import Foundation

@MainActor
final class EdgeSnapService
{
    private let preferences: AppPreferences
    private let authorization: AccessibilityAuthorizationService
    private let displayProvider: DisplaySnapshotProvider
    private let calculator: any LayoutCalculating
    private let windowManager: any WindowManaging
    private let onResult: @MainActor (MoveResult) -> Void
    private let resolver = EdgeSnapResolver()
    private let footprintController = FootprintPanelController()
    private var monitor: Any?
    private var captureIdentifier = UUID()
    private var trackedWindow: ManagedWindowSnapshot?
    private var latestWindow: ManagedWindowSnapshot?
    private var candidate: EdgeSnapCandidate?
    private var pendingLocation: CGPoint?
    private var isMouseDown = false
    private var isRefreshing = false
    private var didMoveWindow = false
    private var dragScreens: [ScreenSnapshot] = []
    private var lastRefreshInstant: ContinuousClock.Instant?
    private var refreshTask: Task<Void, Never>?
    private var refreshIdentifier = UUID()

    init(
        preferences: AppPreferences,
        authorization: AccessibilityAuthorizationService,
        displayProvider: DisplaySnapshotProvider,
        calculator: any LayoutCalculating,
        windowManager: any WindowManaging,
        onResult: @escaping @MainActor (MoveResult) -> Void
    )
    {
        self.preferences = preferences
        self.authorization = authorization
        self.displayProvider = displayProvider
        self.calculator = calculator
        self.windowManager = windowManager
        self.onResult = onResult
    }

    func start()
    {
        guard monitor == nil
        else
        {
            return
        }
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        )
        {
            [weak self] event in
            Task
            {
                @MainActor in
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: NSEvent)
    {
        let location = NSEvent.mouseLocation
        switch event.type
        {
        case .leftMouseDown:
            begin(at: location)
        case .leftMouseDragged:
            update(at: location)
        case .leftMouseUp:
            finish(at: location)
        default:
            break
        }
    }

    private func begin(at location: CGPoint)
    {
        reset()
        guard preferences.edgeSnappingEnabled,
              authorization.isTrusted
        else
        {
            return
        }
        isMouseDown = true
        dragScreens = displayProvider.snapshots()
        let identifier = UUID()
        captureIdentifier = identifier
        let converter = currentConverter()
        Task
        {
            [weak self] in
            guard let self
            else
            {
                return
            }
            let result = await windowManager.captureStandardWindow(
                at: location,
                converter: converter
            )
            guard isMouseDown,
                  captureIdentifier == identifier,
                  case .captured(let window) = result
            else
            {
                return
            }
            trackedWindow = window
            latestWindow = window
            refreshIfNeeded()
        }
    }

    private func update(at location: CGPoint)
    {
        guard isMouseDown,
              preferences.edgeSnappingEnabled
        else
        {
            return
        }
        pendingLocation = location
        refreshIfNeeded()
    }

    private func refreshIfNeeded()
    {
        guard !isRefreshing,
              let trackedWindow,
              pendingLocation != nil
        else
        {
            return
        }
        isRefreshing = true
        let converter = currentConverter()
        let earliestRefresh = lastRefreshInstant?.advanced(by: .milliseconds(33))
        let identifier = UUID()
        refreshIdentifier = identifier
        refreshTask = Task
        {
            [weak self] in
            guard let self
            else
            {
                return
            }
            if let earliestRefresh
            {
                try? await ContinuousClock().sleep(until: earliestRefresh)
            }
            guard !Task.isCancelled,
                  refreshIdentifier == identifier
            else
            {
                completeRefresh(identifier: identifier)
                return
            }
            let result = await windowManager.snapshot(
                for: trackedWindow.token,
                converter: converter
            )
            guard isMouseDown,
                  self.trackedWindow?.token == trackedWindow.token,
                  refreshIdentifier == identifier
            else
            {
                completeRefresh(identifier: identifier)
                return
            }
            if case .captured(let window) = result
            {
                latestWindow = window
                let deltaX = window.frame.minX - trackedWindow.frame.minX
                let deltaY = window.frame.minY - trackedWindow.frame.minY
                if hypot(deltaX, deltaY) >= 4
                {
                    didMoveWindow = true
                }
            }
            let location = pendingLocation
            pendingLocation = nil
            lastRefreshInstant = ContinuousClock.now
            completeRefresh(identifier: identifier)
            if let location
            {
                updateCandidate(at: location)
            }
            if pendingLocation != nil
            {
                refreshIfNeeded()
            }
        }
    }

    private func updateCandidate(at location: CGPoint)
    {
        guard didMoveWindow,
              let latestWindow,
              let screen = displayProvider.screen(
                  containing: location,
                  in: dragScreens
              ),
              let zone = resolver.zone(at: location, on: screen, threshold: 24)
        else
        {
            if candidate != nil
            {
                candidate = nil
                footprintController.hide()
            }
            return
        }
        let nextCandidate = EdgeSnapCandidate(zone: zone, screen: screen)
        guard candidate != nextCandidate
        else
        {
            return
        }
        candidate = nextCandidate
        guard preferences.showsPreview
        else
        {
            footprintController.hide()
            return
        }
        let target = calculator.target(
            for: .preset(zone.preset),
            on: screen,
            currentWindowFrame: latestWindow.frame,
            spacing: preferences.spacing
        )
        footprintController.show(frame: target.frame)
    }

    private func finish(at location: CGPoint)
    {
        guard isMouseDown
        else
        {
            return
        }
        isMouseDown = false
        captureIdentifier = UUID()
        footprintController.hide()
        guard let trackedWindow
        else
        {
            reset()
            return
        }
        let converter = currentConverter()
        let spacing = preferences.spacing
        let hadVerifiedMovement = didMoveWindow
        let screens = dragScreens
        reset()
        Task
        {
            [weak self] in
            guard let self
            else
            {
                return
            }
            try? await Task.sleep(for: .milliseconds(40))
            let snapshotResult = await windowManager.snapshot(
                for: trackedWindow.token,
                converter: converter
            )
            guard case .captured(let window) = snapshotResult
            else
            {
                return
            }
            let deltaX = window.frame.minX - trackedWindow.frame.minX
            let deltaY = window.frame.minY - trackedWindow.frame.minY
            guard hadVerifiedMovement || hypot(deltaX, deltaY) >= 4,
                  let screen = displayProvider.screen(
                      containing: location,
                      in: screens
                  ),
                  let zone = resolver.zone(at: location, on: screen, threshold: 24)
            else
            {
                return
            }
            let command = LayoutCommand.preset(zone.preset)
            let target = calculator.target(
                for: command,
                on: screen,
                currentWindowFrame: window.frame,
                spacing: spacing
            )
            let result = await windowManager.apply(
                target: target,
                to: trackedWindow.token,
                converter: converter,
                command: command,
                historyPreviousFrame: trackedWindow.frame
            )
            onResult(result)
        }
    }

    private func reset()
    {
        captureIdentifier = UUID()
        trackedWindow = nil
        latestWindow = nil
        candidate = nil
        pendingLocation = nil
        isMouseDown = false
        isRefreshing = false
        didMoveWindow = false
        dragScreens = []
        lastRefreshInstant = nil
        refreshIdentifier = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        footprintController.hide()
    }

    private func completeRefresh(identifier: UUID)
    {
        guard refreshIdentifier == identifier
        else
        {
            return
        }
        isRefreshing = false
        refreshTask = nil
    }

    private func currentConverter() -> ScreenCoordinateConverter
    {
        ScreenCoordinateConverter(
            primaryDisplayMaximumY: displayProvider.primaryDisplayMaximumY()
        )
    }
}
