import CoreGraphics
import Foundation

enum WindowArrangementFailure: Error, Equatable, Sendable
{
    case noWindows
    case tooManyWindows(Int)
    case move(MoveFailure)
    case terminal(TerminalWindowSizingError)
    case terminalWindowCountMismatch(accessibility: Int, automation: Int)
    case doesNotFit(required: CGSize, available: CGSize)
    case rollbackFailed(String)

    var message: String
    {
        switch self
        {
        case .noWindows:
            return "The target application has no manageable standard windows."
        case .tooManyWindows(let count):
            return "Arrangement is unavailable for \(count) windows. Maximum: 8."
        case .move(let failure):
            return failure.message
        case .terminal(let failure):
            return failure.message
        case .terminalWindowCountMismatch(let accessibility, let automation):
            return "Terminal exposed \(accessibility) manageable windows and \(automation) automation windows. No windows were changed."
        case .doesNotFit(let required, let available):
            return "Exact 80 × 48 windows require \(Int(ceil(required.width))) × \(Int(ceil(required.height))) pt; this display provides \(Int(floor(available.width))) × \(Int(floor(available.height))) pt. No windows were changed."
        case .rollbackFailed(let detail):
            return "The arrangement failed and could not be completely restored: \(detail)"
        }
    }
}
