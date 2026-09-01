import CoreGraphics
import Foundation

struct WindowPlacementRequest: Equatable, Sendable
{
    let token: ManagedWindowToken
    let target: LayoutTarget
    let historyPreviousFrame: CGRect
    let command: LayoutCommand?
}
