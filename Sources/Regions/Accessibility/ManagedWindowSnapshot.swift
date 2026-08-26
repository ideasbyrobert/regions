import CoreGraphics
import Foundation

struct ManagedWindowSnapshot: Equatable, Sendable
{
    let token: ManagedWindowToken
    let processIdentifier: pid_t
    let frame: CGRect
    let isResizable: Bool

    init(
        token: ManagedWindowToken,
        processIdentifier: pid_t,
        frame: CGRect,
        isResizable: Bool = true
    )
    {
        self.token = token
        self.processIdentifier = processIdentifier
        self.frame = frame
        self.isResizable = isResizable
    }
}
