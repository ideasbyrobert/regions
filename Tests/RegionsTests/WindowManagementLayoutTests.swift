import CoreGraphics
import XCTest

@testable import Regions

final class WindowManagementLayoutTests: XCTestCase
{
    private let calculator = GridLayoutCalculator()
    private let screen = ScreenSnapshot(
        displayID: 1,
        frame: CGRect(x: 0, y: 0, width: 1200, height: 900),
        visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
        backingScaleFactor: 2
    )
    private let currentFrame = CGRect(x: 300, y: 250, width: 600, height: 400)

    func testEveryPresetProducesAVisiblePositiveFrame()
    {
        for preset in LayoutPreset.allCases
        {
            let target = target(for: .preset(preset), spacing: 8)

            XCTAssertTrue(
                screen.visibleFrame.contains(target.frame), preset.title)
            XCTAssertGreaterThan(target.frame.width, 0, preset.title)
            XCTAssertGreaterThan(target.frame.height, 0, preset.title)
        }
    }

    func testHorizontalThirdsUseExpectedScreenRegions()
    {
        XCTAssertEqual(
            target(for: .preset(.leftThird)).frame,
            CGRect(x: 0, y: 0, width: 400, height: 900)
        )
        XCTAssertEqual(
            target(for: .preset(.centerThird)).frame,
            CGRect(x: 400, y: 0, width: 400, height: 900)
        )
        XCTAssertEqual(
            target(for: .preset(.rightTwoThirds)).frame,
            CGRect(x: 400, y: 0, width: 800, height: 900)
        )
    }

    func testVerticalThirdsUseExpectedScreenRegions()
    {
        XCTAssertEqual(
            target(for: .preset(.topThird)).frame,
            CGRect(x: 0, y: 600, width: 1200, height: 300)
        )
        XCTAssertEqual(
            target(for: .preset(.middleThird)).frame,
            CGRect(x: 0, y: 300, width: 1200, height: 300)
        )
        XCTAssertEqual(
            target(for: .preset(.bottomTwoThirds)).frame,
            CGRect(x: 0, y: 0, width: 1200, height: 600)
        )
    }

    func testCenteredSizesUseScreenFractions()
    {
        XCTAssertEqual(
            target(for: .preset(.centeredHalf)).frame,
            CGRect(x: 300, y: 225, width: 600, height: 450)
        )
        XCTAssertEqual(
            target(for: .preset(.centeredThreeQuarters)).frame,
            CGRect(x: 150, y: 112.5, width: 900, height: 675)
        )
        XCTAssertEqual(
            target(for: .preset(.almostFill)).frame,
            CGRect(x: 60, y: 45, width: 1080, height: 810)
        )
    }

    func testAxisMaximizationPreservesOtherDimension()
    {
        let widthTarget = target(for: .preset(.maximizeWidth))
        let heightTarget = target(for: .preset(.maximizeHeight))

        XCTAssertEqual(
            widthTarget.frame, CGRect(x: 0, y: 250, width: 1200, height: 400))
        XCTAssertEqual(
            heightTarget.frame, CGRect(x: 300, y: 0, width: 600, height: 900))
    }

    func testMoveCommandsPreserveSizeAndReachEdges()
    {
        let topLeft = target(for: .move(.topLeftCorner))
        let right = target(for: .move(.rightEdge))
        let center = target(for: .move(.center))

        XCTAssertEqual(
            topLeft.frame, CGRect(x: 0, y: 500, width: 600, height: 400))
        XCTAssertEqual(topLeft.edges, [.left, .top])
        XCTAssertEqual(
            right.frame, CGRect(x: 600, y: 250, width: 600, height: 400))
        XCTAssertEqual(right.edges, [.right])
        XCTAssertEqual(
            center.frame, CGRect(x: 300, y: 250, width: 600, height: 400))
    }

    func testNudgeAndResizeCommandsRemainWithinVisibleFrame()
    {
        let moved = target(for: .adjustment(.moveRight, amount: 40))
        let grown = target(for: .adjustment(.grow, amount: 40))
        let narrowed = target(for: .adjustment(.narrow, amount: 40))

        XCTAssertEqual(
            moved.frame, CGRect(x: 340, y: 250, width: 600, height: 400))
        XCTAssertEqual(
            grown.frame, CGRect(x: 260, y: 210, width: 680, height: 480))
        XCTAssertEqual(
            narrowed.frame, CGRect(x: 340, y: 250, width: 520, height: 400))
        XCTAssertTrue(screen.visibleFrame.contains(moved.frame))
        XCTAssertTrue(screen.visibleFrame.contains(grown.frame))
        XCTAssertTrue(screen.visibleFrame.contains(narrowed.frame))
    }

    func testRepeatedAdjustmentClampsAtScreenBoundary()
    {
        let edgeFrame = CGRect(x: 0, y: 0, width: 600, height: 400)
        let target = calculator.target(
            for: .adjustment(.moveLeft, amount: 128),
            on: screen,
            currentWindowFrame: edgeFrame,
            spacing: 0
        )

        XCTAssertEqual(target.frame, edgeFrame)
        XCTAssertTrue(target.edges.contains(.left))
        XCTAssertTrue(target.edges.contains(.bottom))
    }

    private func target(
        for command: LayoutCommand,
        spacing: CGFloat = 0
    ) -> LayoutTarget
    {
        calculator.target(
            for: command,
            on: screen,
            currentWindowFrame: currentFrame,
            spacing: spacing
        )
    }
}
