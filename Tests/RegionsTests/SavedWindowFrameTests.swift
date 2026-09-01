import CoreGraphics
import XCTest
@testable import Regions

final class SavedWindowFrameTests: XCTestCase
{
    func testRoundTripAcrossSameVisibleFrame()
    {
        let visibleFrame = CGRect(x: 40, y: 80, width: 1200, height: 800)
        let original = CGRect(x: 340, y: 280, width: 600, height: 400)
        let saved = SavedWindowFrame(frame: original, within: visibleFrame)
        let screen = ScreenSnapshot(
            displayID: 1,
            frame: visibleFrame,
            visibleFrame: visibleFrame,
            backingScaleFactor: 2
        )

        XCTAssertEqual(saved.target(on: screen).frame, original)
    }

    func testLayoutScalesToDifferentVisibleFrame()
    {
        let saved = SavedWindowFrame(
            frame: CGRect(x: 0, y: 0, width: 500, height: 400),
            within: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )
        let screen = ScreenSnapshot(
            displayID: 1,
            frame: CGRect(x: 100, y: 50, width: 2000, height: 1200),
            visibleFrame: CGRect(x: 100, y: 50, width: 2000, height: 1200),
            backingScaleFactor: 2
        )

        XCTAssertEqual(
            saved.target(on: screen).frame,
            CGRect(x: 100, y: 50, width: 1000, height: 600)
        )
    }

    func testOutOfBoundsFrameIsClampedInsideVisibleFrame()
    {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let saved = SavedWindowFrame(
            frame: CGRect(x: -200, y: 700, width: 600, height: 400),
            within: visibleFrame
        )
        let screen = ScreenSnapshot(
            displayID: 1,
            frame: visibleFrame,
            visibleFrame: visibleFrame,
            backingScaleFactor: 2
        )
        let result = saved.target(on: screen).frame

        XCTAssertGreaterThanOrEqual(result.minX, visibleFrame.minX)
        XCTAssertGreaterThanOrEqual(result.minY, visibleFrame.minY)
        XCTAssertLessThanOrEqual(result.maxX, visibleFrame.maxX)
        XCTAssertLessThanOrEqual(result.maxY, visibleFrame.maxY)
    }
}
