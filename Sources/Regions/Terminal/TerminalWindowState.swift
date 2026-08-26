import Foundation

struct TerminalWindowState: Equatable, Sendable
{
    let windowIdentifier: Int32
    let columns: Int
    let rows: Int
}
