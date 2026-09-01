import Foundation

struct WindowArrangementTransaction: Equatable, Sendable
{
    let identifier: UUID
    let changes: [WindowFrameChange]
    let terminalState: TerminalArrangementState?
}
