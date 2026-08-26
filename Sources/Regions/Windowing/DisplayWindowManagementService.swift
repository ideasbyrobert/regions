import Foundation
import OSLog

@MainActor
final class DisplayWindowManagementService
{
    private let windowManager: any WindowManaging
    private let displayProvider: DisplaySnapshotProvider
    private let calculator: any LayoutCalculating
    private let transferCalculator: DisplayTransferCalculator
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.ideasbyrobert.Regions",
        category: "Displays"
    )

    init(
        windowManager: any WindowManaging,
        displayProvider: DisplaySnapshotProvider,
        calculator: any LayoutCalculating,
        transferCalculator: DisplayTransferCalculator
    )
    {
        self.windowManager = windowManager
        self.displayProvider = displayProvider
        self.calculator = calculator
        self.transferCalculator = transferCalculator
    }

    func moveAppWindows(
        processIdentifier: pid_t,
        to destination: ScreenSnapshot,
        screens: [ScreenSnapshot],
        spacing: CGFloat,
        converter: ScreenCoordinateConverter
    ) async -> DisplayWindowManagementResult
    {
        let start = ContinuousClock.now
        let capture = await windowManager.captureStandardWindows(
            processIdentifier: processIdentifier,
            converter: converter
        )
        guard case .success(let windows) = capture
        else
        {
            if case .failure(let failure) = capture
            {
                return .failed(failure)
            }
            return .failed(.noManageableWindows)
        }
        var requests: [WindowPlacementRequest] = []
        for window in windows
        {
            guard
                let source = displayProvider.screen(
                    containing: window.frame,
                    in: screens
                )
            else
            {
                return .failed(.noDisplays)
            }
            guard source.displayID != destination.displayID
            else
            {
                continue
            }
            let command = await windowManager.lastCommand(for: window.token)?
                .adapted(to: destination)
            let target: LayoutTarget
            if let command
            {
                target = calculator.target(
                    for: command,
                    on: destination,
                    currentWindowFrame: window.frame,
                    spacing: spacing
                )
            } else
            {
                target = transferCalculator.target(
                    for: window.frame,
                    from: source,
                    to: destination,
                    spacing: spacing
                )
            }
            requests.append(
                WindowPlacementRequest(
                    token: window.token,
                    target: target,
                    historyPreviousFrame: window.frame,
                    command: command
                ))
        }
        guard !requests.isEmpty
        else
        {
            return .alreadyOnDisplay
        }
        let result = await windowManager.applyBatch(
            requests,
            terminalState: nil,
            converter: converter
        )
        logger.info(
            """
            Transferred \(requests.count, privacy: .public) app windows in \
            \(start.duration(to: .now), privacy: .public)
            """
        )
        switch result
        {
        case .moved:
            return .moved(windowCount: requests.count, usedBestEffort: false)
        case .bestEffort:
            return .moved(windowCount: requests.count, usedBestEffort: true)
        case .failed(let failure):
            return .failed(failure)
        }
    }

    func swapAppWindows(
        processIdentifier: pid_t,
        screens: [ScreenSnapshot],
        spacing: CGFloat,
        converter: ScreenCoordinateConverter
    ) async -> DisplayWindowManagementResult
    {
        guard screens.count >= 2
        else
        {
            return .failed(.noDisplays)
        }
        let capture = await windowManager.captureStandardWindows(
            processIdentifier: processIdentifier,
            converter: converter
        )
        guard case .success(let windows) = capture
        else
        {
            if case .failure(let failure) = capture
            {
                return .failed(failure)
            }
            return .failed(.noManageableWindows)
        }
        var requests: [WindowPlacementRequest] = []
        for window in windows
        {
            guard
                let screen = displayProvider.screen(
                    containing: window.frame, in: screens),
                let sourceIndex = screens.firstIndex(where:
                {
                    $0.displayID == screen.displayID
                })
            else
            {
                continue
            }
            let destinationIndex = (sourceIndex + 1) % screens.count
            let source = screens[sourceIndex]
            let destination = screens[destinationIndex]
            let command = await windowManager.lastCommand(for: window.token)?
                .adapted(to: destination)
            let target: LayoutTarget
            if let command
            {
                target = calculator.target(
                    for: command,
                    on: destination,
                    currentWindowFrame: window.frame,
                    spacing: spacing
                )
            } else
            {
                target = transferCalculator.target(
                    for: window.frame,
                    from: source,
                    to: destination,
                    spacing: spacing
                )
            }
            requests.append(
                WindowPlacementRequest(
                    token: window.token,
                    target: target,
                    historyPreviousFrame: window.frame,
                    command: command
                ))
        }
        guard !requests.isEmpty
        else
        {
            return .failed(.noManageableWindows)
        }
        let result = await windowManager.applyBatch(
            requests,
            terminalState: nil,
            converter: converter
        )
        switch result
        {
        case .moved:
            return .moved(windowCount: requests.count, usedBestEffort: false)
        case .bestEffort:
            return .moved(windowCount: requests.count, usedBestEffort: true)
        case .failed(let failure):
            return .failed(failure)
        }
    }
}
