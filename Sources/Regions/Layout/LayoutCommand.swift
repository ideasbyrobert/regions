import Foundation

enum LayoutCommand: Hashable, Codable, Sendable
{
    case region(RegionPlacement)
    case grid(GridRegion)
    case preset(LayoutPreset)
    case move(WindowMovePosition)
    case adjustment(WindowAdjustment, amount: Double)

    var title: String
    {
        switch self
        {
        case .region(let placement):
            placement.title
        case .grid(let region):
            region.accessibilityLabel
        case .preset(let preset):
            preset.title
        case .move(let position):
            position.title
        case .adjustment(let adjustment, _):
            adjustment.title
        }
    }
}
