import CoreGraphics
import Foundation

@MainActor
final class BalancedWindowArrangementService
{
    private let windowManager: any WindowManaging
    private let terminalWindowSizing: any TerminalWindowSizing
    private let calculator: any LayoutCalculating
    private let layout = BalancedFourByTwoLayout()
    private let threeByTwoLayout = BalancedThreeByTwoLayout()
    private let visualOrder = VisualWindowOrder()

    init(
        windowManager: any WindowManaging,
        terminalWindowSizing: any TerminalWindowSizing,
        calculator: any LayoutCalculating
    )
    {
        self.windowManager = windowManager
        self.terminalWindowSizing = terminalWindowSizing
        self.calculator = calculator
    }

    func arrange(
        processIdentifier: pid_t,
        bundleIdentifier: String?,
        targetScreen: ScreenSnapshot,
        spacing: CGFloat,
        converter: ScreenCoordinateConverter
    ) async -> WindowArrangementResult
    {
        let capture = await windowManager.captureStandardWindows(
            processIdentifier: processIdentifier,
            converter: converter
        )
        guard case .success(let capturedWindows) = capture
        else
        {
            if case .failure(let failure) = capture
            {
                return .failed(.move(failure))
            }
            return .failed(.noWindows)
        }
        guard !capturedWindows.isEmpty
        else
        {
            return .failed(.noWindows)
        }
        guard capturedWindows.count <= BalancedFourByTwoLayout.capacity
        else
        {
            return .failed(.tooManyWindows(capturedWindows.count))
        }

        let originalWindows = visualOrder.ordered(capturedWindows)
        let originalFrames = originalWindows.map
        {
            WindowFrameState(token: $0.token, frame: $0.frame)
        }
        let isTerminal =
            bundleIdentifier == TerminalWindowSizingService.bundleIdentifier
        var currentWindows = originalWindows
        var terminalState: TerminalArrangementState?

        if isTerminal
        {
            let authorization =
                await terminalWindowSizing.requestAuthorization()
            guard authorization.permitsAutomation
            else
            {
                return .failed(.terminal(.automation(authorization)))
            }
            let previousStates: [TerminalWindowState]
            do
            {
                previousStates = try terminalWindowSizing.captureStates()
            } catch let failure as TerminalWindowSizingError
            {
                return .failed(.terminal(failure))
            } catch
            {
                return .failed(
                    .terminal(
                        .scriptFailure(
                            code: 0,
                            message: error.localizedDescription
                        )))
            }
            guard previousStates.count == originalWindows.count
            else
            {
                return .failed(
                    .terminalWindowCountMismatch(
                        accessibility: originalWindows.count,
                        automation: previousStates.count
                    ))
            }
            let managedStates = TerminalWindowSizingService.managedStates(
                from: previousStates
            )
            do
            {
                try terminalWindowSizing.apply(managedStates)
            } catch let failure as TerminalWindowSizingError
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: previousStates,
                    frameStates: originalFrames,
                    converter: converter
                )
                return .failed(rollbackFailure ?? .terminal(failure))
            } catch
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: previousStates,
                    frameStates: originalFrames,
                    converter: converter
                )
                return .failed(
                    rollbackFailure
                        ?? .terminal(
                            .scriptFailure(
                                code: 0,
                                message: error.localizedDescription
                            )))
            }
            try? await Task.sleep(for: .milliseconds(100))
            let resizedCapture = await windowManager.captureStandardWindows(
                processIdentifier: processIdentifier,
                converter: converter
            )
            guard case .success(let resizedWindows) = resizedCapture,
                resizedWindows.count == originalWindows.count
            else
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: previousStates,
                    frameStates: originalFrames,
                    converter: converter
                )
                return .failed(rollbackFailure ?? .terminal(.windowSetChanged))
            }
            let resizedByToken = Dictionary(
                uniqueKeysWithValues: resizedWindows.map
                {
                    ($0.token, $0)
                }
            )
            guard
                originalWindows.allSatisfy(
                    {
                        resizedByToken[$0.token] != nil
                    })
            else
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: previousStates,
                    frameStates: originalFrames,
                    converter: converter
                )
                return .failed(rollbackFailure ?? .terminal(.windowSetChanged))
            }
            currentWindows = originalWindows.compactMap
            {
                resizedByToken[$0.token]
            }
            terminalState = TerminalArrangementState(
                previous: previousStates,
                managed: managedStates
            )
        }

        let windowSizes =
            isTerminal
            ? currentWindows.map(\.frame.size)
            : genericWindowSizes(
                dimension: .fourByTwo,
                count: currentWindows.count,
                screen: targetScreen,
                spacing: spacing
            )
        let layoutResult = layout.placements(
            for: windowSizes,
            in: targetScreen.visibleFrame,
            spacing: spacing,
            backingScaleFactor: targetScreen.backingScaleFactor
        )
        let placements: [CGRect]
        switch layoutResult
        {
        case .placements(let frames):
            placements = frames
        case .unsupportedWindowCount(let count):
            if let terminalState
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: terminalState.previous,
                    frameStates: originalFrames,
                    converter: converter
                )
                return .failed(
                    rollbackFailure
                        ?? (count == 0 ? .noWindows : .tooManyWindows(count))
                )
            }
            return .failed(count == 0 ? .noWindows : .tooManyWindows(count))
        case .doesNotFit(let required, let available):
            if let terminalState
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: terminalState.previous,
                    frameStates: originalFrames,
                    converter: converter
                )
                return .failed(
                    rollbackFailure
                        ?? .doesNotFit(
                            required: required,
                            available: available
                        )
                )
            }
            return .failed(
                .doesNotFit(required: required, available: available))
        }

        let originalByToken = Dictionary(
            uniqueKeysWithValues: originalWindows.map
            {
                ($0.token, $0.frame)
            }
        )
        let requests = zip(currentWindows, placements).compactMap
        {
            window, frame -> WindowPlacementRequest? in
            guard let previousFrame = originalByToken[window.token]
            else
            {
                return nil
            }
            return WindowPlacementRequest(
                token: window.token,
                target: LayoutTarget(
                    frame: frame,
                    visibleFrame: targetScreen.visibleFrame,
                    edges: [],
                    backingScaleFactor: targetScreen.backingScaleFactor
                ),
                historyPreviousFrame: previousFrame,
                command: nil
            )
        }
        guard requests.count == currentWindows.count
        else
        {
            if let terminalState
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: terminalState.previous,
                    frameStates: originalFrames,
                    converter: converter
                )
                return .failed(rollbackFailure ?? .terminal(.windowSetChanged))
            }
            return .failed(.move(.staleWindow))
        }
        let result = await windowManager.applyBatch(
            requests,
            terminalState: terminalState,
            converter: converter
        )
        switch result
        {
        case .moved:
            return .arranged(
                windowCount: requests.count,
                usedBestEffort: false,
                terminalSized: isTerminal
            )
        case .bestEffort:
            return .arranged(
                windowCount: requests.count,
                usedBestEffort: true,
                terminalSized: isTerminal
            )
        case .failed(let failure):
            if let terminalState
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: terminalState.previous,
                    frameStates: originalFrames,
                    converter: converter
                )
                return .failed(rollbackFailure ?? .move(failure))
            }
            return .failed(.move(failure))
        }
    }

    func arrangeThreeByTwo(
        processIdentifier: pid_t,
        targetScreen: ScreenSnapshot,
        spacing: CGFloat,
        converter: ScreenCoordinateConverter
    ) async -> WindowArrangementResult
    {
        let capture = await windowManager.captureStandardWindows(
            processIdentifier: processIdentifier,
            converter: converter
        )
        guard case .success(let capturedWindows) = capture
        else
        {
            if case .failure(let failure) = capture
            {
                return .failed(.move(failure))
            }
            return .failed(.noWindows)
        }
        guard !capturedWindows.isEmpty
        else
        {
            return .failed(.noWindows)
        }
        guard capturedWindows.count <= BalancedThreeByTwoLayout.capacity
        else
        {
            return .failed(.tooManyWindows(capturedWindows.count))
        }

        let originalWindows = visualOrder.ordered(capturedWindows)

        let windowSizes = genericWindowSizes(
            dimension: .threeByTwo,
            count: originalWindows.count,
            screen: targetScreen,
            spacing: spacing
        )
        let layoutResult = threeByTwoLayout.placements(
            for: windowSizes,
            in: targetScreen.visibleFrame,
            spacing: spacing,
            backingScaleFactor: targetScreen.backingScaleFactor
        )
        let placements: [CGRect]
        switch layoutResult
        {
        case .placements(let frames):
            placements = frames
        case .unsupportedWindowCount(let count):
            return .failed(count == 0 ? .noWindows : .tooManyWindows(count))
        case .doesNotFit(let required, let available):
            return .failed(
                .doesNotFit(required: required, available: available))
        }

        let originalByToken = Dictionary(
            uniqueKeysWithValues: originalWindows.map
            {
                ($0.token, $0.frame)
            }
        )
        let requests = zip(originalWindows, placements).compactMap
        {
            window, frame -> WindowPlacementRequest? in
            guard let previousFrame = originalByToken[window.token]
            else
            {
                return nil
            }
            return WindowPlacementRequest(
                token: window.token,
                target: LayoutTarget(
                    frame: frame,
                    visibleFrame: targetScreen.visibleFrame,
                    edges: [],
                    backingScaleFactor: targetScreen.backingScaleFactor
                ),
                historyPreviousFrame: previousFrame,
                command: nil
            )
        }
        guard requests.count == originalWindows.count
        else
        {
            return .failed(.move(.staleWindow))
        }
        let result = await windowManager.applyBatch(
            requests,
            terminalState: nil,
            converter: converter
        )
        switch result
        {
        case .moved:
            return .arranged(
                windowCount: requests.count,
                usedBestEffort: false,
                terminalSized: false
            )
        case .bestEffort:
            return .arranged(
                windowCount: requests.count,
                usedBestEffort: true,
                terminalSized: false
            )
        case .failed(let failure):
            return .failed(.move(failure))
        }
    }

    func restorePrevious(
        converter: ScreenCoordinateConverter
    ) async -> WindowArrangementResult
    {
        let preparation = await windowManager.prepareUndo(converter: converter)
        guard case .success(let transaction) = preparation
        else
        {
            if case .failure(let failure) = preparation
            {
                return .failed(.move(failure))
            }
            return .failed(.move(.nothingToUndo))
        }
        if let terminalState = transaction.terminalState
        {
            let authorization =
                await terminalWindowSizing.requestAuthorization()
            guard authorization.permitsAutomation
            else
            {
                return .failed(.terminal(.automation(authorization)))
            }
            do
            {
                let currentStates = try terminalWindowSizing.captureStates()
                guard
                    normalized(currentStates)
                        == normalized(terminalState.managed)
                else
                {
                    return .failed(.move(.windowChanged))
                }
                try terminalWindowSizing.apply(terminalState.previous)
            } catch let failure as TerminalWindowSizingError
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: terminalState.managed,
                    frameStates: transaction.changes.map
                    {
                        WindowFrameState(
                            token: $0.token, frame: $0.managedFrame)
                    },
                    converter: converter
                )
                return .failed(rollbackFailure ?? .terminal(failure))
            } catch
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: terminalState.managed,
                    frameStates: transaction.changes.map
                    {
                        WindowFrameState(
                            token: $0.token, frame: $0.managedFrame)
                    },
                    converter: converter
                )
                return .failed(
                    rollbackFailure
                        ?? .terminal(
                            .scriptFailure(
                                code: 0,
                                message: error.localizedDescription
                            )))
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        let result = await windowManager.commitPreparedUndo(
            transactionIdentifier: transaction.identifier,
            converter: converter
        )
        switch result
        {
        case .moved:
            return .restored(
                windowCount: transaction.changes.count,
                usedBestEffort: false
            )
        case .bestEffort:
            return .restored(
                windowCount: transaction.changes.count,
                usedBestEffort: true
            )
        case .failed(let failure):
            if let terminalState = transaction.terminalState
            {
                let rollbackFailure = await rollbackExternalState(
                    terminalStates: terminalState.managed,
                    frameStates: transaction.changes.map
                    {
                        WindowFrameState(
                            token: $0.token, frame: $0.managedFrame)
                    },
                    converter: converter
                )
                return .failed(rollbackFailure ?? .move(failure))
            }
            return .failed(.move(failure))
        }
    }

    private func genericWindowSizes(
        dimension: GridDimension,
        count: Int,
        screen: ScreenSnapshot,
        spacing: CGFloat
    ) -> [CGSize]
    {
        let cell = GridCell(row: 0, column: 0)
        let region = GridRegion(
            dimension: dimension,
            anchor: cell,
            extent: cell
        )
        let target = calculator.target(
            for: .grid(region),
            on: screen,
            currentWindowFrame: .zero,
            spacing: spacing
        )
        return Array(repeating: target.frame.size, count: count)
    }

    private func rollbackExternalState(
        terminalStates: [TerminalWindowState],
        frameStates: [WindowFrameState],
        converter: ScreenCoordinateConverter
    ) async -> WindowArrangementFailure?
    {
        var terminalFailure: String?
        do
        {
            try terminalWindowSizing.apply(terminalStates)
        } catch let failure as TerminalWindowSizingError
        {
            terminalFailure = failure.message
        } catch
        {
            terminalFailure = error.localizedDescription
        }
        try? await Task.sleep(for: .milliseconds(100))
        let frameResult = await windowManager.restoreFrames(
            frameStates,
            converter: converter
        )
        switch frameResult
        {
        case .moved:
            if let terminalFailure
            {
                return .rollbackFailed(terminalFailure)
            }
            return nil
        case .bestEffort:
            let detail =
                terminalFailure.map
                {
                    "\($0) Window frames were restored only approximately."
                } ?? "Window frames were restored only approximately."
            return .rollbackFailed(detail)
        case .failed(let failure):
            let detail =
                terminalFailure.map
                {
                    "\($0) \(failure.message)"
                } ?? failure.message
            return .rollbackFailed(detail)
        }
    }

    private func normalized(
        _ states: [TerminalWindowState]
    ) -> [TerminalWindowState]
    {
        states.sorted
        {
            $0.windowIdentifier < $1.windowIdentifier
        }
    }
}
