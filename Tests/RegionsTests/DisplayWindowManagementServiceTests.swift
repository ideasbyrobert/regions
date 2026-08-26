import CoreGraphics
import XCTest

@testable import Regions

@MainActor
final class DisplayWindowManagementServiceTests: XCTestCase
{
    func testMovesOffDisplayWindowsAsOneUndoableTransaction() async
    {
        let first = makeWindow(
            frame: CGRect(x: 100, y: 100, width: 400, height: 300)
        )
        let second = makeWindow(
            frame: CGRect(x: 1_200, y: 100, width: 400, height: 300)
        )
        let original = [first, second]
        let manager = FakeWindowManager(windows: original)
        let service = makeService(manager: manager)

        let result = await service.moveAppWindows(
            processIdentifier: 42,
            to: rightScreen,
            screens: [leftScreen, rightScreen],
            spacing: 8,
            converter: converter
        )

        XCTAssertEqual(result, .moved(windowCount: 1, usedBestEffort: false))
        let moved = await manager.currentWindows()
        let transactionCount = await manager.transactionCount()
        XCTAssertTrue(rightScreen.visibleFrame.contains(moved[0].frame))
        XCTAssertEqual(moved[1].frame, second.frame)
        XCTAssertEqual(transactionCount, 1)

        _ = await manager.undoLast(converter: converter)

        let restored = await manager.currentWindows()
        XCTAssertEqual(restored, original)
    }

    func testPreservesKnownLayoutCommandOnDestination() async
    {
        let window = makeWindow(
            frame: CGRect(x: 0, y: 0, width: 500, height: 800)
        )
        let manager = FakeWindowManager(windows: [window])
        await manager.setLastCommand(.preset(.leftHalf), for: window.token)
        let service = makeService(manager: manager)

        let result = await service.moveAppWindows(
            processIdentifier: 42,
            to: rightScreen,
            screens: [leftScreen, rightScreen],
            spacing: 8,
            converter: converter
        )

        XCTAssertEqual(result, .moved(windowCount: 1, usedBestEffort: false))
        let moved = await manager.currentWindows()[0]
        let expected = GridLayoutCalculator().target(
            for: .preset(.leftHalf),
            on: rightScreen,
            currentWindowFrame: window.frame,
            spacing: 8
        )
        XCTAssertEqual(moved.frame, expected.frame)
    }

    func testAlreadyGatheredWindowsDoNotCreateUndoTransaction() async
    {
        let window = makeWindow(
            frame: CGRect(x: 1_100, y: 100, width: 400, height: 300)
        )
        let manager = FakeWindowManager(windows: [window])
        let service = makeService(manager: manager)

        let result = await service.moveAppWindows(
            processIdentifier: 42,
            to: rightScreen,
            screens: [leftScreen, rightScreen],
            spacing: 8,
            converter: converter
        )

        let transactionCount = await manager.transactionCount()
        XCTAssertEqual(result, .alreadyOnDisplay)
        XCTAssertEqual(transactionCount, 0)
    }

    func testMissingDisplayTopologyDoesNotMoveWindows() async
    {
        let window = makeWindow(
            frame: CGRect(x: 100, y: 100, width: 400, height: 300)
        )
        let manager = FakeWindowManager(windows: [window])
        let service = makeService(manager: manager)

        let result = await service.moveAppWindows(
            processIdentifier: 42,
            to: rightScreen,
            screens: [],
            spacing: 8,
            converter: converter
        )

        let current = await manager.currentWindows()
        let transactionCount = await manager.transactionCount()
        XCTAssertEqual(result, .failed(.noDisplays))
        XCTAssertEqual(current, [window])
        XCTAssertEqual(transactionCount, 0)
    }

    func testBatchFailureLeavesEveryWindowAndUndoHistoryUntouched() async
    {
        let first = makeWindow(
            frame: CGRect(x: 100, y: 100, width: 400, height: 300)
        )
        let second = makeWindow(
            frame: CGRect(x: 500, y: 100, width: 400, height: 300)
        )
        let original = [first, second]
        let manager = FakeWindowManager(windows: original)
        await manager.setBatchFailure(.accessibilityFailure(-25205))
        let service = makeService(manager: manager)

        let result = await service.moveAppWindows(
            processIdentifier: 42,
            to: rightScreen,
            screens: [leftScreen, rightScreen],
            spacing: 8,
            converter: converter
        )

        let current = await manager.currentWindows()
        let transactionCount = await manager.transactionCount()
        XCTAssertEqual(result, .failed(.accessibilityFailure(-25205)))
        XCTAssertEqual(current, original)
        XCTAssertEqual(transactionCount, 0)
    }

    private var leftScreen: ScreenSnapshot
    {
        ScreenSnapshot(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            backingScaleFactor: 2
        )
    }

    private var rightScreen: ScreenSnapshot
    {
        ScreenSnapshot(
            displayID: 2,
            frame: CGRect(x: 1_000, y: 0, width: 1_000, height: 800),
            visibleFrame: CGRect(x: 1_000, y: 0, width: 1_000, height: 800),
            backingScaleFactor: 2
        )
    }

    private var converter: ScreenCoordinateConverter
    {
        ScreenCoordinateConverter(primaryDisplayMaximumY: 800)
    }

    private func makeWindow(frame: CGRect) -> ManagedWindowSnapshot
    {
        ManagedWindowSnapshot(
            token: ManagedWindowToken(id: UUID()),
            processIdentifier: 42,
            frame: frame
        )
    }

    private func makeService(
        manager: FakeWindowManager
    ) -> DisplayWindowManagementService
    {
        DisplayWindowManagementService(
            windowManager: manager,
            displayProvider: DisplaySnapshotProvider(),
            calculator: GridLayoutCalculator(),
            transferCalculator: DisplayTransferCalculator()
        )
    }
}
