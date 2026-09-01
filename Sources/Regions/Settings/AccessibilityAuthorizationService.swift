import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class AccessibilityAuthorizationService: ObservableObject
{
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    private var timer: Timer?
    private var pollingAttempt = 0

    func refresh()
    {
        isTrusted = AXIsProcessTrusted()
        if isTrusted
        {
            timer?.invalidate()
            timer = nil
        }
    }

    func requestAuthorizationInSystemSettings()
    {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        startMonitoring()
        if !isTrusted
        {
            openSystemSettings()
        }
    }

    func startMonitoring()
    {
        refresh()
        if !isTrusted
        {
            beginPolling()
        }
    }

    func openSystemSettings()
    {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        )
        else
        {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func stopPolling()
    {
        timer?.invalidate()
        timer = nil
        pollingAttempt = 0
    }

    private func beginPolling()
    {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true)
        {
            [weak self] _ in
            Task
            {
                @MainActor in
                guard let self
                else
                {
                    return
                }
                self.pollingAttempt += 1
                self.refresh()
                if self.pollingAttempt >= 240
                {
                    self.stopPolling()
                }
            }
        }
    }
}
