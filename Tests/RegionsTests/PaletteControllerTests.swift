import CoreGraphics
import XCTest

@testable import Regions

@MainActor
final class PaletteControllerTests: XCTestCase
{
    func testPanelCentersAndClampsOnOffsetDisplay()
    {
        let visible = CGRect(x: 100, y: 50, width: 800, height: 500)
        let frame = PaletteController.clampedFrame(
            contentSize: CGSize(width: 340, height: 356),
            visibleFrame: visible
        )

        XCTAssertEqual(frame.origin.x, 330)
        XCTAssertEqual(frame.origin.y, 122)
        XCTAssertTrue(visible.insetBy(dx: 16, dy: 16).contains(frame))
    }

    func testPanelShrinksToTinyVisibleFrame()
    {
        let visible = CGRect(x: 0, y: 0, width: 300, height: 300)
        let frame = PaletteController.clampedFrame(
            contentSize: CGSize(width: 340, height: 356),
            visibleFrame: visible
        )

        XCTAssertEqual(frame, CGRect(x: 16, y: 16, width: 268, height: 268))
    }
}
