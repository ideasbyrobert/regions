import AppKit
import SwiftUI

@MainActor
final class FootprintPanelController
{
    private var panel: NSPanel?

    func show(frame: CGRect)
    {
        let panel = panel ?? makePanel()
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide()
    {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel
    {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentViewController = NSHostingController(rootView: FootprintView())
        return panel
    }
}
