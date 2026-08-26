import Foundation

enum WindowOperationResult: Equatable, Sendable
{
    case completed
    case failed(MoveFailure)
}
