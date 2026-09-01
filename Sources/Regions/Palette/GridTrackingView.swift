import AppKit
import OSLog

@MainActor
final class GridTrackingView: NSView
{
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.ideasbyrobert.Regions",
        category: "PaletteInteraction"
    )
    var begin: (@MainActor (CGPoint, CGSize) -> Void)?
    var update: (@MainActor (CGPoint, CGSize) -> Void)?
    var end: (@MainActor (CGPoint, CGSize) -> Void)?

    override var isFlipped: Bool
    {
        true
    }

    override func mouseDown(with event: NSEvent)
    {
        logger.info("Grid pointer interaction began")
        begin?(location(for: event), bounds.size)
    }

    override func mouseDragged(with event: NSEvent)
    {
        update?(location(for: event), bounds.size)
    }

    override func mouseUp(with event: NSEvent)
    {
        logger.info("Grid pointer interaction ended")
        end?(location(for: event), bounds.size)
    }

    private func location(for event: NSEvent) -> CGPoint
    {
        convert(event.locationInWindow, from: nil)
    }
}
