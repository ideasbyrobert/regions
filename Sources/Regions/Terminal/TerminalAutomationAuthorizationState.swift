import Foundation

enum TerminalAutomationAuthorizationState: Equatable, Sendable
{
    case notRequested
    case allowed
    case requiresConsent
    case denied
    case unavailable(Int32)

    var title: String
    {
        switch self
        {
        case .notRequested:
            return "Not requested"
        case .allowed:
            return "Allowed"
        case .requiresConsent:
            return "Required"
        case .denied:
            return "Denied"
        case .unavailable:
            return "Unavailable"
        }
    }

    var permitsAutomation: Bool
    {
        self == .allowed
    }
}
