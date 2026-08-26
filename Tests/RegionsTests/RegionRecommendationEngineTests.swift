import CoreGraphics
import XCTest

@testable import Regions

final class RegionRecommendationEngineTests: XCTestCase
{
    private let engine = RegionRecommendationEngine()

    func testLandscapeUsesHorizontalVocabulary()
    {
        let context = makeContext(
            visibleFrame: CGRect(x: 100, y: 50, width: 1200, height: 800),
            windowFrame: CGRect(x: 100, y: 50, width: 300, height: 800)
        )
        let placement = engine.initialPlacement(for: context)

        XCTAssertEqual(context.orientation, .landscape)
        XCTAssertEqual(placement.position, .leading)
        XCTAssertEqual(placement.size, .quarter)
    }

    func testPortraitUsesVerticalVocabulary()
    {
        let context = makeContext(
            visibleFrame: CGRect(x: 0, y: 0, width: 600, height: 1000),
            windowFrame: CGRect(x: 0, y: 750, width: 600, height: 250)
        )
        let placement = engine.initialPlacement(for: context)

        XCTAssertEqual(context.orientation, .portrait)
        XCTAssertEqual(placement.position, .leading)
        XCTAssertEqual(placement.size, .quarter)
    }

    func testCenterAndSideSizeVocabulariesAreDistinct()
    {
        let context = makeContext(
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            windowFrame: CGRect(x: 250, y: 0, width: 500, height: 800)
        )

        XCTAssertEqual(
            engine.sizes(for: .leading, context: context),
            [.quarter, .half, .seventy]
        )
        XCTAssertEqual(
            engine.sizes(for: .center, context: context),
            [.half, .seventy, .ninety]
        )
    }

    func testNonResizableWindowRemovesFillAndSizes()
    {
        let context = makeContext(
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            windowFrame: CGRect(x: 0, y: 0, width: 500, height: 400),
            isResizable: false
        )

        XCTAssertEqual(
            engine.positions(for: context),
            [.leading, .center, .trailing]
        )
        XCTAssertTrue(
            engine.sizes(for: .center, context: context).isEmpty
        )
    }

    private func makeContext(
        visibleFrame: CGRect,
        windowFrame: CGRect,
        isResizable: Bool = true
    ) -> RegionContext
    {
        let screen = ScreenSnapshot(
            displayID: 1,
            frame: visibleFrame,
            visibleFrame: visibleFrame,
            backingScaleFactor: 2
        )
        return RegionContext(
            window: ManagedWindowSnapshot(
                token: ManagedWindowToken(id: UUID()),
                processIdentifier: 42,
                frame: windowFrame,
                isResizable: isResizable
            ),
            screen: screen,
            applicationWindowCount: 1,
            displayCount: 1,
            isTerminal: false,
            hasSavedLayout: false,
            savedWindowCount: nil,
            canUndo: false
        )
    }
}
