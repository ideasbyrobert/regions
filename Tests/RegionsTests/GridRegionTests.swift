import XCTest

@testable import Regions

final class GridRegionTests: XCTestCase
{
    func testReverseSelectionNormalizesBounds()
    {
        let region = GridRegion(
            dimension: .four,
            anchor: GridCell(row: 3, column: 2),
            extent: GridCell(row: 1, column: 0)
        )

        XCTAssertEqual(region.minimumRow, 1)
        XCTAssertEqual(region.maximumRow, 3)
        XCTAssertEqual(region.minimumColumn, 0)
        XCTAssertEqual(region.maximumColumn, 2)
    }

    func testSelectionClampsCellsToGrid()
    {
        let region = GridRegion(
            dimension: .three,
            anchor: GridCell(row: -2, column: 8),
            extent: GridCell(row: 4, column: -3)
        )

        XCTAssertEqual(region.minimumRow, 0)
        XCTAssertEqual(region.maximumRow, 2)
        XCTAssertEqual(region.minimumColumn, 0)
        XCTAssertEqual(region.maximumColumn, 2)
    }

    func testContainsOnlySelectedCells()
    {
        let region = GridRegion(
            dimension: .four,
            anchor: GridCell(row: 1, column: 1),
            extent: GridCell(row: 2, column: 3)
        )

        XCTAssertTrue(region.contains(GridCell(row: 1, column: 1)))
        XCTAssertTrue(region.contains(GridCell(row: 2, column: 3)))
        XCTAssertFalse(region.contains(GridCell(row: 0, column: 1)))
        XCTAssertFalse(region.contains(GridCell(row: 2, column: 0)))
    }

    func testFourByTwoClampsRowsAndColumnsIndependently()
    {
        let region = GridRegion(
            dimension: .fourByTwo,
            anchor: GridCell(row: -1, column: 9),
            extent: GridCell(row: 8, column: -2)
        )

        XCTAssertEqual(region.minimumRow, 0)
        XCTAssertEqual(region.maximumRow, 1)
        XCTAssertEqual(region.minimumColumn, 0)
        XCTAssertEqual(region.maximumColumn, 3)
    }

    func testAccessibilityLabelDescribesSpan()
    {
        let region = GridRegion(
            dimension: .three,
            anchor: GridCell(row: 0, column: 1),
            extent: GridCell(row: 2, column: 2)
        )

        XCTAssertEqual(
            region.accessibilityLabel,
            "3 × 3, rows 1 through 3, columns 2 through 3"
        )
    }
}
