import SwiftUI

/// A menu command names itself.
///
/// Every command enum in the menu bar already answered to `title`, so the
/// eight hand written `ForEach` blocks in `MenuBarContent` differed only in
/// which enum they walked and which controller method they called. Naming that
/// shape once means a new command family arrives as one line rather than as a
/// seventh copy of the same seven lines, and a change to how a row is built
/// happens in one place instead of eight.
protocol MenuCommand: Hashable
{
    var title: String { get }
}

extension LayoutPreset: MenuCommand {}
extension WindowMovePosition: MenuCommand {}
extension WindowAdjustment: MenuCommand {}
extension WindowFocusDirection: MenuCommand {}
extension WindowLifecycleAction: MenuCommand {}

/// Renders one button per command, in the order given.
struct CommandButtons<Command: MenuCommand>: View
{
    private let commands: [Command]
    private let perform: (Command) -> Void

    init(_ commands: [Command], perform: @escaping (Command) -> Void)
    {
        self.commands = commands
        self.perform = perform
    }

    var body: some View
    {
        ForEach(commands, id: \.self)
        {
            command in
            Button(command.title)
            {
                perform(command)
            }
        }
    }
}
