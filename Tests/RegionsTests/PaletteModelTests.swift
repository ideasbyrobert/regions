import CoreGraphics
import XCTest
@testable import Regions

@MainActor
final class PaletteModelTests: XCTestCase
{
    func testReverseDragSelectsNormalizedRectangle()
    {
        let model = makeModel()
        let size = CGSize(width: 300, height: 300)

        model.beginDrag(at: CGPoint(x: 290, y: 290), in: size)
        model.updateDrag(at: CGPoint(x: 10, y: 10), in: size)

        XCTAssertEqual(model.selectedRegion?.minimumRow, 0)
        XCTAssertEqual(model.selectedRegion?.maximumRow, 2)
        XCTAssertEqual(model.selectedRegion?.minimumColumn, 0)
        XCTAssertEqual(model.selectedRegion?.maximumColumn, 2)
    }

    func testKeyboardMovementAndExtension()
    {
        let model = makeModel()

        model.moveSelection(rowDelta: 0, columnDelta: 1, extending: false)
        model.moveSelection(rowDelta: 1, columnDelta: 0, extending: true)

        XCTAssertEqual(model.selectedRegion?.minimumRow, 0)
        XCTAssertEqual(model.selectedRegion?.maximumRow, 1)
        XCTAssertEqual(model.selectedRegion?.minimumColumn, 1)
        XCTAssertEqual(model.selectedRegion?.maximumColumn, 1)
    }

    func testGridChangeResetsSelection()
    {
        let model = makeModel()
        model.moveSelection(rowDelta: 2, columnDelta: 2, extending: false)

        model.setDimension(.four)

        XCTAssertEqual(model.dimension, .four)
        XCTAssertEqual(model.selectedRegion?.minimumRow, 0)
        XCTAssertEqual(model.selectedRegion?.minimumColumn, 0)
    }

    func testFourByTwoPointerMappingUsesIndependentAxes()
    {
        let model = makeModel(dimension: .fourByTwo)
        let size = CGSize(width: 400, height: 200)

        model.beginDrag(at: CGPoint(x: 399, y: 199), in: size)

        XCTAssertEqual(model.selectedRegion?.minimumRow, 1)
        XCTAssertEqual(model.selectedRegion?.maximumRow, 1)
        XCTAssertEqual(model.selectedRegion?.minimumColumn, 3)
        XCTAssertEqual(model.selectedRegion?.maximumColumn, 3)
    }

    func testFourByTwoKeyboardMovementClampsToTwoRowsAndFourColumns()
    {
        let model = makeModel(dimension: .fourByTwo)

        model.moveSelection(rowDelta: 8, columnDelta: 8, extending: false)

        XCTAssertEqual(model.selectedRegion?.minimumRow, 1)
        XCTAssertEqual(model.selectedRegion?.minimumColumn, 3)
    }

    func testReleaseOutsideCancelsWithoutCommit()
    {
        var commitCount = 0
        var cancelCount = 0
        let model = PaletteModel(
            dimension: .three,
            onPreview:
            {
                _ in
            },
            onCommit:
            {
                _ in
                commitCount += 1
            },
            onCancel:
            {
                cancelCount += 1
            }
        )
        let size = CGSize(width: 300, height: 300)

        model.beginDrag(at: CGPoint(x: 10, y: 10), in: size)
        model.endDrag(at: CGPoint(x: 320, y: 320), in: size)

        XCTAssertEqual(commitCount, 0)
        XCTAssertEqual(cancelCount, 1)
        XCTAssertNil(model.selectedRegion)
    }

    func testAdjustmentCommitUsesConfiguredAmount()
    {
        var committedCommand: LayoutCommand?
        let model = PaletteModel(
            dimension: .three,
            adjustmentAmount: 64,
            onPreview:
            {
                _ in
            },
            onCommit:
            {
                command in
                committedCommand = command
            },
            onCancel:
            {
            }
        )

        model.commit(.moveRight)

        XCTAssertEqual(committedCommand, .adjustment(.moveRight, amount: 64))
    }

    private func makeModel(dimension: GridDimension = .three) -> PaletteModel
    {
        PaletteModel(
            dimension: dimension,
            onPreview:
            {
                _ in
            },
            onCommit:
            {
                _ in
            },
            onCancel:
            {
            }
        )
    }
}
