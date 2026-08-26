import CoreGraphics
import XCTest

@testable import Regions

final class EdgeSnapResolverTests: XCTestCase
{
    private let resolver = EdgeSnapResolver()
    private let screen = ScreenSnapshot(
        displayID: 1,
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 836),
        backingScaleFactor: 2
    )

    func testTopCenterResolvesToFill()
    {
        XCTAssertEqual(
            resolver.zone(
                at: CGPoint(x: 720, y: 899), on: screen, threshold: 24),
            .fill
        )
    }

    func testCornersResolveBeforeStraightEdges()
    {
        XCTAssertEqual(
            resolver.zone(at: CGPoint(x: 1, y: 899), on: screen, threshold: 24),
            .topLeftQuarter
        )
        XCTAssertEqual(
            resolver.zone(
                at: CGPoint(x: 1439, y: 1), on: screen, threshold: 24),
            .bottomRightQuarter
        )
    }

    func testStraightSideEdgesResolveToHalves()
    {
        XCTAssertEqual(
            resolver.zone(at: CGPoint(x: 1, y: 450), on: screen, threshold: 24),
            .leftHalf
        )
        XCTAssertEqual(
            resolver.zone(
                at: CGPoint(x: 1439, y: 450), on: screen, threshold: 24),
            .rightHalf
        )
    }

    func testBottomCenterResolvesToBottomHalf()
    {
        XCTAssertEqual(
            resolver.zone(at: CGPoint(x: 720, y: 1), on: screen, threshold: 24),
            .bottomHalf
        )
    }

    func testInteriorReturnsNoZone()
    {
        XCTAssertNil(
            resolver.zone(
                at: CGPoint(x: 720, y: 450), on: screen, threshold: 24)
        )
    }
}
