import Foundation

enum BatchArrangementAvailability: Equatable, Sendable
{
    case checking
    case available(windowCount: Int)
    case unavailableNoWindows
    case unavailableTooMany(windowCount: Int)
    case unavailable(MoveFailure)

    var isAvailable: Bool
    {
        if case .available = self
        {
            return true
        }
        return false
    }

    var detailText: String
    {
        switch self
        {
        case .checking:
            return "Checking windows…"
        case .available(let windowCount):
            return "\(windowCount) of 8 positions"
        case .unavailableNoWindows:
            return "Unavailable: no windows"
        case .unavailableTooMany(let windowCount):
            return "Unavailable: \(windowCount) windows"
        case .unavailable(let failure):
            return detailText(for: failure)
        }
    }

    private func detailText(for failure: MoveFailure) -> String
    {
        switch failure
        {
        case .accessibilityPermissionRequired:
            return "Window Control required"
        case .minimizedWindow:
            return "Restore minimized windows"
        case .fullScreenWindow:
            return "Exit full screen"
        case .noTargetApplication, .noFocusedWindow, .noManageableWindows:
            return "Unavailable: no windows"
        default:
            return "Unavailable"
        }
    }
}
