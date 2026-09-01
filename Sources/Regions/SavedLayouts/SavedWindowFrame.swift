import CoreGraphics
import Foundation

struct SavedWindowFrame: Codable, Equatable, Sendable
{
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(frame: CGRect, within visibleFrame: CGRect)
    {
        let normalizedWidth = min(max(frame.width / visibleFrame.width, 0.05), 1)
        let normalizedHeight = min(max(frame.height / visibleFrame.height, 0.05), 1)
        let normalizedX = (frame.minX - visibleFrame.minX) / visibleFrame.width
        let normalizedY = (frame.minY - visibleFrame.minY) / visibleFrame.height
        x = min(max(normalizedX, 0), 1 - normalizedWidth)
        y = min(max(normalizedY, 0), 1 - normalizedHeight)
        width = normalizedWidth
        height = normalizedHeight
    }

    func target(on screen: ScreenSnapshot) -> LayoutTarget
    {
        let visibleFrame = screen.visibleFrame
        let frame = CGRect(
            x: visibleFrame.minX + visibleFrame.width * x,
            y: visibleFrame.minY + visibleFrame.height * y,
            width: visibleFrame.width * width,
            height: visibleFrame.height * height
        )
        var edges: LayoutEdges = []
        if x <= 0.001
        {
            edges.insert(.left)
        }
        if x + width >= 0.999
        {
            edges.insert(.right)
        }
        if y <= 0.001
        {
            edges.insert(.bottom)
        }
        if y + height >= 0.999
        {
            edges.insert(.top)
        }
        return LayoutTarget(
            frame: frame,
            visibleFrame: visibleFrame,
            edges: edges,
            backingScaleFactor: screen.backingScaleFactor
        )
    }
}
