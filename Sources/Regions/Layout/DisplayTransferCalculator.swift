import CoreGraphics
import Foundation

struct DisplayTransferCalculator: Sendable
{
    func target(
        for currentFrame: CGRect,
        from source: ScreenSnapshot,
        to destination: ScreenSnapshot,
        spacing: CGFloat
    ) -> LayoutTarget
    {
        let sourceBounds = inset(source.visibleFrame, spacing: spacing)
        let destinationBounds = inset(destination.visibleFrame, spacing: spacing)
        let widthRatio = sourceBounds.width > 0 ? currentFrame.width / sourceBounds.width : 1
        let heightRatio = sourceBounds.height > 0 ? currentFrame.height / sourceBounds.height : 1
        let xRatio = sourceBounds.width > currentFrame.width
            ? (currentFrame.minX - sourceBounds.minX) / (sourceBounds.width - currentFrame.width)
            : 0.5
        let yRatio = sourceBounds.height > currentFrame.height
            ? (currentFrame.minY - sourceBounds.minY) / (sourceBounds.height - currentFrame.height)
            : 0.5
        let width = min(destinationBounds.width, destinationBounds.width * widthRatio)
        let height = min(destinationBounds.height, destinationBounds.height * heightRatio)
        let x = destinationBounds.minX + clamped(xRatio) * max(0, destinationBounds.width - width)
        let y = destinationBounds.minY + clamped(yRatio) * max(0, destinationBounds.height - height)
        let scale = max(destination.backingScaleFactor, 1)
        let frame = CGRect(
            x: align(x, scale: scale),
            y: align(y, scale: scale),
            width: align(width, scale: scale),
            height: align(height, scale: scale)
        )
        return LayoutTarget(
            frame: frame,
            visibleFrame: destination.visibleFrame,
            edges: [],
            backingScaleFactor: destination.backingScaleFactor
        )
    }

    private func inset(_ frame: CGRect, spacing: CGFloat) -> CGRect
    {
        let gap = min(min(max(spacing, 0), frame.width / 2), frame.height / 2)
        return frame.insetBy(dx: gap, dy: gap)
    }

    private func clamped(_ value: CGFloat) -> CGFloat
    {
        min(max(value, 0), 1)
    }

    private func align(_ value: CGFloat, scale: CGFloat) -> CGFloat
    {
        (value * scale).rounded() / scale
    }
}
