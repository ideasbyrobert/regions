import Foundation

enum WindowAdjustment: String, CaseIterable, Codable, Sendable
{
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case grow
    case shrink
    case widen
    case narrow
    case taller
    case shorter

    static let moveCases: [WindowAdjustment] = [
        .moveLeft,
        .moveRight,
        .moveUp,
        .moveDown
    ]

    static let resizeCases: [WindowAdjustment] = [
        .grow,
        .shrink,
        .widen,
        .narrow,
        .taller,
        .shorter
    ]

    var title: String
    {
        switch self
        {
        case .moveLeft:
            return "Nudge Left"
        case .moveRight:
            return "Nudge Right"
        case .moveUp:
            return "Nudge Up"
        case .moveDown:
            return "Nudge Down"
        case .grow:
            return "Grow"
        case .shrink:
            return "Shrink"
        case .widen:
            return "Widen"
        case .narrow:
            return "Narrow"
        case .taller:
            return "Make Taller"
        case .shorter:
            return "Make Shorter"
        }
    }
}
