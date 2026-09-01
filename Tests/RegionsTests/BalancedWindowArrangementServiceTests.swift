import CoreGraphics
import XCTest
@testable import Regions

@MainActor
final class BalancedWindowArrangementServiceTests: XCTestCase
{
    func testGenericFiveWindowArrangementUsesBalancedRows() async
    {
        let original = makeWindows(count: 5, size: CGSize(width: 160, height: 120))
        let manager = FakeWindowManager(
            windows: original,
            captureQueue: [original]
        )
        let terminal = FakeTerminalWindowSizing(
            authorizationState: .notRequested,
            currentStates: []
        )
        let service = makeService(manager: manager, terminal: terminal)

        let result = await service.arrange(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Editor",
            targetScreen: screen,
            spacing: 10,
            converter: converter
        )

        XCTAssertEqual(
            result,
            .arranged(windowCount: 5, usedBestEffort: false, terminalSized: false)
        )
        let arranged = await manager.currentWindows()
        let yValues = Dictionary(grouping: arranged, by: { $0.frame.minY })
            .values
            .map(\.count)
            .sorted(by: >)
        let transactionCount = await manager.transactionCount()
        XCTAssertEqual(yValues, [3, 2])
        XCTAssertEqual(transactionCount, 1)
    }

    func testTerminalAutomationDenialLeavesFramesUnchanged() async
    {
        let original = makeWindows(count: 2, size: CGSize(width: 180, height: 100))
        let manager = FakeWindowManager(
            windows: original,
            captureQueue: [original]
        )
        let terminal = FakeTerminalWindowSizing(
            authorizationState: .denied,
            currentStates: terminalStates(count: 2)
        )
        let service = makeService(manager: manager, terminal: terminal)

        let result = await service.arrange(
            processIdentifier: 42,
            bundleIdentifier: TerminalWindowSizingService.bundleIdentifier,
            targetScreen: screen,
            spacing: 10,
            converter: converter
        )

        let currentWindows = await manager.currentWindows()
        XCTAssertEqual(result, .failed(.terminal(.automation(.denied))))
        XCTAssertEqual(currentWindows, original)
        XCTAssertTrue(terminal.appliedStates.isEmpty)
    }

    func testTerminalSizingFailureRollsBackDimensionsAndFrames() async
    {
        let original = makeWindows(count: 2, size: CGSize(width: 180, height: 100))
        let previousStates = terminalStates(count: 2)
        let manager = FakeWindowManager(
            windows: original,
            captureQueue: [original]
        )
        let terminal = FakeTerminalWindowSizing(
            authorizationState: .allowed,
            currentStates: previousStates
        )
        terminal.failNextApply(with: .scriptFailure(code: -1708, message: "Rejected"))
        let service = makeService(manager: manager, terminal: terminal)

        let result = await service.arrange(
            processIdentifier: 42,
            bundleIdentifier: TerminalWindowSizingService.bundleIdentifier,
            targetScreen: screen,
            spacing: 10,
            converter: converter
        )

        XCTAssertEqual(
            result,
            .failed(.terminal(.scriptFailure(code: -1708, message: "Rejected")))
        )
        let currentWindows = await manager.currentWindows()
        let transactionCount = await manager.transactionCount()
        XCTAssertEqual(terminal.currentStates, previousStates)
        XCTAssertEqual(currentWindows, original)
        XCTAssertEqual(terminal.appliedStates.count, 2)
        XCTAssertEqual(transactionCount, 0)
    }

    func testTerminalLayoutThatDoesNotFitRollsBackWithoutTransaction() async
    {
        let original = makeWindows(count: 8, size: CGSize(width: 180, height: 100))
        let resized = replacingSizes(
            in: original,
            with: CGSize(width: 300, height: 300)
        )
        let previousStates = terminalStates(count: 8)
        let manager = FakeWindowManager(
            windows: original,
            captureQueue: [original, resized]
        )
        let terminal = FakeTerminalWindowSizing(
            authorizationState: .allowed,
            currentStates: previousStates
        )
        let service = makeService(manager: manager, terminal: terminal)

        let result = await service.arrange(
            processIdentifier: 42,
            bundleIdentifier: TerminalWindowSizingService.bundleIdentifier,
            targetScreen: screen,
            spacing: 10,
            converter: converter
        )

        guard case .failed(.doesNotFit) = result
        else
        {
            XCTFail("Expected exact-size fit rejection")
            return
        }
        let currentWindows = await manager.currentWindows()
        let transactionCount = await manager.transactionCount()
        XCTAssertEqual(terminal.currentStates, previousStates)
        XCTAssertEqual(currentWindows, original)
        XCTAssertEqual(transactionCount, 0)
    }

    func testTerminalArrangementAndUndoRestoreWholeBatch() async
    {
        let original = makeWindows(count: 5, size: CGSize(width: 180, height: 100))
        let resized = replacingSizes(
            in: original,
            with: CGSize(width: 160, height: 90)
        )
        let previousStates = terminalStates(count: 5)
        let managedStates = TerminalWindowSizingService.managedStates(from: previousStates)
        let manager = FakeWindowManager(
            windows: original,
            captureQueue: [original, resized]
        )
        let terminal = FakeTerminalWindowSizing(
            authorizationState: .allowed,
            currentStates: previousStates
        )
        let service = makeService(manager: manager, terminal: terminal)

        let arrangement = await service.arrange(
            processIdentifier: 42,
            bundleIdentifier: TerminalWindowSizingService.bundleIdentifier,
            targetScreen: screen,
            spacing: 10,
            converter: converter
        )
        XCTAssertEqual(
            arrangement,
            .arranged(windowCount: 5, usedBestEffort: false, terminalSized: true)
        )
        let arrangedTransactionCount = await manager.transactionCount()
        XCTAssertEqual(terminal.currentStates, managedStates)
        XCTAssertEqual(arrangedTransactionCount, 1)

        let restore = await service.restorePrevious(converter: converter)

        XCTAssertEqual(
            restore,
            .restored(windowCount: 5, usedBestEffort: false)
        )
        let restoredWindows = await manager.currentWindows()
        let restoredTransactionCount = await manager.transactionCount()
        XCTAssertEqual(terminal.currentStates, previousStates)
        XCTAssertEqual(restoredWindows, original)
        XCTAssertEqual(restoredTransactionCount, 0)
    }

