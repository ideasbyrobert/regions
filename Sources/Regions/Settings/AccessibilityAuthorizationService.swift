import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class AccessibilityAuthorizationService: ObservableObject
{
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    func refresh()
    {
        isTrusted = AXIsProcessTrusted()
    }

    func requestAuthorizationInSystemSettings()
    {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        if !isTrusted
        {
            openSystemSettings()
        }
    }

    func openSystemSettings()
    {
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:"
                    + "com.apple.settings.PrivacySecurity.extension"
                    + "?Privacy_Accessibility"
            )
        else
        {
            return
        }
        NSWorkspace.shared.open(url)
    }

}
