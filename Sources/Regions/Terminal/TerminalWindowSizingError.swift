import Foundation

enum TerminalWindowSizingError: Error, Equatable, Sendable
{
    case automation(TerminalAutomationAuthorizationState)
    case invalidState
    case malformedResponse
    case scriptFailure(code: Int, message: String)
    case windowSetChanged
    case verificationFailed

    var message: String
    {
        switch self
        {
        case .automation(.denied):
            return "Terminal Automation permission was denied. No windows were changed."
        case .automation(.requiresConsent), .automation(.notRequested):
            return "Terminal Automation permission is required for exact 80 × 48 sizing."
        case .automation(.unavailable(let code)):
            return "Terminal Automation is unavailable with status \(code)."
        case .automation(.allowed):
            return "Terminal Automation could not be completed."
        case .invalidState:
            return "Terminal returned invalid window dimensions."
        case .malformedResponse:
            return "Terminal returned an unreadable window response."
        case .scriptFailure(let code, let message):
            return "Terminal rejected the sizing request with error \(code): \(message)"
        case .windowSetChanged:
            return "The Terminal window set changed during arrangement."
        case .verificationFailed:
            return "Terminal did not apply the requested 80 × 48 dimensions."
        }
    }
}
