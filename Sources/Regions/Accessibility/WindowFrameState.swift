import CoreGraphics
import Foundation

struct WindowFrameState: Equatable, Sendable
{
    let token: ManagedWindowToken
    let frame: CGRect
}
