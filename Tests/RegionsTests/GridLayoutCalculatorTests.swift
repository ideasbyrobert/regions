import CoreGraphics
import XCTest

@testable import Regions

final class GridLayoutCalculatorTests: XCTestCase
{
    private let calculator = GridLayoutCalculator()
    private let screen = ScreenSnapshot(
        displayID: 1,
        frame: CGRect(x: 0, y: 0, width: 1220, height: 940),
        visibleFrame: CGRect(x: 10, y: 20, width: 1200, height: 900),
        backingScaleFactor: 2
    )

    func testEverySingleCellStaysWithinVisibleFrame()
    {
        for dimension in GridDimension.allCases
        {
            for row in 0..<dimension.rowCount
            {
                for column in 0..<dimension.columnCount
                {
                    let region = GridRegion(
                        dimension: dimension,
                        anchor: GridCell(row: row, column: column),
                        extent: GridCell(row: row, column: column)
                    )
                    let target = calculator.target(
                        for: .grid(region),
                        on: screen,
                        currentWindowFrame: .zero,
                        spacing: 8
                    )

                    XCTAssertTrue(screen.visibleFrame.contains(target.frame))
                    XCTAssertGreaterThan(target.frame.width, 0)
                    XCTAssertGreaterThan(target.frame.height, 0)
                }
            }
        }
    }

    func testFullGridTerminatesAtConfiguredOuterSpacing()
    {
        for dimension in GridDimension.allCases
        {
            let region = GridRegion(
                dimension: dimension,
                anchor: GridCell(row: 0, column: 0),
                extent: GridCell(
                    row: dimension.rowCount - 1,
                    column: dimension.columnCount - 1
                )
            )
            let target = calculator.target(
                for: .grid(region),
                on: screen,
                currentWindowFrame: .zero,
                spacing: 8
            )

            XCTAssertEqual(target.frame.minX, 18, accuracy: 0.001)
            XCTAssertEqual(target.frame.maxX, 1202, accuracy: 0.001)
            XCTAssertEqual(target.frame.minY, 28, accuracy: 0.001)
            XCTAssertEqual(target.frame.maxY, 912, accuracy: 0.001)
            XCTAssertEqual(target.edges, .all)
        }
    }

    func testAdjacentCellsRetainConfiguredGap()
    {
        let left = targetForCell(
            row: 1, column: 0, dimension: .three, spacing: 8)
        let right = targetForCell(
            row: 1, column: 1, dimension: .three, spacing: 8)
        let top = targetForCell(
            row: 0, column: 1, dimension: .three, spacing: 8)
        let bottom = targetForCell(
            row: 1, column: 1, dimension: .three, spacing: 8)

        XCTAssertEqual(right.frame.minX - left.frame.maxX, 8, accuracy: 0.5)
        XCTAssertEqual(top.frame.minY - bottom.frame.maxY, 8, accuracy: 0.5)
    }

    func testFourByTwoUsesFourColumnsAndTwoRows()
    {
        let topLeft = targetForCell(
            row: 0, column: 0, dimension: .fourByTwo, spacing: 0)
        let bottomRight = targetForCell(
            row: 1, column: 3, dimension: .fourByTwo, spacing: 0)

        XCTAssertEqual(
            topLeft.frame, CGRect(x: 10, y: 470, width: 300, height: 450))
        XCTAssertEqual(
            bottomRight.frame, CGRect(x: 910, y: 20, width: 300, height: 450))
        XCTAssertEqual(topLeft.edges, [.left, .top])
        XCTAssertEqual(bottomRight.edges, [.right, .bottom])
    }

    func testThreeByTwoUsesThreeColumnsAndTwoRows()
    {
        let topLeft = targetForCell(
            row: 0, column: 0, dimension: .threeByTwo, spacing: 0)
        let bottomRight = targetForCell(
            row: 1, column: 2, dimension: .threeByTwo, spacing: 0)

        XCTAssertEqual(
            topLeft.frame, CGRect(x: 10, y: 470, width: 400, height: 450))
        XCTAssertEqual(
            bottomRight.frame, CGRect(x: 810, y: 20, width: 400, height: 450))
        XCTAssertEqual(topLeft.edges, [.left, .top])
        XCTAssertEqual(bottomRight.edges, [.right, .bottom])
    }

    func testTwoByThreeUsesTwoColumnsAndThreeRows()
    {
        let topLeft = targetForCell(
            row: 0, column: 0, dimension: .twoByThree, spacing: 0)
        let bottomRight = targetForCell(
            row: 2, column: 1, dimension: .twoByThree, spacing: 0)

        XCTAssertEqual(
            topLeft.frame, CGRect(x: 10, y: 620, width: 600, height: 300))
        XCTAssertEqual(
            bottomRight.frame, CGRect(x: 610, y: 20, width: 600, height: 300))
        XCTAssertEqual(topLeft.edges, [.left, .top])
        XCTAssertEqual(bottomRight.edges, [.right, .bottom])
    }

