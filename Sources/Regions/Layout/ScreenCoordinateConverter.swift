import CoreGraphics
import Foundation

struct ScreenCoordinateConverter: Sendable
{
    let primaryDisplayMaximumY: CGFloat

    func accessibilityFrame(fromAppKitFrame frame: CGRect) -> CGRect
    {
        CGRect(
            x: frame.minX,
            y: primaryDisplayMaximumY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    func appKitFrame(fromAccessibilityFrame frame: CGRect) -> CGRect
    {
        CGRect(
            x: frame.minX,
            y: primaryDisplayMaximumY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    func accessibilityPoint(fromAppKitPoint point: CGPoint) -> CGPoint
    {
        CGPoint(
            x: point.x,
            y: primaryDisplayMaximumY - point.y
        )
    }
}
