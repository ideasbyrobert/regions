import CoreGraphics
import XCTest
@testable import Regions

final class ScreenCoordinateConverterTests: XCTestCase
{
    func testConversionIsItsOwnInverse()
    {
        let converter = ScreenCoordinateConverter(primaryDisplayMaximumY: 1080)
        let frames =
        [
            CGRect(x: 0, y: 0, width: 500, height: 400),
            CGRect(x: -1600, y: 200, width: 900, height: 700),
            CGRect(x: 2000, y: -800, width: 1200, height: 600),
            CGRect(x: 100, y: 1300, width: 400, height: 300)
        ]

        for frame in frames
        {
            let accessibilityFrame = converter.accessibilityFrame(fromAppKitFrame: frame)
            let result = converter.appKitFrame(fromAccessibilityFrame: accessibilityFrame)
            XCTAssertEqual(result, frame)
        }
    }

    func testConversionPreservesSizeAndHorizontalPosition()
    {
        let converter = ScreenCoordinateConverter(primaryDisplayMaximumY: 900)
        let frame = CGRect(x: -100, y: 40, width: 640, height: 480)
        let converted = converter.accessibilityFrame(fromAppKitFrame: frame)

        XCTAssertEqual(converted.origin.x, frame.origin.x)
        XCTAssertEqual(converted.size, frame.size)
        XCTAssertEqual(converted.origin.y, 380)
    }

    func testPointConversionFlipsOnlyVerticalPosition()
    {
        let converter = ScreenCoordinateConverter(primaryDisplayMaximumY: 900)

        XCTAssertEqual(
            converter.accessibilityPoint(fromAppKitPoint: CGPoint(x: -100, y: 40)),
            CGPoint(x: -100, y: 860)
        )
    }
}
