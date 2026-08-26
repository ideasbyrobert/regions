import CoreGraphics
import XCTest

@testable import Regions

final class BalancedThreeByTwoLayoutTests: XCTestCase
{
    private let layout = BalancedThreeByTwoLayout()

    func testRowShapesForEverySupportedCount()
    {
        XCTAssertEqual(layout.rowCounts(forWindowCount: 1), [1])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 2), [2])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 3), [3])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 4), [2, 2])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 5), [3, 2])
        XCTAssertEqual(layout.rowCounts(forWindowCount: 6), [3, 3])
    }

    func testRejectsCountsOutsideCapacity()
    {
        XCTAssertNil(layout.rowCounts(forWindowCount: 0))
        XCTAssertNil(layout.rowCounts(forWindowCount: 7))
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

    func testFourWindowsUseCenteredRowsOfTwoAndTwo()
    {
        let result = layout.placements(
            for: Array(repeating: CGSize(width: 100, height: 100), count: 4),
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
        XCTAssertEqual(Array(frames.prefix(2)).map(\.minX), [395, 505])
        XCTAssertEqual(Array(frames.suffix(2)).map(\.minX), [395, 505])
        XCTAssertEqual(Array(frames.prefix(2)).map(\.minY), [305, 305])
        XCTAssertEqual(Array(frames.suffix(2)).map(\.minY), [195, 195])
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

    func testSixWindowsUseCenteredRowsOfThreeAndThree()
    {
        let result = layout.placements(
            for: Array(repeating: CGSize(width: 100, height: 100), count: 6),
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
        XCTAssertEqual(Array(frames.suffix(3)).map(\.minX), [340, 450, 560])
        XCTAssertEqual(Array(frames.prefix(3)).map(\.minY), [305, 305, 305])
        XCTAssertEqual(Array(frames.suffix(3)).map(\.minY), [195, 195, 195])
    }

    func testExactFitSucceedsAndOnePointTooSmallFails()
    {
        let sizes = Array(repeating: CGSize(width: 100, height: 50), count: 6)
        let exact = layout.placements(
            for: sizes,
            in: CGRect(x: 0, y: 0, width: 340, height: 130),
            spacing: 10,
            backingScaleFactor: 1
        )
        let tooSmall = layout.placements(
            for: sizes,
            in: CGRect(x: 0, y: 0, width: 339, height: 130),
            spacing: 10,
            backingScaleFactor: 1
        )

        guard case .placements(let exactFrames) = exact
        else
        {
            XCTFail("Expected exact-fit placements")
            return
        }
        XCTAssertEqual(exactFrames.count, 6)
        XCTAssertEqual(
            tooSmall,
            .doesNotFit(
                required: CGSize(width: 340, height: 130),
                available: CGSize(width: 339, height: 130)
            )
        )
    }
}
