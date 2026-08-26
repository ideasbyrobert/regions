import Combine
import Foundation

@MainActor
final class PaletteModel: ObservableObject
{
    @Published private(set) var placement: RegionPlacement

    let context: RegionContext

    private let recommendationEngine: RegionRecommendationEngine
    private let adjustmentAmount: Double
    private let onPreview: @MainActor (RegionPlacement?) -> Void
    private let onCommit: @MainActor (RegionPlacement) -> Void
    private let onCancel: @MainActor () -> Void

    init(
        context: RegionContext,
        recommendationEngine: RegionRecommendationEngine =
            RegionRecommendationEngine(),
        adjustmentAmount: Double = 32,
        onPreview: @escaping @MainActor (RegionPlacement?) -> Void,
        onCommit: @escaping @MainActor (RegionPlacement) -> Void,
        onCancel: @escaping @MainActor () -> Void
    )
    {
        self.context = context
        self.recommendationEngine = recommendationEngine
        self.adjustmentAmount = adjustmentAmount
        self.onPreview = onPreview
        self.onCommit = onCommit
        self.onCancel = onCancel
        placement = recommendationEngine.initialPlacement(for: context)
    }

    var positions: [RegionPosition]
    {
        recommendationEngine.positions(for: context)
    }

    var sizes: [RegionSize]
    {
        recommendationEngine.sizes(
            for: placement.position,
            context: context
        )
    }

    var isResizable: Bool
    {
        context.window.isResizable
    }

    func beginPreview()
    {
        onPreview(placement)
    }

    func select(_ position: RegionPosition)
    {
        guard positions.contains(position)
        else
        {
            return
        }
        let available = recommendationEngine.sizes(
            for: position,
            context: context
        )
        let size: RegionSize?
        if available.contains(placement.size ?? .half)
        {
            size = placement.size
        } else
        {
            size = available.min
            {
                abs($0.rawValue - (placement.size?.rawValue ?? 50))
                    < abs($1.rawValue - (placement.size?.rawValue ?? 50))
            }
        }
        placement = placement.replacing(position: position, size: size)
        onPreview(placement)
    }

    func select(_ size: RegionSize)
    {
        guard sizes.contains(size)
        else
        {
            return
        }
        placement = placement.replacing(size: size)
        onPreview(placement)
    }

    func nudge(horizontal: Double, vertical: Double)
    {
        placement = placement.offsetBy(
            horizontal: horizontal * adjustmentAmount,
            vertical: vertical * adjustmentAmount
        )
        onPreview(placement)
    }

    func resize(width: Double, height: Double)
    {
        guard isResizable
        else
        {
            return
        }
        placement = placement.resizedBy(
            width: width * adjustmentAmount,
            height: height * adjustmentAmount
        )
        onPreview(placement)
    }

    func grow()
    {
        resize(width: 1, height: 1)
    }

    func shrink()
    {
        resize(width: -1, height: -1)
    }

    func commit()
    {
        onCommit(placement)
    }

    func cancel()
    {
        onPreview(nil)
        onCancel()
    }
}
