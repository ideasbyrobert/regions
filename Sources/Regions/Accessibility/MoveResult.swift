import CoreGraphics
import Foundation

enum MoveResult: Equatable, Sendable
{
    case moved(CGRect)
    case bestEffort(CGRect)
    case failed(MoveFailure)

    var failure: MoveFailure?
    {
        if case .failed(let failure) = self
        {
            return failure
        }
        return nil
    }
}
