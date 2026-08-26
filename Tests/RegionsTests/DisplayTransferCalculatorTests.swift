import CoreGraphics
import XCTest

@testable import Regions

final class DisplayTransferCalculatorTests: XCTestCase
{
    func testTransferPreservesNormalizedSizeAndPosition()
    {
        let source = ScreenSnapshot(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            backingScaleFactor: 2
        )
        let destination = ScreenSnapshot(
            displayID: 2,
            frame: CGRect(x: 1000, y: 0, width: 2000, height: 1600),
            visibleFrame: CGRect(x: 1000, y: 0, width: 2000, height: 1600),
            backingScaleFactor: 2
        )
        let currentFrame = CGRect(x: 250, y: 200, width: 500, height: 400)

        let target = DisplayTransferCalculator().target(
            for: currentFrame,
            from: source,
            to: destination,
            spacing: 0
        )

        XCTAssertEqual(
            target.frame, CGRect(x: 1500, y: 400, width: 1000, height: 800))
    }

    func testTransferClampsWindowToSmallerDestination()
    {
        let source = ScreenSnapshot(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 2000, height: 1600),
            visibleFrame: CGRect(x: 0, y: 0, width: 2000, height: 1600),
            backingScaleFactor: 1
        )
        let destination = ScreenSnapshot(
            displayID: 2,
            frame: CGRect(x: -800, y: 0, width: 800, height: 600),
            visibleFrame: CGRect(x: -800, y: 0, width: 800, height: 600),
            backingScaleFactor: 1
        )

        let target = DisplayTransferCalculator().target(
            for: CGRect(x: 0, y: 0, width: 2600, height: 1800),
            from: source,
            to: destination,
            spacing: 8
        )

        XCTAssertTrue(destination.visibleFrame.contains(target.frame))
        XCTAssertLessThanOrEqual(target.frame.width, 784)
        XCTAssertLessThanOrEqual(target.frame.height, 584)
    }
}
