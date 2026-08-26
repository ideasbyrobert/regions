import CoreGraphics
import XCTest

@testable import Regions

@MainActor
final class DisplaySnapshotProviderTests: XCTestCase
{
    private let provider = DisplaySnapshotProvider()

    func testScreenSelectionUsesGreatestIntersection()
    {
        let screens = makeScreens()
        let frame = CGRect(x: 850, y: 100, width: 400, height: 400)

        let result = provider.screen(containing: frame, in: screens)

        XCTAssertEqual(result?.displayID, 2)
    }

    func testScreenSelectionFallsBackToNearestCenter()
    {
        let screens = makeScreens()
        let frame = CGRect(x: 2500, y: 100, width: 100, height: 100)

        let result = provider.screen(containing: frame, in: screens)

        XCTAssertEqual(result?.displayID, 2)
    }

    func testAdjacentDisplayOrderingWraps()
    {
        let screens = makeScreens()

        let previous = provider.adjacent(
            to: screens[0], direction: .previous, in: screens)
        let next = provider.adjacent(
            to: screens[1], direction: .next, in: screens)

        XCTAssertEqual(previous?.displayID, 2)
        XCTAssertEqual(next?.displayID, 1)
    }

    private func makeScreens() -> [ScreenSnapshot]
    {
        [
            ScreenSnapshot(
                displayID: 1,
                frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
                visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 760),
                backingScaleFactor: 2
            ),
            ScreenSnapshot(
                displayID: 2,
                frame: CGRect(x: 1000, y: 0, width: 1200, height: 900),
                visibleFrame: CGRect(x: 1000, y: 0, width: 1200, height: 860),
                backingScaleFactor: 1
            ),
        ]
    }
}
