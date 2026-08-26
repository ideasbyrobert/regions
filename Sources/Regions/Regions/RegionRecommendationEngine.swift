import CoreGraphics
import Foundation

struct RegionRecommendationEngine
{
    func positions(for context: RegionContext) -> [RegionPosition]
    {
        context.window.isResizable
            ? RegionPosition.allCases
            : [.leading, .center, .trailing]
    }

    func sizes(
        for position: RegionPosition,
        context: RegionContext
    ) -> [RegionSize]
    {
        guard context.window.isResizable,
            position != .fill
        else
        {
            return []
        }
        switch position
        {
        case .leading, .trailing:
            return [.quarter, .half, .seventy]
        case .center:
            return [.half, .seventy, .ninety]
        case .fill:
            return []
        }
    }

    func initialPlacement(for context: RegionContext) -> RegionPlacement
    {
        let orientation = context.orientation
        let visibleFrame = context.screen.visibleFrame
        let windowFrame = context.window.frame
        let axisFraction: Double
        let axisPosition: Double
        if orientation == .landscape
        {
            axisFraction = windowFrame.width / visibleFrame.width
            axisPosition =
                (windowFrame.midX - visibleFrame.minX) / visibleFrame.width
        } else
        {
            axisFraction = windowFrame.height / visibleFrame.height
            axisPosition =
                (visibleFrame.maxY - windowFrame.midY) / visibleFrame.height
        }
        let position: RegionPosition
        if context.window.isResizable && axisFraction >= 0.9
        {
            position = .fill
        } else if axisPosition < 0.4
        {
            position = .leading
        } else if axisPosition > 0.6
        {
            position = .trailing
        } else
        {
            position = .center
        }
        let availableSizes = sizes(for: position, context: context)
        let size = availableSizes.min
        {
            abs($0.fraction - axisFraction)
                < abs($1.fraction - axisFraction)
        }
        return RegionPlacement(
            orientation: orientation,
            position: position,
            size: size
        )
    }
}
