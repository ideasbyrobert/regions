import AppKit

@MainActor
enum PaletteSnapshotWriter
{
    static func write(_ window: NSWindow, to path: String)
    {
        guard let view = window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else
        {
            return
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:])
        else
        {
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
