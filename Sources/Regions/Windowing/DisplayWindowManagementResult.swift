import Foundation

enum DisplayWindowManagementResult: Equatable, Sendable
{
    case moved(windowCount: Int, usedBestEffort: Bool)
    case alreadyOnDisplay
    case failed(MoveFailure)
}
