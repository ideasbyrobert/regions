import CoreGraphics
import Foundation

struct WindowFrameChange: Equatable, Sendable
{
    let token: ManagedWindowToken
    let previousFrame: CGRect
    let managedFrame: CGRect
}
