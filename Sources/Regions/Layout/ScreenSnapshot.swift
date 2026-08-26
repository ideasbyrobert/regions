import CoreGraphics
import Foundation

struct ScreenSnapshot: Equatable, Sendable
{
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let visibleFrame: CGRect
    let backingScaleFactor: CGFloat
}
