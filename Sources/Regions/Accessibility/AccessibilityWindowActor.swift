import ApplicationServices
import CoreGraphics
import Foundation
import OSLog

actor AccessibilityWindowActor: WindowManaging
{
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.ideasbyrobert.Regions",
        category: "Windowing"
    )
    private var records: [UUID: AccessibilityWindowRecord] = [:]
    private var history: [WindowArrangementTransaction] = []
    private var lastCommands: [UUID: LayoutCommand] = [:]

    func captureFocusedWindow(
        processIdentifier: pid_t,
        converter: ScreenCoordinateConverter
    ) async -> WindowCaptureResult
    {
        guard AXIsProcessTrusted()
        else
        {
            return .failed(.accessibilityPermissionRequired)
        }

        let application = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.5)
        guard let window = application.copiedElement(for: kAXFocusedWindowAttribute as CFString)
        else
        {
            return .failed(.noFocusedWindow)
        }
        AXUIElementSetMessagingTimeout(window, 0.5)

        if let failure = validationFailure(for: window)
        {
            return .failed(failure)
        }
        guard let accessibilityFrame = frame(of: window)
        else
        {
            return .failed(.staleWindow)
        }

        logger.info("Captured focused window for process \(processIdentifier, privacy: .public)")
        return .captured(registeredSnapshot(
            processIdentifier: processIdentifier,
            element: window,
            accessibilityFrame: accessibilityFrame,
            converter: converter
        ))
    }

    func captureStandardWindows(
        processIdentifier: pid_t,
        converter: ScreenCoordinateConverter
    ) async -> Result<[ManagedWindowSnapshot], MoveFailure>
    {
        guard AXIsProcessTrusted()
        else
        {
            return .failure(.accessibilityPermissionRequired)
        }

        let application = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.5)
        guard let windows = application.copiedElements(for: kAXWindowsAttribute as CFString)
        else
        {
            return .failure(.noManageableWindows)
        }

        var snapshots: [ManagedWindowSnapshot] = []
        for window in windows where isStandardWindow(window)
        {
            AXUIElementSetMessagingTimeout(window, 0.5)
            if let failure = validationFailure(for: window)
            {
                return .failure(failure)
            }
            guard let accessibilityFrame = frame(of: window)
            else
            {
                return .failure(.staleWindow)
            }
            snapshots.append(registeredSnapshot(
                processIdentifier: processIdentifier,
                element: window,
                accessibilityFrame: accessibilityFrame,
                converter: converter
            ))
        }

        guard !snapshots.isEmpty
        else
        {
            return .failure(.noManageableWindows)
        }
        logger.info(
            "Captured \(snapshots.count, privacy: .public) standard windows for process \(processIdentifier, privacy: .public)"
        )
        return .success(snapshots)
    }

    func captureFocusedWindowForLifecycle(
        processIdentifier: pid_t,
        converter: ScreenCoordinateConverter
    ) async -> WindowCaptureResult
    {
        guard AXIsProcessTrusted()
        else
        {
            return .failed(.accessibilityPermissionRequired)
        }

        let application = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.5)
        guard let window = application.copiedElement(for: kAXFocusedWindowAttribute as CFString)
        else
        {
            return .failed(.noFocusedWindow)
        }
        AXUIElementSetMessagingTimeout(window, 0.5)
        guard isStandardWindow(window)
        else
        {
            return .failed(.unsupportedWindow)
        }
        guard let accessibilityFrame = frame(of: window)
        else
        {
            return .failed(.staleWindow)
        }
        return .captured(registeredSnapshot(
            processIdentifier: processIdentifier,
            element: window,
            accessibilityFrame: accessibilityFrame,
            converter: converter
        ))
    }

    func captureStandardWindow(
        at point: CGPoint,
        converter: ScreenCoordinateConverter
    ) async -> WindowCaptureResult
    {
        guard AXIsProcessTrusted()
        else
        {
            return .failed(.accessibilityPermissionRequired)
        }
        let accessibilityPoint = converter.accessibilityPoint(fromAppKitPoint: point)
        let systemWideElement = AXUIElementCreateSystemWide()
        var hitElement: AXUIElement?
        let hitError = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(accessibilityPoint.x),
            Float(accessibilityPoint.y),
            &hitElement
        )
        guard hitError == .success,
              let hitElement,
              let window = standardWindowAncestor(of: hitElement)
        else
        {
            return .failed(.noFocusedWindow)
        }
        AXUIElementSetMessagingTimeout(window, 0.5)
        if let failure = validationFailure(for: window)
        {
            return .failed(failure)
        }
        guard let accessibilityFrame = frame(of: window)
        else
        {
            return .failed(.staleWindow)
        }
        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(window, &processIdentifier) == .success,
              processIdentifier != ProcessInfo.processInfo.processIdentifier
        else
        {
            return .failed(.noTargetApplication)
        }
        return .captured(registeredSnapshot(
            processIdentifier: processIdentifier,
            element: window,
            accessibilityFrame: accessibilityFrame,
            converter: converter
        ))
    }

    func snapshot(
        for token: ManagedWindowToken,
        converter: ScreenCoordinateConverter
    ) async -> WindowCaptureResult
    {
        guard let record = records[token.id],
              let accessibilityFrame = frame(of: record.element)
        else
        {
            records[token.id] = nil
            lastCommands[token.id] = nil
            return .failed(.staleWindow)
        }
        return .captured(
            ManagedWindowSnapshot(
                token: token,
                processIdentifier: record.processIdentifier,
                frame: converter.appKitFrame(fromAccessibilityFrame: accessibilityFrame)
            )
        )
    }

    func apply(
        target: LayoutTarget,
        to token: ManagedWindowToken,
        converter: ScreenCoordinateConverter,
        command: LayoutCommand?,
        historyPreviousFrame: CGRect?
    ) async -> MoveResult
    {
        let execution = await move(
            target: target,
            token: token,
            converter: converter
        )
        switch execution.result
        {
        case .moved(let actualFrame), .bestEffort(let actualFrame):
            guard let previousFrame = execution.previousFrame
            else
            {
                return .failed(.staleWindow)
            }
            appendHistory(
                changes:
                [
                    WindowFrameChange(
                        token: token,
                        previousFrame: historyPreviousFrame ?? previousFrame,
                        managedFrame: actualFrame
                    )
                ],
                terminalState: nil
            )
            if let command
            {
                lastCommands[token.id] = command
            }
            return execution.result
        case .failed:
            return execution.result
        }
    }

    func applyBatch(
        _ requests: [WindowPlacementRequest],
        terminalState: TerminalArrangementState?,
        converter: ScreenCoordinateConverter
    ) async -> MoveResult
    {
        guard !requests.isEmpty,
              Set(requests.map(\.token)).count == requests.count
        else
        {
            return .failed(.noManageableWindows)
        }
        var changes: [WindowFrameChange] = []
        var rollbackStates: [WindowFrameState] = []
        var usedBestEffort = false
        let start = ContinuousClock.now
        for request in requests
        {
            let execution = await move(
                target: request.target,
                token: request.token,
                converter: converter
            )
            switch execution.result
            {
            case .moved(let actualFrame):
                guard let previousFrame = execution.previousFrame
                else
                {
                    if !rollbackStates.isEmpty
                    {
                        _ = await restoreFrames(rollbackStates, converter: converter)
                    }
                    return .failed(.staleWindow)
                }
                rollbackStates.append(WindowFrameState(
                    token: request.token,
                    frame: previousFrame
                ))
                changes.append(WindowFrameChange(
                    token: request.token,
                    previousFrame: request.historyPreviousFrame,
                    managedFrame: actualFrame
                ))
            case .bestEffort(let actualFrame):
                guard let previousFrame = execution.previousFrame
                else
                {
                    if !rollbackStates.isEmpty
                    {
                        _ = await restoreFrames(rollbackStates, converter: converter)
                    }
                    return .failed(.staleWindow)
                }
                rollbackStates.append(WindowFrameState(
                    token: request.token,
                    frame: previousFrame
                ))
                usedBestEffort = true
                changes.append(WindowFrameChange(
                    token: request.token,
                    previousFrame: request.historyPreviousFrame,
                    managedFrame: actualFrame
                ))
            case .failed(let failure):
                if !rollbackStates.isEmpty
                {
                    _ = await restoreFrames(rollbackStates, converter: converter)
                }
                return .failed(failure)
            }
        }
        appendHistory(changes: changes, terminalState: terminalState)
        for request in requests
        {
            if let command = request.command
            {
                lastCommands[request.token.id] = command
            }
        }
        guard let firstFrame = changes.first?.managedFrame
        else
        {
            return .failed(.noManageableWindows)
        }
        logger.info(
            "Applied batch of \(changes.count, privacy: .public) windows in \(start.duration(to: .now), privacy: .public)"
        )
        return usedBestEffort ? .bestEffort(firstFrame) : .moved(firstFrame)
    }

    func perform(
        _ action: WindowLifecycleAction,
        on token: ManagedWindowToken,
        converter: ScreenCoordinateConverter
    ) async -> WindowOperationResult
    {
        guard let record = records[token.id]
        else
        {
            return .failed(.staleWindow)
        }
        guard isStandardWindow(record.element)
        else
        {
            return .failed(.unsupportedWindow)
        }

        let previousFrame = action == .zoom
            ? readAppKitFrame(record.element, converter: converter)
            : nil
        let error: AXError
        switch action
        {
        case .minimize:
            guard record.element.isAttributeSettable(kAXMinimizedAttribute as CFString)
            else
            {
                return .failed(.windowActionUnavailable)
            }
            error = record.element.setBoolean(true, for: kAXMinimizedAttribute as CFString)
        case .zoom:
            guard let button = record.element.copiedElement(for: kAXZoomButtonAttribute as CFString)
            else
            {
                return .failed(.windowActionUnavailable)
            }
            error = button.perform(kAXPressAction as CFString)
        case .toggleFullScreen:
            let attribute = "AXFullScreen" as CFString
            guard record.element.isAttributeSettable(attribute)
            else
            {
                return .failed(.windowActionUnavailable)
            }
            let isFullScreen = record.element.copiedBoolean(for: attribute) == true
            error = record.element.setBoolean(!isFullScreen, for: attribute)
        case .close:
            guard let button = record.element.copiedElement(for: kAXCloseButtonAttribute as CFString)
            else
            {
                return .failed(.windowActionUnavailable)
            }
            error = button.perform(kAXPressAction as CFString)
        case .bringToFront:
            error = bringToFront(record)
        }

        guard error == .success
        else
        {
            logger.error(
                "Window action failed with AX error \(error.rawValue, privacy: .public)"
            )
            return .failed(.accessibilityFailure(error.rawValue))
        }
        if action == .zoom,
           let previousFrame
        {
            try? await Task.sleep(for: .milliseconds(100))
            if let managedFrame = readAppKitFrame(record.element, converter: converter),
               !approximatelyEqual(previousFrame, managedFrame, tolerance: 2)
            {
                appendHistory(
                    changes:
                    [
                        WindowFrameChange(
                            token: token,
                            previousFrame: previousFrame,
                            managedFrame: managedFrame
                        )
                    ],
                    terminalState: nil
                )
            }
        }
        logger.info("Window action completed: \(action.title, privacy: .public)")
        return .completed
    }

    func undoLast(converter: ScreenCoordinateConverter) async -> MoveResult
    {
        let preparation = await prepareUndo(converter: converter)
        switch preparation
        {
        case .success(let transaction):
            guard transaction.terminalState == nil
            else
            {
                return .failed(.terminalStateRestoreRequired)
            }
            return await commitPreparedUndo(
                transactionIdentifier: transaction.identifier,
                converter: converter
            )
        case .failure(let failure):
            return .failed(failure)
        }
    }

    func prepareUndo(
        converter: ScreenCoordinateConverter
    ) async -> Result<WindowArrangementTransaction, MoveFailure>
    {
        guard let transaction = history.last
        else
        {
            return .failure(.nothingToUndo)
        }
        for change in transaction.changes
        {
            guard let record = records[change.token.id],
                  let currentFrame = readAppKitFrame(record.element, converter: converter)
            else
            {
                return .failure(.staleWindow)
            }
            guard approximatelyEqual(currentFrame, change.managedFrame, tolerance: 2)
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
        guard let transaction = history.last,
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
        switch result
        {
        case .moved, .bestEffort:
            history.removeLast()
        case .failed:
            break
        }
        return result
    }

    func restoreFrames(
        _ states: [WindowFrameState],
        converter: ScreenCoordinateConverter
    ) async -> MoveResult
    {
        guard !states.isEmpty,
              Set(states.map(\.token)).count == states.count
        else
        {
            return .failed(.noManageableWindows)
        }
        let start = ContinuousClock.now
        var currentStates: [WindowFrameState] = []
        for state in states
        {
            guard let record = records[state.token.id],
                  let currentFrame = readAppKitFrame(record.element, converter: converter)
            else
            {
                return .failed(.staleWindow)
            }
            currentStates.append(WindowFrameState(token: state.token, frame: currentFrame))
        }
        var restoredFrames: [CGRect] = []
        var usedBestEffort = false
        for state in states
        {
            guard let record = records[state.token.id]
            else
            {
                rollback(currentStates, converter: converter)
                return .failed(.staleWindow)
            }
            let resize = record.element.isAttributeSettable(kAXSizeAttribute as CFString)
            let error = set(
                appKitFrame: state.frame,
                on: record.element,
                converter: converter,
                resize: resize
            )
            guard error == .success,
                  let restoredFrame = readAppKitFrame(record.element, converter: converter)
            else
            {
                rollback(currentStates, converter: converter)
                return error == .success
                    ? .failed(.staleWindow)
                    : .failed(.accessibilityFailure(error.rawValue))
            }
            if !approximatelyEqual(restoredFrame, state.frame, tolerance: 2)
            {
                usedBestEffort = true
            }
            restoredFrames.append(restoredFrame)
        }
        guard let firstFrame = restoredFrames.first
        else
        {
            return .failed(.noManageableWindows)
        }
        logger.info(
            "Restored \(restoredFrames.count, privacy: .public) windows in \(start.duration(to: .now), privacy: .public)"
        )
        return usedBestEffort ? .bestEffort(firstFrame) : .moved(firstFrame)
    }

    func lastCommand(for token: ManagedWindowToken) async -> LayoutCommand?
    {
        lastCommands[token.id]
    }

    private func move(
        target: LayoutTarget,
        token: ManagedWindowToken,
        converter: ScreenCoordinateConverter
    ) async -> (result: MoveResult, previousFrame: CGRect?)
    {
        guard let record = records[token.id]
        else
        {
            return (.failed(.staleWindow), nil)
        }
        if let failure = validationFailure(for: record.element)
        {
            return (.failed(failure), nil)
        }
        guard let previousAccessibilityFrame = frame(of: record.element)
        else
        {
            return (.failed(.staleWindow), nil)
        }
        let previousFrame = converter.appKitFrame(
            fromAccessibilityFrame: previousAccessibilityFrame
        )
        let isResizable = record.element.isAttributeSettable(kAXSizeAttribute as CFString)
        let initialError = set(
            appKitFrame: target.frame,
            on: record.element,
            converter: converter,
            resize: isResizable
        )
        if initialError != .success
        {
            _ = set(
                appKitFrame: previousFrame,
                on: record.element,
                converter: converter,
                resize: isResizable
            )
            logger.error(
                "Initial window move failed with AX error \(initialError.rawValue, privacy: .public)"
            )
            return (.failed(.accessibilityFailure(initialError.rawValue)), previousFrame)
        }

        guard let firstAccessibilityFrame = frame(of: record.element)
        else
        {
            _ = set(
                appKitFrame: previousFrame,
                on: record.element,
                converter: converter,
                resize: isResizable
            )
            return (.failed(.staleWindow), previousFrame)
        }
        let firstFrame = converter.appKitFrame(
            fromAccessibilityFrame: firstAccessibilityFrame
        )
        let alignedFrame = constrainedFrame(firstFrame, target: target)
        let alignmentError = set(
            appKitFrame: alignedFrame,
            on: record.element,
            converter: converter,
            resize: isResizable
        )
        if alignmentError != .success
        {
            _ = set(
                appKitFrame: previousFrame,
                on: record.element,
                converter: converter,
                resize: isResizable
            )
            logger.error(
                "Aligned window move failed with AX error \(alignmentError.rawValue, privacy: .public)"
            )
            return (.failed(.accessibilityFailure(alignmentError.rawValue)), previousFrame)
        }

        let tolerance = 2 / max(1, target.backingScaleFactor)
        let expectedFrame = alignedFrame
        var actualFrame = readAppKitFrame(record.element, converter: converter)
        if actualFrame.map(
        {
            !approximatelyEqual($0, expectedFrame, tolerance: tolerance)
        }) ?? true
        {
            try? await Task.sleep(for: .milliseconds(50))
            let retryError = set(
                appKitFrame: expectedFrame,
                on: record.element,
                converter: converter,
                resize: isResizable
            )
            if retryError != .success
            {
                _ = set(
                    appKitFrame: previousFrame,
                    on: record.element,
                    converter: converter,
                    resize: isResizable
                )
                logger.error(
                    "Window move retry failed with AX error \(retryError.rawValue, privacy: .public)"
                )
                return (.failed(.accessibilityFailure(retryError.rawValue)), previousFrame)
            }
            actualFrame = readAppKitFrame(record.element, converter: converter)
        }

        guard let actualFrame
        else
        {
            _ = set(
                appKitFrame: previousFrame,
                on: record.element,
                converter: converter,
                resize: isResizable
            )
            return (.failed(.staleWindow), previousFrame)
        }
        let exact = approximatelyEqual(actualFrame, target.frame, tolerance: tolerance)
        logger.info("Window move completed with exact target: \(exact, privacy: .public)")
        return (
            exact ? .moved(actualFrame) : .bestEffort(actualFrame),
            previousFrame
        )
    }

    private func appendHistory(
        changes: [WindowFrameChange],
        terminalState: TerminalArrangementState?
    )
    {
        guard !changes.isEmpty
        else
        {
            return
        }
        history.append(WindowArrangementTransaction(
            identifier: UUID(),
            changes: changes,
            terminalState: terminalState
        ))
        if history.count > 50
        {
            history.removeFirst(history.count - 50)
        }
    }

    private func rollback(
        _ states: [WindowFrameState],
        converter: ScreenCoordinateConverter
    )
    {
        for state in states
        {
            guard let record = records[state.token.id]
            else
            {
                continue
            }
            _ = set(
                appKitFrame: state.frame,
                on: record.element,
                converter: converter,
                resize: record.element.isAttributeSettable(kAXSizeAttribute as CFString)
            )
        }
    }

    private func validationFailure(for element: AXUIElement) -> MoveFailure?
    {
        guard isStandardWindow(element)
        else
        {
            return .unsupportedWindow
        }
        if element.copiedBoolean(for: kAXMinimizedAttribute as CFString) == true
        {
            return .minimizedWindow
        }
        if element.copiedBoolean(for: "AXFullScreen" as CFString) == true
        {
            return .fullScreenWindow
        }
        guard element.isAttributeSettable(kAXPositionAttribute as CFString)
        else
        {
            return .windowNotMovable
        }
        return nil
    }

    private func bringToFront(_ record: AccessibilityWindowRecord) -> AXError
    {
        let directError = record.element.perform(kAXRaiseAction as CFString)
        if directError == .success
        {
            return .success
        }
        let application = AXUIElementCreateApplication(record.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.5)
        let frontmostError = application.setBoolean(
            true,
            for: kAXFrontmostAttribute as CFString
        )
        var focusedWindowError = AXError.actionUnsupported
        if application.isAttributeSettable(kAXFocusedWindowAttribute as CFString)
        {
            focusedWindowError = application.setElement(
                record.element,
                for: kAXFocusedWindowAttribute as CFString
            )
        }
        var mainWindowError = AXError.actionUnsupported
        if record.element.isAttributeSettable(kAXMainAttribute as CFString)
        {
            mainWindowError = record.element.setBoolean(
                true,
                for: kAXMainAttribute as CFString
            )
        }
        if frontmostError == .success
            && (focusedWindowError == .success || mainWindowError == .success)
        {
            return .success
        }
        return directError
    }

    private func isStandardWindow(_ element: AXUIElement) -> Bool
    {
        element.copiedString(for: kAXRoleAttribute as CFString) == kAXWindowRole as String
            && element.copiedString(for: kAXSubroleAttribute as CFString) == kAXStandardWindowSubrole as String
    }

    private func standardWindowAncestor(of element: AXUIElement) -> AXUIElement?
    {
        var current: AXUIElement? = element
        for _ in 0..<16
        {
            guard let candidate = current
            else
            {
                return nil
            }
            if isStandardWindow(candidate)
            {
                return candidate
            }
            current = candidate.copiedElement(for: kAXParentAttribute as CFString)
        }
        return nil
    }

    private func registeredSnapshot(
        processIdentifier: pid_t,
        element: AXUIElement,
        accessibilityFrame: CGRect,
        converter: ScreenCoordinateConverter
    ) -> ManagedWindowSnapshot
    {
        if let existing = records.first(where:
        {
            $0.value.processIdentifier == processIdentifier && CFEqual($0.value.element, element)
        })
        {
            return ManagedWindowSnapshot(
                token: ManagedWindowToken(id: existing.key),
                processIdentifier: processIdentifier,
                frame: converter.appKitFrame(fromAccessibilityFrame: accessibilityFrame)
            )
        }

        let token = ManagedWindowToken(id: UUID())
        records[token.id] = AccessibilityWindowRecord(
            processIdentifier: processIdentifier,
            element: element
        )
        return ManagedWindowSnapshot(
            token: token,
            processIdentifier: processIdentifier,
            frame: converter.appKitFrame(fromAccessibilityFrame: accessibilityFrame)
        )
    }

    private func frame(of element: AXUIElement) -> CGRect?
    {
        guard let position = element.copiedPoint(for: kAXPositionAttribute as CFString),
              let size = element.copiedSize(for: kAXSizeAttribute as CFString)
        else
        {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func readAppKitFrame(
        _ element: AXUIElement,
        converter: ScreenCoordinateConverter
    ) -> CGRect?
    {
        frame(of: element).map(converter.appKitFrame(fromAccessibilityFrame:))
    }

    private func set(
        appKitFrame: CGRect,
        on element: AXUIElement,
        converter: ScreenCoordinateConverter,
        resize: Bool
    ) -> AXError
    {
        let accessibilityFrame = converter.accessibilityFrame(fromAppKitFrame: appKitFrame)
        if resize
        {
            let firstSizeError = element.setSize(accessibilityFrame.size, for: kAXSizeAttribute as CFString)
            if firstSizeError != .success
            {
                return firstSizeError
            }
        }
        let positionError = element.setPoint(accessibilityFrame.origin, for: kAXPositionAttribute as CFString)
        if positionError != .success
        {
            return positionError
        }
        if resize
        {
            return element.setSize(accessibilityFrame.size, for: kAXSizeAttribute as CFString)
        }
        return .success
    }

    private func constrainedFrame(_ actualFrame: CGRect, target: LayoutTarget) -> CGRect
    {
        var origin = actualFrame.origin
        if target.edges.contains(.left) && !target.edges.contains(.right)
        {
            origin.x = target.frame.minX
        }
        else if target.edges.contains(.right) && !target.edges.contains(.left)
        {
            origin.x = target.frame.maxX - actualFrame.width
        }
        else
        {
            origin.x = target.frame.midX - actualFrame.width / 2
        }

        if target.edges.contains(.bottom) && !target.edges.contains(.top)
        {
            origin.y = target.frame.minY
        }
        else if target.edges.contains(.top) && !target.edges.contains(.bottom)
        {
            origin.y = target.frame.maxY - actualFrame.height
        }
        else
        {
            origin.y = target.frame.midY - actualFrame.height / 2
        }

        let horizontalReach = min(actualFrame.width, 80)
        let verticalReach = min(actualFrame.height, 44)
        origin.x = min(
            max(origin.x, target.visibleFrame.minX - actualFrame.width + horizontalReach),
            target.visibleFrame.maxX - horizontalReach
        )
        origin.y = min(
            max(origin.y, target.visibleFrame.minY - actualFrame.height + verticalReach),
            target.visibleFrame.maxY - verticalReach
        )
        return CGRect(origin: origin, size: actualFrame.size)
    }

    private func approximatelyEqual(_ first: CGRect, _ second: CGRect, tolerance: CGFloat) -> Bool
    {
        abs(first.minX - second.minX) <= tolerance
            && abs(first.minY - second.minY) <= tolerance
            && abs(first.width - second.width) <= tolerance
            && abs(first.height - second.height) <= tolerance
    }

}
