import CoreGraphics
import Foundation

struct ManagedWindowSnapshot: Equatable, Sendable
{
    let token: ManagedWindowToken
    let processIdentifier: pid_t
    let frame: CGRect
}
