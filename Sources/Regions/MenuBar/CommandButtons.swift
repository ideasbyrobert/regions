import SwiftUI

protocol MenuCommand: Hashable
{
    var title: String { get }
}

extension LayoutPreset: MenuCommand {}
extension WindowMovePosition: MenuCommand {}
extension WindowAdjustment: MenuCommand {}
extension WindowFocusDirection: MenuCommand {}
extension WindowLifecycleAction: MenuCommand {}

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
