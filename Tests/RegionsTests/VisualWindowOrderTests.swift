import CoreGraphics
import XCTest

@testable import Regions

final class VisualWindowOrderTests: XCTestCase
{
    func testOrdersTopToBottomThenLeftToRight()
    {
        let topRight = makeWindow(x: 500, y: 400)
        let bottomLeft = makeWindow(x: 100, y: 100)
        let topLeft = makeWindow(x: 100, y: 400)
        let ordered = VisualWindowOrder().ordered(
            [topRight, bottomLeft, topLeft]
        )

        XCTAssertEqual(
            ordered.map(\.token),
            [topLeft.token, topRight.token, bottomLeft.token]
        )
    }

    func testCaptureOrderBreaksExactFrameTies()
    {
        let first = makeWindow(x: 100, y: 100)
        let second = makeWindow(x: 100, y: 100)
        let ordered = VisualWindowOrder().ordered([first, second])

        XCTAssertEqual(ordered.map(\.token), [first.token, second.token])
    }

    private func makeWindow(x: CGFloat, y: CGFloat) -> ManagedWindowSnapshot
    {
        ManagedWindowSnapshot(
            token: ManagedWindowToken(id: UUID()),
            processIdentifier: 42,
            frame: CGRect(x: x, y: y, width: 200, height: 100)
        )
    }
}
