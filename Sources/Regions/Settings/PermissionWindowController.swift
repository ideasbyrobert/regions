import AppKit
import SwiftUI

@MainActor
final class PermissionWindowController: NSWindowController, NSWindowDelegate
{
    private let authorization: AccessibilityAuthorizationService

    init(authorization: AccessibilityAuthorizationService)
    {
        self.authorization = authorization
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 500, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "Regions"
        window.isReleasedWhenClosed = false
        window.delegate = self
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
        if !authorization.isTrusted && !ProcessInfo.processInfo.arguments.contains("--ui-testing")
        {
            NSApp.setActivationPolicy(.regular)
        }
        window.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification)
    {
        if authorization.isTrusted
        {
            NSApp.setActivationPolicy(.accessory)
        }
        authorization.handleWindowClosed()
    }
}