    func testProMasterStackSplits()
    {
        let leftSixty = calculator.target(
            for: .preset(.leftSixtyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )
        let rightForty = calculator.target(
            for: .preset(.rightFortyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )
        let leftSeventy = calculator.target(
            for: .preset(.leftSeventyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )
        let rightThirty = calculator.target(
            for: .preset(.rightThirtyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )
        let topSeventy = calculator.target(
            for: .preset(.topSeventyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )
        let bottomThirty = calculator.target(
            for: .preset(.bottomThirtyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )

        XCTAssertEqual(
            leftSixty.frame, CGRect(x: 10, y: 20, width: 720, height: 900))
        XCTAssertEqual(
            rightForty.frame, CGRect(x: 730, y: 20, width: 480, height: 900))
        XCTAssertEqual(
            leftSeventy.frame, CGRect(x: 10, y: 20, width: 840, height: 900))
        XCTAssertEqual(
            rightThirty.frame, CGRect(x: 850, y: 20, width: 360, height: 900))
        XCTAssertEqual(
            topSeventy.frame, CGRect(x: 10, y: 290, width: 1200, height: 630))
        XCTAssertEqual(
            bottomThirty.frame, CGRect(x: 10, y: 20, width: 1200, height: 270))
    }

    func testProCenterFocusTriptych()
    {
        let centerFifty = calculator.target(
            for: .preset(.centerFocusFiftyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )
        let centerSixty = calculator.target(
            for: .preset(.centerFocusSixtyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )

        XCTAssertEqual(
            centerFifty.frame, CGRect(x: 310, y: 20, width: 600, height: 900))
        XCTAssertEqual(
            centerSixty.frame, CGRect(x: 250, y: 20, width: 720, height: 900))
    }

    func testProCenteredSizes()
    {
        let centeredSixty = calculator.target(
            for: .preset(.centeredSixtyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )
        let centeredEighty = calculator.target(
            for: .preset(.centeredEightyPercent),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )

        XCTAssertEqual(
            centeredSixty.frame, CGRect(x: 250, y: 200, width: 720, height: 540)
        )
        XCTAssertEqual(
            centeredEighty.frame,
            CGRect(x: 130, y: 110, width: 960, height: 720))
    }

    func testMultiCellSpanConsumesInternalGaps()
    {
        let region = GridRegion(
            dimension: .three,
            anchor: GridCell(row: 0, column: 0),
            extent: GridCell(row: 0, column: 1)
        )
        let span = calculator.target(
            for: .grid(region),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 8
        )
        let first = targetForCell(
            row: 0, column: 0, dimension: .three, spacing: 8)
        let second = targetForCell(
            row: 0, column: 1, dimension: .three, spacing: 8)

        XCTAssertEqual(span.frame.minX, first.frame.minX, accuracy: 0.001)
        XCTAssertEqual(span.frame.maxX, second.frame.maxX, accuracy: 0.001)
    }

    func testZeroSpacingUsesEntireVisibleFrame()
    {
        let region = GridRegion(
            dimension: .four,
            anchor: GridCell(row: 0, column: 0),
            extent: GridCell(row: 3, column: 3)
        )
        let target = calculator.target(
            for: .grid(region),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )

        XCTAssertEqual(target.frame, screen.visibleFrame)
    }

    func testOversizedSpacingStillProducesPositiveCells()
    {
        let tinyScreen = ScreenSnapshot(
            displayID: 2,
            frame: CGRect(x: 0, y: 0, width: 8, height: 8),
            visibleFrame: CGRect(x: 0, y: 0, width: 8, height: 8),
            backingScaleFactor: 2
        )
        let region = GridRegion(
            dimension: .four,
            anchor: GridCell(row: 3, column: 3),
            extent: GridCell(row: 3, column: 3)
        )
        let target = calculator.target(
            for: .grid(region),
            on: tinyScreen,
            currentWindowFrame: .zero,
            spacing: 32
        )

        XCTAssertGreaterThanOrEqual(target.frame.width, 0.5)
        XCTAssertGreaterThanOrEqual(target.frame.height, 0.5)
        XCTAssertTrue(tinyScreen.visibleFrame.contains(target.frame))
    }

    func testCenterPreservesWindowSizeAndCentersIt()
    {
        let currentFrame = CGRect(x: 100, y: 100, width: 600, height: 400)
        let target = calculator.target(
            for: .preset(.center),
            on: screen,
            currentWindowFrame: currentFrame,
            spacing: 8
        )

        XCTAssertEqual(target.frame.size, currentFrame.size)
        XCTAssertEqual(
            target.frame.midX, screen.visibleFrame.midX, accuracy: 0.001)
        XCTAssertEqual(
            target.frame.midY, screen.visibleFrame.midY, accuracy: 0.001)
        XCTAssertTrue(target.edges.isEmpty)
    }

    func testCommonPresetsMapToExpectedRegions()
    {
        let left = calculator.target(
            for: .preset(.leftHalf),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )
        let bottomRight = calculator.target(
            for: .preset(.bottomRightQuarter),
            on: screen,
            currentWindowFrame: .zero,
            spacing: 0
        )

        XCTAssertEqual(
            left.frame, CGRect(x: 10, y: 20, width: 600, height: 900))
        XCTAssertEqual(
            bottomRight.frame, CGRect(x: 610, y: 20, width: 600, height: 450))
        XCTAssertEqual(left.edges, [.left, .top, .bottom])
        XCTAssertEqual(bottomRight.edges, [.right, .bottom])
    }

    private func targetForCell(
        row: Int,
        column: Int,
        dimension: GridDimension,
        spacing: CGFloat
    ) -> LayoutTarget
    {
        let region = GridRegion(
            dimension: dimension,
            anchor: GridCell(row: row, column: column),
            extent: GridCell(row: row, column: column)
        )
        return calculator.target(
            for: .grid(region),
            on: screen,
            currentWindowFrame: .zero,
            spacing: spacing
        )
    }
}
