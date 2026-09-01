import Foundation

extension WindowManaging
{
    func apply(
        target: LayoutTarget,
        to token: ManagedWindowToken,
        converter: ScreenCoordinateConverter,
        command: LayoutCommand?
    ) async -> MoveResult
    {
        await apply(
            target: target,
            to: token,
            converter: converter,
            command: command,
            historyPreviousFrame: nil
        )
    }
}
