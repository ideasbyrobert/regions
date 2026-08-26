import Foundation

enum HotKeyRegistrationResult: Equatable, Sendable
{
    case registered
    case conflict
    case failed(Int32)
}
