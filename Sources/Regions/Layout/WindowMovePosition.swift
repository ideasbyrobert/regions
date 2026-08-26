import Foundation

enum WindowMovePosition: String, CaseIterable, Codable, Sendable
{
    case center
    case leftEdge
    case rightEdge
    case topEdge
    case bottomEdge
    case topLeftCorner
    case topRightCorner
    case bottomLeftCorner
    case bottomRightCorner

    var title: String
    {
        switch self
        {
        case .center:
            return "Move to Center"
        case .leftEdge:
            return "Move to Left Edge"
        case .rightEdge:
            return "Move to Right Edge"
        case .topEdge:
            return "Move to Top Edge"
        case .bottomEdge:
            return "Move to Bottom Edge"
        case .topLeftCorner:
            return "Move to Top Left"
        case .topRightCorner:
            return "Move to Top Right"
        case .bottomLeftCorner:
            return "Move to Bottom Left"
        case .bottomRightCorner:
            return "Move to Bottom Right"
        }
    }
}
