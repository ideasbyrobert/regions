import Foundation

enum EdgeSnapZone: String, CaseIterable, Equatable, Sendable
{
    case fill
    case leftHalf
    case rightHalf
    case bottomHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter

    var preset: LayoutPreset
    {
        switch self
        {
        case .fill:
            return .fill
        case .leftHalf:
            return .leftHalf
        case .rightHalf:
            return .rightHalf
        case .bottomHalf:
            return .bottomHalf
        case .topLeftQuarter:
            return .topLeftQuarter
        case .topRightQuarter:
            return .topRightQuarter
        case .bottomLeftQuarter:
            return .bottomLeftQuarter
        case .bottomRightQuarter:
            return .bottomRightQuarter
        }
    }
}
