import CoreGraphics
import Foundation

enum BalancedThreeByTwoLayoutResult: Equatable, Sendable
{
    case placements([CGRect])
    case unsupportedWindowCount(Int)
    case doesNotFit(required: CGSize, available: CGSize)
}
