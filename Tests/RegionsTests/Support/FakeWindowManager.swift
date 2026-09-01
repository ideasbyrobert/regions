import CoreGraphics
import Foundation
@testable import Regions

actor FakeWindowManager: WindowManaging
{
    private var windows: [ManagedWindowSnapshot]
    private var captureQueue: [[ManagedWindowSnapshot]]
    private var transactions: [WindowArrangementTransaction] = []
    private var lastCommands: [ManagedWindowToken: LayoutCommand] = [:]
    private var batchFailure: MoveFailure?
    private var frameRestoreFailure: MoveFailure?

    init(
        windows: [ManagedWindowSnapshot],
        captureQueue: [[ManagedWindowSnapshot]] = []
    )
    {
        self.windows = windows
        self.captureQueue = captureQueue
    }

    func captureFocusedWindow(
        processIdentifier: pid_t,
        converter: ScreenCoordinateConverter
    ) async -> WindowCaptureResult
    {
        guard let window = windows.first
        else
        {
            return .failed(.noFocusedWindow)
        }
        return .captured(window)
    }

    func captureStandardWindows(
        processIdentifier: pid_t,
        converter: ScreenCoordinateConverter
    ) async -> Result<[ManagedWindowSnapshot], MoveFailure>
    {
        if !captureQueue.isEmpty
        {
            windows = captureQueue.removeFirst()
        }
        return windows.isEmpty ? .failure(.noManageableWindows) : .success(windows)
    }

    func captureFocusedWindowForLifecycle(
        processIdentifier: pid_t,
        converter: ScreenCoordinateConverter
    ) async -> WindowCaptureResult
    {
        await captureFocusedWindow(
            processIdentifier: processIdentifier,
            converter: converter
        )
    }

    func captureStandardWindow(
        at point: CGPoint,
        converter: ScreenCoordinateConverter
    ) async -> WindowCaptureResult
    {
        guard let window = windows.first(where:
        {
            $0.frame.contains(point)
        })
        else
        {
            return .failed(.noFocusedWindow)
        }
        return .captured(window)
    }

    func snapshot(
        for token: ManagedWindowToken,
        converter: ScreenCoordinateConverter
    ) async -> WindowCaptureResult
    {
        guard let window = windows.first(where:
        {
            $0.token == token
        })
        else
        {
            return .failed(.staleWindow)
        }
        return .captured(window)
    }

    func apply(
        target: LayoutTarget,
        to token: ManagedWindowToken,
        converter: ScreenCoordinateConverter,
        command: LayoutCommand?,
        historyPreviousFrame: CGRect?
    ) async -> MoveResult
    {
        guard let index = windows.firstIndex(where:
        {
            $0.token == token
        })
        else
        {
            return .failed(.staleWindow)
        }
        let previousFrame = historyPreviousFrame ?? windows[index].frame
        windows[index] = ManagedWindowSnapshot(
            token: token,
            processIdentifier: windows[index].processIdentifier,
            frame: target.frame
        )
        transactions.append(WindowArrangementTransaction(
            identifier: UUID(),
            changes:
            [
                WindowFrameChange(
                    token: token,
                    previousFrame: previousFrame,
                    managedFrame: target.frame
                )
            ],
            terminalState: nil
        ))
        return .moved(target.frame)
    }

    func applyBatch(
        _ requests: [WindowPlacementRequest],
        terminalState: TerminalArrangementState?,
        converter: ScreenCoordinateConverter
    ) async -> MoveResult
    {
        if let batchFailure
        {
            return .failed(batchFailure)
        }
        guard requests.allSatisfy(
        {
            request in
            windows.contains(where:
            {
                $0.token == request.token
            })
        })
        else
        {
            return .failed(.staleWindow)
        }
        var changes: [WindowFrameChange] = []
        for request in requests
        {
            guard let index = windows.firstIndex(where:
            {
                $0.token == request.token
            })
            else
            {
                return .failed(.staleWindow)
            }
            windows[index] = ManagedWindowSnapshot(
                token: request.token,
                processIdentifier: windows[index].processIdentifier,
                frame: request.target.frame
            )
            changes.append(WindowFrameChange(
                token: request.token,
                previousFrame: request.historyPreviousFrame,
                managedFrame: request.target.frame
            ))
        }
        let transaction = WindowArrangementTransaction(
            identifier: UUID(),
            changes: changes,
            terminalState: terminalState
        )
        transactions.append(transaction)
        guard let frame = changes.first?.managedFrame
        else
        {
            return .failed(.noManageableWindows)
        }
        return .moved(frame)
    }

    func perform(
        _ action: WindowLifecycleAction,
        on token: ManagedWindowToken,
        converter: ScreenCoordinateConverter
    ) async -> WindowOperationResult
    {
        windows.contains(where:
        {
            $0.token == token
        }) ? .completed : .failed(.staleWindow)
    }

    func undoLast(converter: ScreenCoordinateConverter) async -> MoveResult
    {
        let preparation = await prepareUndo(converter: converter)
        guard case .success(let transaction) = preparation
        else
        {
            if case .failure(let failure) = preparation
            {
                return .failed(failure)
            }
            return .failed(.nothingToUndo)
        }
        return await commitPreparedUndo(
            transactionIdentifier: transaction.identifier,
            converter: converter
        )
    }

    func prepareUndo(
        converter: ScreenCoordinateConverter
    ) async -> Result<WindowArrangementTransaction, MoveFailure>
    {
        guard let transaction = transactions.last
        else
        {
            return .failure(.nothingToUndo)
        }
        for change in transaction.changes
        {
            guard let window = windows.first(where:
            {
                $0.token == change.token
            })
            else
            {
                return .failure(.staleWindow)
            }
            guard window.frame == change.managedFrame
            else
            {
                return .failure(.windowChanged)
            }
        }
        return .success(transaction)
    }

    func commitPreparedUndo(
        transactionIdentifier: UUID,
        converter: ScreenCoordinateConverter
    ) async -> MoveResult
    {
        guard let transaction = transactions.last,
              transaction.identifier == transactionIdentifier
        else
        {
            return .failed(.windowChanged)
        }
        let result = await restoreFrames(
            transaction.changes.map
            {
                WindowFrameState(token: $0.token, frame: $0.previousFrame)
            },
            converter: converter
        )
        if case .moved = result
        {
            transactions.removeLast()
        }
        return result
    }

    func restoreFrames(
        _ states: [WindowFrameState],
        converter: ScreenCoordinateConverter
    ) async -> MoveResult
    {
        if let frameRestoreFailure
        {
            return .failed(frameRestoreFailure)
        }
        for state in states
        {
            guard let index = windows.firstIndex(where:
            {
                $0.token == state.token
            })
            else
            {
                return .failed(.staleWindow)
            }
            windows[index] = ManagedWindowSnapshot(
                token: state.token,
                processIdentifier: windows[index].processIdentifier,
                frame: state.frame
            )
        }
        guard let frame = states.first?.frame
        else
        {
            return .failed(.noManageableWindows)
        }
        return .moved(frame)
    }

    func lastCommand(for token: ManagedWindowToken) async -> LayoutCommand?
    {
        lastCommands[token]
    }

    func setBatchFailure(_ failure: MoveFailure?)
    {
        batchFailure = failure
    }

    func setFrameRestoreFailure(_ failure: MoveFailure?)
    {
        frameRestoreFailure = failure
    }

    func setFrame(_ frame: CGRect, for token: ManagedWindowToken)
    {
        guard let index = windows.firstIndex(where:
        {
            $0.token == token
        })
        else
        {
            return
        }
        windows[index] = ManagedWindowSnapshot(
            token: token,
            processIdentifier: windows[index].processIdentifier,
            frame: frame
        )
    }

    func setLastCommand(_ command: LayoutCommand?, for token: ManagedWindowToken)
    {
        lastCommands[token] = command
    }

    func currentWindows() -> [ManagedWindowSnapshot]
    {
        windows
    }

    func transactionCount() -> Int
    {
        transactions.count
    }
}
