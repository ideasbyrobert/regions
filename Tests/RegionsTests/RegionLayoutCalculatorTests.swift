import CoreGraphics
import XCTest

@testable import Regions

final class RegionLayoutCalculatorTests: XCTestCase
{
    private let calculator = GridLayoutCalculator()

    func testLandscapeSideAndCenterPercentages()
    {
        let screen = makeScreen(width: 1000, height: 800)

        XCTAssertEqual(
            target(.leading, .quarter, .landscape, screen: screen).frame,
            CGRect(x: 0, y: 0, width: 250, height: 800)
        )
        XCTAssertEqual(
            target(.center, .half, .landscape, screen: screen).frame,
            CGRect(x: 250, y: 0, width: 500, height: 800)
        )
        XCTAssertEqual(
            target(.trailing, .seventy, .landscape, screen: screen).frame,
            CGRect(x: 300, y: 0, width: 700, height: 800)
        )
    }

    func testPortraitTopCenterAndBottomPercentages()
    {
        let screen = makeScreen(width: 600, height: 900)

        XCTAssertEqual(
            target(.leading, .quarter, .portrait, screen: screen).frame,
            CGRect(x: 0, y: 675, width: 600, height: 225)
        )
        XCTAssertEqual(
            target(.center, .half, .portrait, screen: screen).frame,
            CGRect(x: 0, y: 225, width: 600, height: 450)
        )
        XCTAssertEqual(
            target(.trailing, .seventy, .portrait, screen: screen).frame,
            CGRect(x: 0, y: 0, width: 600, height: 630)
        )
    }

    func testCenterHalfCreatesTwentyFiveFiftyTwentyFive()
    {
        let screen = makeScreen(width: 1200, height: 800)
        let frame = target(
            .center,
            .half,
            .landscape,
            screen: screen
        ).frame

        XCTAssertEqual(frame.minX, 300)
        XCTAssertEqual(frame.width, 600)
        XCTAssertEqual(screen.visibleFrame.maxX - frame.maxX, 300)
    }

    func testNonResizablePlacementKeepsSize()
    {
        let screen = makeScreen(width: 1000, height: 800)
        let current = CGRect(x: 300, y: 200, width: 300, height: 200)
        let placement = RegionPlacement(
            orientation: .landscape,
            position: .trailing,
            size: nil
        )
        let target = calculator.target(
            for: .region(placement),
            on: screen,
            currentWindowFrame: current,
            spacing: 0
        )

        XCTAssertEqual(
            target.frame,
            CGRect(x: 700, y: 300, width: 300, height: 200)
        )
    }

    func testRefinementStaysInsideVisibleFrame()
    {
        let screen = makeScreen(width: 1000, height: 800)
        let placement = RegionPlacement(
            orientation: .landscape,
            position: .center,
            size: .half,
            horizontalOffset: 1000,
            verticalOffset: -1000,
            widthDelta: 32,
            heightDelta: -32
        )
        let result = calculator.target(
            for: .region(placement),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 8
        )

        XCTAssertTrue(screen.visibleFrame.contains(result.frame))
        XCTAssertEqual(result.frame.maxX, 992)
        XCTAssertEqual(result.frame.minY, 8)
    }

    private func target(
        _ position: RegionPosition,
        _ size: RegionSize,
        _ orientation: RegionOrientation,
        screen: ScreenSnapshot
    ) -> LayoutTarget
    {
        calculator.target(
            for: .region(
                RegionPlacement(
                    orientation: orientation,
                    position: position,
                    size: size
                )),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )
    }

    private func makeScreen(
        width: CGFloat,
        height: CGFloat
    ) -> ScreenSnapshot
    {
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        return ScreenSnapshot(
            displayID: 1,
            frame: frame,
            visibleFrame: frame,
            backingScaleFactor: 2
        )
    }
}
