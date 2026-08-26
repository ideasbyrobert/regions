import CoreGraphics
import Foundation

struct EdgeSnapResolver: Sendable
{
    func zone(
        at location: CGPoint,
        on screen: ScreenSnapshot,
        threshold: CGFloat
    ) -> EdgeSnapZone?
    {
        let frame = screen.frame
        let resolvedThreshold = min(max(threshold, 1), 96)
        let cornerSpan = min(max(frame.width * 0.16, 96), 200)
        let nearLeft = location.x <= frame.minX + resolvedThreshold
        let nearRight = location.x >= frame.maxX - resolvedThreshold
        let nearTop = location.y >= frame.maxY - resolvedThreshold
        let nearBottom = location.y <= frame.minY + resolvedThreshold
        let inLeftCornerBand = location.x <= frame.minX + cornerSpan
        let inRightCornerBand = location.x >= frame.maxX - cornerSpan

        if nearTop && inLeftCornerBand
        {
            return .topLeftQuarter
        }
        if nearTop && inRightCornerBand
        {
            return .topRightQuarter
        }
        if nearBottom && inLeftCornerBand
        {
            return .bottomLeftQuarter
        }
        if nearBottom && inRightCornerBand
        {
            return .bottomRightQuarter
        }
        if nearTop
        {
            return .fill
        }
        if nearBottom
        {
            return .bottomHalf
        }
        if nearLeft
        {
            return .leftHalf
        }
        if nearRight
        {
            return .rightHalf
        }
        return nil
    }
}
