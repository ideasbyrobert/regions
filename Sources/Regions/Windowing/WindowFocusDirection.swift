import Foundation

enum WindowFocusDirection: String, CaseIterable, Sendable
{
    case previous
    case next

    var title: String
    {
        switch self
        {
        case .previous:
            return "Previous App Window"
        case .next:
            return "Next App Window"
        }
    }
}
