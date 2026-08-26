import Foundation

enum WindowLifecycleAction: String, Sendable
{
    case minimize
    case zoom
    case toggleFullScreen
    case close
    case bringToFront

    static let menuCases: [WindowLifecycleAction] = [
        .minimize,
        .zoom,
        .toggleFullScreen,
        .close,
    ]

    var title: String
    {
        switch self
        {
        case .minimize:
            return "Minimize"
        case .zoom:
            return "Zoom or Restore"
        case .toggleFullScreen:
            return "Toggle Full Screen"
        case .close:
            return "Close Window"
        case .bringToFront:
            return "Bring to Front"
        }
    }
}