    func testChangedTerminalDimensionsPreventAtomicUndo() async
    {
        let original = makeWindows(count: 2, size: CGSize(width: 180, height: 100))
        let resized = replacingSizes(
            in: original,
            with: CGSize(width: 160, height: 90)
        )
        let previousStates = terminalStates(count: 2)
        let manager = FakeWindowManager(
            windows: original,
            captureQueue: [original, resized]
        )
        let terminal = FakeTerminalWindowSizing(
            authorizationState: .allowed,
            currentStates: previousStates
        )
        let service = makeService(manager: manager, terminal: terminal)
        _ = await service.arrange(
            processIdentifier: 42,
            bundleIdentifier: TerminalWindowSizingService.bundleIdentifier,
            targetScreen: screen,
            spacing: 10,
            converter: converter
        )
        let arrangedFrames = await manager.currentWindows()
        terminal.replaceCurrentStates([
            TerminalWindowState(windowIdentifier: 1, columns: 79, rows: 48),
            TerminalWindowState(windowIdentifier: 2, columns: 80, rows: 48)
        ])

        let restore = await service.restorePrevious(converter: converter)

        let currentWindows = await manager.currentWindows()
        let transactionCount = await manager.transactionCount()
        XCTAssertEqual(restore, .failed(.move(.windowChanged)))
        XCTAssertEqual(currentWindows, arrangedFrames)
        XCTAssertEqual(transactionCount, 1)
    }

    func testNineWindowsAreRejectedWithoutMutation() async
    {
        let original = makeWindows(count: 9, size: CGSize(width: 160, height: 120))
        let manager = FakeWindowManager(
            windows: original,
            captureQueue: [original]
        )
        let terminal = FakeTerminalWindowSizing(
            authorizationState: .notRequested,
            currentStates: []
        )
        let service = makeService(manager: manager, terminal: terminal)

        let result = await service.arrange(
            processIdentifier: 42,
            bundleIdentifier: "com.example.Editor",
            targetScreen: screen,
            spacing: 10,
            converter: converter
        )

        let currentWindows = await manager.currentWindows()
        let transactionCount = await manager.transactionCount()
        XCTAssertEqual(result, .failed(.tooManyWindows(9)))
        XCTAssertEqual(currentWindows, original)
        XCTAssertEqual(transactionCount, 0)
    }

    func testTerminalWindowSetMismatchFailsBeforeSizing() async
    {
        let original = makeWindows(count: 2, size: CGSize(width: 180, height: 100))
        let manager = FakeWindowManager(
            windows: original,
            captureQueue: [original]
        )
        let terminal = FakeTerminalWindowSizing(
            authorizationState: .allowed,
            currentStates: terminalStates(count: 1)
        )
        let service = makeService(manager: manager, terminal: terminal)

        let result = await service.arrange(
            processIdentifier: 42,
            bundleIdentifier: TerminalWindowSizingService.bundleIdentifier,
            targetScreen: screen,
            spacing: 10,
            converter: converter
        )

        let currentWindows = await manager.currentWindows()
        let transactionCount = await manager.transactionCount()
        XCTAssertEqual(
            result,
            .failed(.terminalWindowCountMismatch(accessibility: 2, automation: 1))
        )
        XCTAssertEqual(currentWindows, original)
        XCTAssertTrue(terminal.appliedStates.isEmpty)
        XCTAssertEqual(transactionCount, 0)
    }

    private var screen: ScreenSnapshot
    {
        ScreenSnapshot(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 600),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 600),
            backingScaleFactor: 2
        )
    }

    private var converter: ScreenCoordinateConverter
    {
        ScreenCoordinateConverter(primaryDisplayMaximumY: 600)
    }

    private func makeService(
        manager: FakeWindowManager,
        terminal: FakeTerminalWindowSizing
    ) -> BalancedWindowArrangementService
    {
        BalancedWindowArrangementService(
            windowManager: manager,
            terminalWindowSizing: terminal,
            calculator: GridLayoutCalculator()
        )
    }

    private func makeWindows(
        count: Int,
        size: CGSize
    ) -> [ManagedWindowSnapshot]
    {
        (0..<count).map
        {
            index in
            ManagedWindowSnapshot(
                token: ManagedWindowToken(id: UUID()),
                processIdentifier: 42,
                frame: CGRect(
                    x: CGFloat(index * 23),
                    y: CGFloat(index * 17),
                    width: size.width,
                    height: size.height
                )
            )
        }
    }

    private func replacingSizes(
        in windows: [ManagedWindowSnapshot],
        with size: CGSize
    ) -> [ManagedWindowSnapshot]
    {
        windows.map
        {
            ManagedWindowSnapshot(
                token: $0.token,
                processIdentifier: $0.processIdentifier,
                frame: CGRect(origin: $0.frame.origin, size: size)
            )
        }
    }

    private func terminalStates(count: Int) -> [TerminalWindowState]
    {
        (1...count).map
        {
            TerminalWindowState(
                windowIdentifier: Int32($0),
                columns: 100 + $0,
                rows: 30 + $0
            )
        }
    }
}
