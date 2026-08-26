import Foundation

struct TerminalArrangementState: Equatable, Sendable
{
    let previous: [TerminalWindowState]
    let managed: [TerminalWindowState]
}
