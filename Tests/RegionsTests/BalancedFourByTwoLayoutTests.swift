import CoreGraphics
import XCTest

@testable import Regions

final class BalancedFourByTwoLayoutTests: XCTestCase
{
    private let layout = BalancedFourByTwoLayout()

    func testRowShapesForEverySupportedCount()
    {
        XCTAssertEqual(layout.rowCounts(forWindowCount: 1), [1])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 2), [2])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 3), [3])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 4), [4])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 5), [3, 2])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 6), [3, 3])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 7), [4, 3])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 8), [4, 4])
    }

    func testRejectsCountsOutsideCapacity()
    {
        XCTAssertNil(layout.rowCounts(forWindowCount: 0))
        XCTAssertNil(layout.rowCounts(forWindowCount: 9))
    }

    func testThreeWindowsUseOneCenteredRow()
    {
        let result = layout.placements(
            for: Array(repeating: CGSize(width: 100, height: 100), count: 3),
            in: CGRect(x: 0, y: 0, width: 1_000, height: 600),
            spacing: 10,
            backingScaleFactor: 2
        )

        guard case .placements(let frames) = result
        else
        {
            XCTFail("Expected placements")
            return
        }
        XCTAssertEqual(frames.map(\.minX), [340, 450, 560])
        XCTAssertEqual(frames.map(\.minY), [250, 250, 250])
    }

    func testFiveWindowsUseCenteredRowsOfThreeAndTwo()
    {
        let result = layout.placements(
            for: Array(repeating: CGSize(width: 100, height: 100), count: 5),
            in: CGRect(x: 0, y: 0, width: 1_000, height: 600),
            spacing: 10,
            backingScaleFactor: 2
        )

        guard case .placements(let frames) = result
        else
        {
            XCTFail("Expected placements")
            return
        }
        XCTAssertEqual(Array(frames.prefix(3)).map(\.minX), [340, 450, 560])
        XCTAssertEqual(Array(frames.suffix(2)).map(\.minX), [395, 505])
        XCTAssertEqual(Array(frames.prefix(3)).map(\.minY), [305, 305, 305])
        XCTAssertEqual(Array(frames.suffix(2)).map(\.minY), [195, 195])
    }

    func testUnequalWindowHeightsAreCenteredWithinTheirRow()
    {
        let result = layout.placements(
            for: [
                CGSize(width: 100, height: 80),
                CGSize(width: 100, height: 120),
            ],
            in: CGRect(x: 0, y: 0, width: 600, height: 600),
            spacing: 10,
            backingScaleFactor: 2
        )

        guard case .placements(let frames) = result
        else
        {
            XCTFail("Expected placements")
            return
        }
        XCTAssertEqual(frames[0].midY, frames[1].midY)
        XCTAssertEqual(frames[0].height, 80)
        XCTAssertEqual(frames[1].height, 120)
    }

    func testExactFitSucceedsAndOnePointTooSmallFails()
    {
        let sizes = Array(repeating: CGSize(width: 100, height: 50), count: 8)
        let exact = layout.placements(
            for: sizes,
            in: CGRect(x: 0, y: 0, width: 450, height: 130),
            spacing: 10,
            backingScaleFactor: 1
        )
        let tooSmall = layout.placements(
            for: sizes,
            in: CGRect(x: 0, y: 0, width: 449, height: 130),
            spacing: 10,
            backingScaleFactor: 1
        )

        guard case .placements(let exactFrames) = exact
        else
        {
            XCTFail("Expected exact-fit placements")
            return
        }
        XCTAssertEqual(exactFrames.count, 8)
        XCTAssertEqual(
            tooSmall,
            .doesNotFit(
                required: CGSize(width: 450, height: 130),
                available: CGSize(width: 449, height: 130)
            )
        )
    }
}
