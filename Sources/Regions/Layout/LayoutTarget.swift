import CoreGraphics
import Foundation

struct LayoutTarget: Equatable, Sendable
{
    let frame: CGRect
    let visibleFrame: CGRect
    let edges: LayoutEdges
    let backingScaleFactor: CGFloat
}
