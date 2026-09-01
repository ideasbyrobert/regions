import Foundation

enum WindowCaptureResult: Equatable, Sendable
{
    case captured(ManagedWindowSnapshot)
    case failed(MoveFailure)
}
