import Foundation

struct PaletteSession: Sendable
{
    let context: RegionContext

    var window: ManagedWindowSnapshot
    {
        context.window
    }

    var screen: ScreenSnapshot
    {
        context.screen
    }
}
