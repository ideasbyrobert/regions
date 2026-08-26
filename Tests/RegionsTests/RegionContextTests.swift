import CoreGraphics
import XCTest

@testable import Regions

final class RegionContextTests: XCTestCase
{
    func testContextExposesOnlySupportedBatchAndRestoreActions()
    {
        XCTAssertFalse(makeContext(windowCount: 1).canArrangeApplication)
        XCTAssertTrue(makeContext(windowCount: 2).canArrangeApplication)
        XCTAssertTrue(makeContext(windowCount: 8).canArrangeApplication)
        XCTAssertFalse(makeContext(windowCount: 9).canArrangeApplication)
        XCTAssertTrue(
            makeContext(
                windowCount: 3,
                hasSavedLayout: true,
                savedWindowCount: 3
            ).canRestoreSavedLayout
        )
        XCTAssertFalse(
            makeContext(
                windowCount: 3,
                hasSavedLayout: true,
                savedWindowCount: 2
            ).canRestoreSavedLayout
        )
    }

    private func makeContext(
        windowCount: Int,
        hasSavedLayout: Bool = false,
        savedWindowCount: Int? = nil
    ) -> RegionContext
    {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let screen = ScreenSnapshot(
            displayID: 1,
            frame: frame,
            visibleFrame: frame,
            backingScaleFactor: 2
        )
        return RegionContext(
            window: ManagedWindowSnapshot(
                token: ManagedWindowToken(id: UUID()),
                processIdentifier: 42,
                frame: frame
            ),
            screen: screen,
            applicationWindowCount: windowCount,
            displayCount: 1,
            isTerminal: false,
            hasSavedLayout: hasSavedLayout,
            savedWindowCount: savedWindowCount,
            canUndo: false
        )
    }
}
