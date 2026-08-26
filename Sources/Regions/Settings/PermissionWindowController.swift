import AppKit
import SwiftUI

@MainActor
final class PermissionWindowController: NSWindowController
{
    init(authorization: AccessibilityAuthorizationService)
    {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "Regions"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(
            rootView: PermissionView(authorization: authorization)
            {
                [weak window] in
                window?.close()
            }
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder)
    {
        nil
    }

    func present()
    {
        guard let window
        else
        {
            return
        }
        window.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
