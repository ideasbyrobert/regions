import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class AppController: ObservableObject
{
    static let shared = AppController()

    @Published private(set) var statusMessage: String?
    @Published private(set) var shortcutErrorMessage: String?
    @Published private(set) var batchArrangementAvailability = BatchArrangementAvailability.checking
    @Published private(set) var savedLayoutSlots = Set<Int>()

    let preferences = AppPreferences.shared
    let authorization = AccessibilityAuthorizationService()
    let launchAtLogin = LaunchAtLoginService()
    let terminalWindowSizing = TerminalWindowSizingService()
    let desktopVisibility = DesktopVisibilityService()
    let updates = UpdateController()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.ideasbyrobert.Regions",
        category: "Commands"
    )
    private let tracker = TargetWindowTracker()
    private let displayProvider = DisplaySnapshotProvider()
    private let calculator: any LayoutCalculating = GridLayoutCalculator()
    private let transferCalculator = DisplayTransferCalculator()
    private let windowManager: any WindowManaging = AccessibilityWindowActor()
    private let hotKeyService = HotKeyService()
    private let savedAppLayoutStore = SavedAppLayoutStore()
    private lazy var paletteController = PaletteController(
        calculator: calculator,
        preferences: preferences
    )
    private lazy var balancedWindowArrangementService = BalancedWindowArrangementService(
        windowManager: windowManager,
        terminalWindowSizing: terminalWindowSizing,
        calculator: calculator
    )
    private lazy var displayWindowManagementService = DisplayWindowManagementService(
        windowManager: windowManager,
        displayProvider: displayProvider,
        calculator: calculator,
        transferCalculator: transferCalculator
    )
    private lazy var permissionWindowController = PermissionWindowController(
        authorization: authorization
    )
    private lazy var edgeSnapService = EdgeSnapService(
        preferences: preferences,
        authorization: authorization,
        displayProvider: displayProvider,
        calculator: calculator,
        windowManager: windowManager,
        onResult:
        {
            [weak self] result in
            self?.handle(result)
        }
    )
    private var isStarted = false
    private var availabilityRequestIdentifier = UUID()
    private var availabilityTask: Task<Void, Never>?
    private var availabilityProcessIdentifier: pid_t?
    private var availabilityRefreshInstant: ContinuousClock.Instant?

    private init()
    {
    }

    func start()
    {
        guard !isStarted
        else
        {
            return
        }
        isStarted = true
        tracker.start()
        if let targetBundleIdentifier = liveUITestTargetBundleIdentifier,
           let targetApplication = NSRunningApplication.runningApplications(
               withBundleIdentifier: targetBundleIdentifier
           ).first
        {
            tracker.pinTargetApplicationForTesting(targetApplication)
        }
        authorization.refresh()
        if isUITesting
        {
            preferences.gridDimension = .three
            preferences.spacing = 8
            preferences.showsPreview = false
            preferences.adjustmentStep = 40
            preferences.edgeSnappingEnabled = false
        }
        registerPaletteShortcut(preferences.paletteShortcut)
        edgeSnapService.start()
        logger.info("Application services started")

        if isLiveArrangementUITesting
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)
            {
                self.arrangeAllWindowsFourByTwo()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3)
            {
                self.restorePreviousFrame()
            }
        }

        if isLiveDisplayTransferUITesting
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)
            {
                self.moveAppWindowsToNextDisplay()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3)
            {
                self.restorePreviousFrame()
            }
        }

        if isPaletteUITesting
        {
            DispatchQueue.main.async
            {
                self.presentUITestPalette()
            }
        }
        else if isPermissionUITesting
        {
            DispatchQueue.main.async
            {
                self.showPermissionWindow()
            }
        }
        else if !authorization.isTrusted && !isUITesting
        {
            showPermissionWindow()
        }
    }

    func openPalette()
    {
        Task
        {
            [self] in
            guard let snapshot = await captureTargetWindow(),
                  let screen = currentScreen(for: snapshot)
            else
            {
                return
            }
            let session = PaletteSession(window: snapshot, screen: screen)
            paletteController.present(session: session)
            {
                [weak self] command, session in
                self?.apply(command, to: session)
            }
            logger.info("Presented layout palette")
        }
    }

    func applyPreset(_ preset: LayoutPreset)
    {
        applyLayoutCommand(.preset(preset))
    }

    func moveWindow(_ position: WindowMovePosition)
    {
        applyLayoutCommand(.move(position))
    }

    func applyAdjustment(_ adjustment: WindowAdjustment)
    {
        applyLayoutCommand(.adjustment(
            adjustment,
            amount: preferences.adjustmentStep
        ))
    }

    func performWindowAction(_ action: WindowLifecycleAction)
    {
        Task
        {
            guard let snapshot = await captureTargetWindowForLifecycle()
            else
            {
                return
            }
            let result = await windowManager.perform(
                action,
                on: snapshot.token,
                converter: currentConverter()
            )
            handle(result, action: action)
        }
    }

    func focusAppWindow(_ direction: WindowFocusDirection)
    {
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            statusMessage = MoveFailure.accessibilityPermissionRequired.message
            showPermissionWindow()
            return
        }
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            statusMessage = MoveFailure.noTargetApplication.message
            return
        }
        let converter = currentConverter()
        Task
        {
            [self] in
            let windowResult = await windowManager.captureStandardWindows(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard case .success(let windows) = windowResult,
                  windows.count > 1
            else
            {
                statusMessage = "No other app window is available."
                return
            }
            let focusedResult = await windowManager.captureFocusedWindowForLifecycle(
                processIdentifier: processIdentifier,
                converter: converter
            )
            let focusedToken: ManagedWindowToken?
            if case .captured(let focusedWindow) = focusedResult
            {
                focusedToken = focusedWindow.token
            }
            else
            {
                focusedToken = nil
            }
            let currentIndex = windows.firstIndex(where:
            {
                $0.token == focusedToken
            }) ?? 0
            let targetIndex: Int
            switch direction
            {
            case .previous:
                targetIndex = currentIndex == 0 ? windows.count - 1 : currentIndex - 1
            case .next:
                targetIndex = currentIndex == windows.count - 1 ? 0 : currentIndex + 1
            }
            let result = await windowManager.perform(
                .bringToFront,
                on: windows[targetIndex].token,
                converter: converter
            )
            if case .completed = result
            {
                NSRunningApplication(processIdentifier: processIdentifier)?.activate(
                    options: [.activateAllWindows]
                )
            }
            handle(result, action: .bringToFront)
        }
    }

    func refreshBatchArrangementAvailability()
    {
        if let batchWindowCountOverride
        {
            let updatedAvailability = availability(
                forWindowCount: batchWindowCountOverride
            )
            if batchArrangementAvailability != updatedAvailability
            {
                batchArrangementAvailability = updatedAvailability
            }
            return
        }
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            cancelAvailabilityRefresh()
            let updatedAvailability = BatchArrangementAvailability.unavailable(
                .accessibilityPermissionRequired
            )
            if batchArrangementAvailability != updatedAvailability
            {
                batchArrangementAvailability = updatedAvailability
            }
            return
        }
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            cancelAvailabilityRefresh()
            let updatedAvailability = BatchArrangementAvailability.unavailable(
                .noTargetApplication
            )
            if batchArrangementAvailability != updatedAvailability
            {
                batchArrangementAvailability = updatedAvailability
            }
            return
        }
        let now = ContinuousClock.now
        if availabilityProcessIdentifier == processIdentifier,
           availabilityTask != nil
        {
            return
        }
        if availabilityProcessIdentifier == processIdentifier,
           let availabilityRefreshInstant,
           now - availabilityRefreshInstant < .seconds(1)
        {
            return
        }
        cancelAvailabilityRefresh()
        let requestIdentifier = UUID()
        availabilityRequestIdentifier = requestIdentifier
        if availabilityProcessIdentifier != processIdentifier
        {
            batchArrangementAvailability = .checking
        }
        availabilityProcessIdentifier = processIdentifier
        let converter = currentConverter()
        availabilityTask = Task
        {
            [weak self] in
            guard let self
            else
            {
                return
            }
            defer
            {
                if availabilityRequestIdentifier == requestIdentifier
                {
                    availabilityTask = nil
                }
            }
            guard !Task.isCancelled,
                  availabilityRequestIdentifier == requestIdentifier
            else
            {
                return
            }
            let result = await windowManager.captureStandardWindows(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard !Task.isCancelled,
                  availabilityRequestIdentifier == requestIdentifier
            else
            {
                return
            }
            availabilityRefreshInstant = ContinuousClock.now
            let updatedAvailability = availability(for: result)
            if batchArrangementAvailability != updatedAvailability
            {
                batchArrangementAvailability = updatedAvailability
            }
        }
    }

    func arrangeAllWindowsFourByTwo()
    {
        let requestIdentifier = UUID()
        cancelAvailabilityRefresh()
        availabilityRequestIdentifier = requestIdentifier
        batchArrangementAvailability = .checking
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            let failure = MoveFailure.accessibilityPermissionRequired
            batchArrangementAvailability = .unavailable(failure)
            statusMessage = failure.message
            showPermissionWindow()
            return
        }
        guard let processIdentifier = tracker.processIdentifier,
              let bundleIdentifier = targetBundleIdentifier
        else
        {
            let failure = MoveFailure.noTargetApplication
            batchArrangementAvailability = .unavailable(failure)
            statusMessage = failure.message
            return
        }
        let converter = currentConverter()
        Task
        {
            [self] in
            let focusedResult = await windowManager.captureFocusedWindow(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard case .captured(let focusedWindow) = focusedResult,
                  let screen = currentScreen(for: focusedWindow)
            else
            {
                if case .failed(let failure) = focusedResult
                {
                    batchArrangementAvailability = .unavailable(failure)
                    statusMessage = failure.message
                }
                return
            }
            let result = await balancedWindowArrangementService.arrange(
                processIdentifier: processIdentifier,
                bundleIdentifier: bundleIdentifier,
                targetScreen: screen,
                spacing: preferences.spacing,
                converter: converter
            )
            guard availabilityRequestIdentifier == requestIdentifier
            else
            {
                return
            }
            handle(result)
        }
    }

    func arrangeAllWindowsThreeByTwo()
    {
        let requestIdentifier = UUID()
        cancelAvailabilityRefresh()
        availabilityRequestIdentifier = requestIdentifier
        batchArrangementAvailability = .checking
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            let failure = MoveFailure.accessibilityPermissionRequired
            batchArrangementAvailability = .unavailable(failure)
            statusMessage = failure.message
            showPermissionWindow()
            return
        }
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            let failure = MoveFailure.noTargetApplication
            batchArrangementAvailability = .unavailable(failure)
            statusMessage = failure.message
            return
        }
        let converter = currentConverter()
        Task
        {
            [self] in
            let focusedResult = await windowManager.captureFocusedWindow(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard case .captured(let focusedWindow) = focusedResult,
                  let screen = currentScreen(for: focusedWindow)
            else
            {
                if case .failed(let failure) = focusedResult
                {
                    batchArrangementAvailability = .unavailable(failure)
                    statusMessage = failure.message
                }
                return
            }
            let result = await balancedWindowArrangementService.arrangeThreeByTwo(
                processIdentifier: processIdentifier,
                targetScreen: screen,
                spacing: preferences.spacing,
                converter: converter
            )
            guard availabilityRequestIdentifier == requestIdentifier
            else
            {
                return
            }
            handle(result)
        }
    }

    func refreshSavedLayoutSlots()
    {
        guard let bundleIdentifier = targetBundleIdentifier
        else
        {
            savedLayoutSlots = []
            return
        }
        savedLayoutSlots = savedAppLayoutStore.slots(bundleIdentifier: bundleIdentifier)
    }

    func saveAppLayout(slot: Int)
    {
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            statusMessage = MoveFailure.accessibilityPermissionRequired.message
            showPermissionWindow()
            return
        }
        guard let processIdentifier = tracker.processIdentifier,
              let bundleIdentifier = targetBundleIdentifier
        else
        {
            statusMessage = MoveFailure.noTargetApplication.message
            return
        }
        let converter = currentConverter()
        Task
        {
            [self] in
            let focusedResult = await windowManager.captureFocusedWindow(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard case .captured(let focusedWindow) = focusedResult,
                  let screen = currentScreen(for: focusedWindow)
            else
            {
                statusMessage = "A focused standard window is required."
                return
            }
            let windowsResult = await windowManager.captureStandardWindows(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard case .success(let capturedWindows) = windowsResult
            else
            {
                statusMessage = MoveFailure.noManageableWindows.message
                return
            }
            let screens = displayProvider.snapshots()
            var windows = capturedWindows.filter
            {
                displayProvider.screen(containing: $0.frame, in: screens)?.displayID
                    == screen.displayID
            }
            if let focusedIndex = windows.firstIndex(where:
            {
                $0.token == focusedWindow.token
            })
            {
                windows.remove(at: focusedIndex)
                windows.insert(focusedWindow, at: 0)
            }
            guard !windows.isEmpty
            else
            {
                statusMessage = MoveFailure.noManageableWindows.message
                return
            }
            let layout = SavedAppLayout(
                bundleIdentifier: bundleIdentifier,
                slot: slot,
                windowFrames: windows.map
                {
                    SavedWindowFrame(frame: $0.frame, within: screen.visibleFrame)
                }
            )
            savedAppLayoutStore.save(layout)
            refreshSavedLayoutSlots()
            statusMessage = "Saved \(windows.count) window positions in slot \(slot)."
        }
    }

    func restoreAppLayout(slot: Int)
    {
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            statusMessage = MoveFailure.accessibilityPermissionRequired.message
            showPermissionWindow()
            return
        }
        guard let processIdentifier = tracker.processIdentifier,
              let bundleIdentifier = targetBundleIdentifier,
              let layout = savedAppLayoutStore.layout(
                  bundleIdentifier: bundleIdentifier,
                  slot: slot
              )
        else
        {
            statusMessage = "No saved layout is available in slot \(slot) for this app."
            return
        }
        let converter = currentConverter()
        Task
        {
            [self] in
            let focusedResult = await windowManager.captureFocusedWindow(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard case .captured(let focusedWindow) = focusedResult,
                  let screen = currentScreen(for: focusedWindow)
            else
            {
                statusMessage = "A focused standard window is required."
                return
            }
            let windowsResult = await windowManager.captureStandardWindows(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard case .success(let capturedWindows) = windowsResult
            else
            {
                statusMessage = MoveFailure.noManageableWindows.message
                return
            }
            let screens = displayProvider.snapshots()
            var windows = capturedWindows.filter
            {
                displayProvider.screen(containing: $0.frame, in: screens)?.displayID
                    == screen.displayID
            }
            if let focusedIndex = windows.firstIndex(where:
            {
                $0.token == focusedWindow.token
            })
            {
                windows.remove(at: focusedIndex)
                windows.insert(focusedWindow, at: 0)
            }
            guard windows.count == layout.windowFrames.count
            else
            {
                statusMessage = "Slot \(slot) expects \(layout.windowFrames.count) windows; this display has \(windows.count)."
                return
            }
            let requests = zip(windows, layout.windowFrames).map
            {
                window, savedFrame in
                WindowPlacementRequest(
                    token: window.token,
                    target: savedFrame.target(on: screen),
                    historyPreviousFrame: window.frame,
                    command: nil
                )
            }
            let result = await windowManager.applyBatch(
                requests,
                terminalState: nil,
                converter: converter
            )
            switch result
            {
            case .moved:
                statusMessage = "Restored \(windows.count) windows from slot \(slot)."
            case .bestEffort:
                statusMessage = "Restored slot \(slot) with window size limits."
            case .failed(let failure):
                statusMessage = failure.message
            }
        }
    }

    func deleteAppLayout(slot: Int)
    {
        guard let bundleIdentifier = targetBundleIdentifier
        else
        {
            statusMessage = MoveFailure.noTargetApplication.message
            return
        }
        savedAppLayoutStore.remove(bundleIdentifier: bundleIdentifier, slot: slot)
        refreshSavedLayoutSlots()
        statusMessage = "Deleted saved layout slot \(slot)."
    }

    func moveToPreviousDisplay()
    {
        moveToDisplay(.previous)
    }

    func moveToNextDisplay()
    {
        moveToDisplay(.next)
    }

    func gatherAppWindowsOnFocusedDisplay()
    {
        moveAppWindows(to: nil)
    }

    func moveAppWindowsToPreviousDisplay()
    {
        moveAppWindows(to: .previous)
    }

    func moveAppWindowsToNextDisplay()
    {
        moveAppWindows(to: .next)
    }

    func swapWindowsBetweenDisplays()
    {
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            statusMessage = MoveFailure.accessibilityPermissionRequired.message
            showPermissionWindow()
            return
        }
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            statusMessage = MoveFailure.noTargetApplication.message
            return
        }
        let converter = currentConverter()
        Task
        {
            [self] in
            let screens = displayProvider.snapshots()
            let result = await displayWindowManagementService.swapAppWindows(
                processIdentifier: processIdentifier,
                screens: screens,
                spacing: preferences.spacing,
                converter: converter
            )
            handle(result)
        }
    }

    func showOrRestoreDesktop()
    {
        let result = desktopVisibility.isDesktopShown
            ? desktopVisibility.restoreDesktop()
            : desktopVisibility.showDesktop()
        handle(result)
    }

    func undoLastMove()
    {
        Task
        {
            let result = await balancedWindowArrangementService.restorePrevious(
                converter: currentConverter()
            )
            handle(result)
        }
    }

    func restorePreviousFrame()
    {
        undoLastMove()
    }

    func showPermissionWindow()
    {
        authorization.refresh()
        permissionWindowController.present()
    }

    func updatePaletteShortcut(_ shortcut: KeyboardShortcut)
    {
        let previousShortcut = preferences.paletteShortcut
        let result = hotKeyService.register(shortcut)
        {
            [weak self] in
            self?.openPalette()
        }
        switch result
        {
        case .registered:
            preferences.setPaletteShortcut(shortcut)
            shortcutErrorMessage = nil
        case .conflict:
            shortcutErrorMessage = "That shortcut is already in use."
            registerPaletteShortcut(previousShortcut)
        case .failed(let status):
            shortcutErrorMessage = "Shortcut registration failed with status \(status)."
            registerPaletteShortcut(previousShortcut)
        }
    }

    func showAbout()
    {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func quit()
    {
        NSApp.terminate(nil)
    }

    private func moveToDisplay(_ direction: DisplayDirection)
    {
        Task
        {
            guard let snapshot = await captureTargetWindow()
            else
            {
                return
            }
            let screens = displayProvider.snapshots()
            guard let source = displayProvider.screen(containing: snapshot.frame, in: screens),
                  let destination = displayProvider.adjacent(
                      to: source,
                      direction: direction,
                      in: screens
                  )
            else
            {
                statusMessage = screens.count < 2
                    ? "No other display is connected."
                    : MoveFailure.noDisplays.message
                return
            }

            let command = await windowManager.lastCommand(for: snapshot.token)
            let target: LayoutTarget
            if let command
            {
                target = calculator.target(
                    for: command,
                    on: destination,
                    currentWindowFrame: snapshot.frame,
                    spacing: preferences.spacing
                )
            }
            else
            {
                target = transferCalculator.target(
                    for: snapshot.frame,
                    from: source,
                    to: destination,
                    spacing: preferences.spacing
                )
            }
            let result = await windowManager.apply(
                target: target,
                to: snapshot.token,
                converter: currentConverter(),
                command: command
            )
            handle(result)
        }
    }

    private func moveAppWindows(to direction: DisplayDirection?)
    {
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            statusMessage = MoveFailure.accessibilityPermissionRequired.message
            showPermissionWindow()
            return
        }
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            statusMessage = MoveFailure.noTargetApplication.message
            return
        }
        let converter = currentConverter()
        Task
        {
            [self] in
            let focusedCapture = await windowManager.captureFocusedWindow(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard case .captured(let focusedWindow) = focusedCapture
            else
            {
                if case .failed(let failure) = focusedCapture
                {
                    statusMessage = failure.message
                }
                return
            }
            let screens = displayProvider.snapshots()
            guard let focusedScreen = displayProvider.screen(
                containing: focusedWindow.frame,
                in: screens
            )
            else
            {
                statusMessage = MoveFailure.noDisplays.message
                return
            }
            let destination: ScreenSnapshot
            if let direction
            {
                guard let adjacentScreen = displayProvider.adjacent(
                    to: focusedScreen,
                    direction: direction,
                    in: screens
                )
                else
                {
                    statusMessage = screens.count < 2
                        ? "No other display is connected."
                        : MoveFailure.noDisplays.message
                    return
                }
                destination = adjacentScreen
            }
            else
            {
                destination = focusedScreen
            }
            let result = await displayWindowManagementService.moveAppWindows(
                processIdentifier: processIdentifier,
                to: destination,
                screens: screens,
                spacing: preferences.spacing,
                converter: converter
            )
            handle(result)
        }
    }

    private func applyLayoutCommand(_ command: LayoutCommand)
    {
        Task
        {
            guard let snapshot = await captureTargetWindow(),
                  let screen = currentScreen(for: snapshot)
            else
            {
                return
            }
            await apply(
                command,
                to: PaletteSession(window: snapshot, screen: screen)
            )
        }
    }

    private func apply(_ command: LayoutCommand, to session: PaletteSession)
    {
        Task
        {
            await apply(command, to: session)
        }
    }

    private func apply(_ command: LayoutCommand, to session: PaletteSession) async
    {
        let target = calculator.target(
            for: command,
            on: session.screen,
            currentWindowFrame: session.window.frame,
            spacing: preferences.spacing
        )
        let result = await windowManager.apply(
            target: target,
            to: session.window.token,
            converter: currentConverter(),
            command: command
        )
        handle(result)
    }

    private func captureTargetWindow() async -> ManagedWindowSnapshot?
    {
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            statusMessage = MoveFailure.accessibilityPermissionRequired.message
            showPermissionWindow()
            return nil
        }
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            statusMessage = MoveFailure.noTargetApplication.message
            return nil
        }
        let result = await windowManager.captureFocusedWindow(
            processIdentifier: processIdentifier,
            converter: currentConverter()
        )
        switch result
        {
        case .captured(let snapshot):
            return snapshot
        case .failed(let failure):
            statusMessage = failure.message
            return nil
        }
    }

    private func captureTargetWindowForLifecycle() async -> ManagedWindowSnapshot?
    {
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            statusMessage = MoveFailure.accessibilityPermissionRequired.message
            showPermissionWindow()
            return nil
        }
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            statusMessage = MoveFailure.noTargetApplication.message
            return nil
        }
        let result = await windowManager.captureFocusedWindowForLifecycle(
            processIdentifier: processIdentifier,
            converter: currentConverter()
        )
        switch result
        {
        case .captured(let snapshot):
            return snapshot
        case .failed(let failure):
            statusMessage = failure.message
            return nil
        }
    }

    private func currentScreen(for snapshot: ManagedWindowSnapshot) -> ScreenSnapshot?
    {
        let screens = displayProvider.snapshots()
        guard let screen = displayProvider.screen(containing: snapshot.frame, in: screens)
        else
        {
            statusMessage = MoveFailure.noDisplays.message
            return nil
        }
        return screen
    }

    private func currentConverter() -> ScreenCoordinateConverter
    {
        ScreenCoordinateConverter(
            primaryDisplayMaximumY: displayProvider.primaryDisplayMaximumY()
        )
    }

    private func cancelAvailabilityRefresh()
    {
        availabilityTask?.cancel()
        availabilityTask = nil
        availabilityRequestIdentifier = UUID()
    }

    private func availability(
        for result: Result<[ManagedWindowSnapshot], MoveFailure>
    ) -> BatchArrangementAvailability
    {
        switch result
        {
        case .success(let windows):
            return availability(forWindowCount: windows.count)
        case .failure(let failure):
            if failure == .noManageableWindows
            {
                return .unavailableNoWindows
            }
            return .unavailable(failure)
        }
    }

    private func availability(forWindowCount windowCount: Int) -> BatchArrangementAvailability
    {
        if windowCount == 0
        {
            return .unavailableNoWindows
        }
        if windowCount > BalancedFourByTwoLayout.capacity
        {
            return .unavailableTooMany(windowCount: windowCount)
        }
        return .available(windowCount: windowCount)
    }

    private func handle(_ result: MoveResult)
    {
        switch result
        {
        case .moved:
            statusMessage = nil
        case .bestEffort:
            statusMessage = "The app applied the closest size this window permits."
        case .failed(let failure):
            statusMessage = failure.message
        }
    }

    private func handle(_ result: WindowArrangementResult)
    {
        switch result
        {
        case .arranged(let windowCount, let usedBestEffort, let terminalSized):
            batchArrangementAvailability = .available(windowCount: windowCount)
            if terminalSized
            {
                statusMessage = usedBestEffort
                    ? "Arranged \(windowCount) Terminal windows at 80 × 48 with position limits."
                    : "Arranged \(windowCount) Terminal windows at 80 × 48."
            }
            else
            {
                statusMessage = usedBestEffort
                    ? "Arranged \(windowCount) windows with size limits."
                    : "Arranged \(windowCount) windows in a balanced 4 × 2 layout."
            }
        case .restored(let windowCount, let usedBestEffort):
            statusMessage = usedBestEffort
                ? "Restored \(windowCount) windows with size limits."
                : "Restored \(windowCount) windows."
        case .failed(let failure):
            statusMessage = failure.message
            switch failure
            {
            case .noWindows:
                batchArrangementAvailability = .unavailableNoWindows
            case .tooManyWindows(let windowCount):
                batchArrangementAvailability = .unavailableTooMany(
                    windowCount: windowCount
                )
            case .move(let moveFailure):
                batchArrangementAvailability = .unavailable(moveFailure)
            default:
                break
            }
        }
    }

    private func handle(_ result: DisplayWindowManagementResult)
    {
        switch result
        {
        case .moved(let windowCount, let usedBestEffort):
            statusMessage = usedBestEffort
                ? "Moved \(windowCount) app windows with size limits."
                : "Moved \(windowCount) app windows to the display."
        case .alreadyOnDisplay:
            statusMessage = "All app windows are already on that display."
        case .failed(let failure):
            statusMessage = failure.message
        }
    }

    private func handle(_ result: DesktopVisibilityResult)
    {
        switch result
        {
        case .shown(let hiddenApplicationCount):
            statusMessage = "Showed the desktop by hiding \(hiddenApplicationCount) applications."
        case .restored(let applicationCount):
            statusMessage = "Restored \(applicationCount) applications."
        case .alreadyShown:
            statusMessage = "The desktop is already shown."
        case .nothingToRestore:
            statusMessage = "There is no desktop visibility state to restore."
        case .failed(let message):
            statusMessage = message
        }
    }

    private func handle(
        _ result: WindowOperationResult,
        action: WindowLifecycleAction
    )
    {
        switch result
        {
        case .completed:
            statusMessage = "\(action.title) completed."
        case .failed(let failure):
            statusMessage = failure.message
        }
    }

    private func registerPaletteShortcut(_ shortcut: KeyboardShortcut)
    {
        let result = hotKeyService.register(shortcut)
        {
            [weak self] in
            self?.openPalette()
        }
        switch result
        {
        case .registered:
            shortcutErrorMessage = nil
        case .conflict:
            shortcutErrorMessage = "The saved shortcut is already in use."
        case .failed(let status):
            shortcutErrorMessage = "Shortcut registration failed with status \(status)."
        }
    }

    private var isUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    private var isPaletteUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains("--ui-testing-palette")
    }

    private var isPermissionUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains("--ui-testing-permission")
    }

    private var isLiveArrangementUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-live-arrange-and-restore"
        )
    }

    private var isLiveDisplayTransferUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-live-display-transfer-and-restore"
        )
    }

    private var batchWindowCountOverride: Int?
    {
        guard isUITesting,
              let argument = ProcessInfo.processInfo.arguments.first(where:
              {
                  $0.hasPrefix("--ui-testing-batch-window-count=")
              })
        else
        {
            return nil
        }
        return Int(argument.replacingOccurrences(
            of: "--ui-testing-batch-window-count=",
            with: ""
        ))
    }

    private var liveUITestTargetBundleIdentifier: String?
    {
        let prefix = "--ui-testing-live-target-bundle-identifier="
        guard let argument = ProcessInfo.processInfo.arguments.first(where:
        {
            $0.hasPrefix(prefix)
        })
        else
        {
            return nil
        }
        return String(argument.dropFirst(prefix.count))
    }

    private var targetBundleIdentifier: String?
    {
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            return nil
        }
        return NSRunningApplication(processIdentifier: processIdentifier)?.bundleIdentifier
    }

    private func presentUITestPalette()
    {
        for window in NSApp.windows where !(window is PalettePanel)
        {
            window.orderOut(nil)
        }
        guard let screen = displayProvider.snapshots().first
        else
        {
            return
        }
        let frame = CGRect(
            x: screen.visibleFrame.midX - 320,
            y: screen.visibleFrame.midY - 240,
            width: 640,
            height: 480
        )
        let session = PaletteSession(
            window: ManagedWindowSnapshot(
                token: ManagedWindowToken(id: UUID()),
                processIdentifier: ProcessInfo.processInfo.processIdentifier,
                frame: frame
            ),
            screen: screen
        )
        paletteController.present(session: session)
        {
            [weak self] command, _ in
            self?.statusMessage = "UI test applied \(command.title)."
        }
        if let snapshotPath = ProcessInfo.processInfo.environment["GRIDWINDOWMANAGER_PALETTE_SNAPSHOT"]
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1)
            {
                self.paletteController.snapshot(to: snapshotPath)
                NSApp.terminate(nil)
            }
        }
    }
}
