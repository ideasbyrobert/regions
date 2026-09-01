import AppKit

final class PalettePanel: NSPanel
{
    var handlesKeyEvent: (@MainActor (NSEvent) -> Bool)?

    override var canBecomeKey: Bool
    {
        true
    }

    override var canBecomeMain: Bool
    {
        false
    }

    override func sendEvent(_ event: NSEvent)
    {
        if event.type == .keyDown && handlesKeyEvent?(event) == true
        {
            return
        }
        super.sendEvent(event)
    }
}
