import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class AccessibilityAuthorizationService: ObservableObject
{
    @Published private(set) var isTrusted: Bool

    private let checkTrust: @Sendable () -> Bool
    private let promptForTrust: @Sendable () -> Bool
    private let openSettingsURL: @MainActor (URL) -> Bool
    private let terminateApplication: @MainActor () -> Void
    private let exitDelay: TimeInterval
    private var timer: Timer?
    private var exitWorkItem: DispatchWorkItem?

    init(
        checkTrust: @escaping @Sendable () -> Bool =
        {
            AXIsProcessTrusted()
        },
        promptForTrust: @escaping @Sendable () -> Bool =
        {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        },
        openSettingsURL: @escaping @MainActor (URL) -> Bool =
        {
            url in
            NSWorkspace.shared.open(url)
        },
        terminateApplication: @escaping @MainActor () -> Void =
        {
            if !ProcessInfo.processInfo.arguments.contains("--ui-testing")
            {
                NSApp.terminate(nil)
            }
        },
        exitDelay: TimeInterval = 0.35
    )
    {
        self.checkTrust = checkTrust
        self.promptForTrust = promptForTrust
        self.openSettingsURL = openSettingsURL
        self.terminateApplication = terminateApplication
        self.exitDelay = exitDelay
        isTrusted = checkTrust()
    }

    func refresh()
    {
        isTrusted = checkTrust()
        if isTrusted
        {
            stopPolling()
            cancelScheduledTermination()
        }
    }

    func requestAuthorizationInSystemSettings()
    {
        stopPolling()
        isTrusted = promptForTrust()
        if isTrusted
        {
            cancelScheduledTermination()
            return
        }
        openSystemSettings()
        scheduleTermination()
    }

    func exitIfUntrusted()
    {
        stopPolling()
        refresh()
        guard !isTrusted
        else
        {
            return
        }
        cancelScheduledTermination()
        terminateApplication()
    }

    func handleWindowClosed()
    {
        stopPolling()
        refresh()
        guard !isTrusted
        else
        {
            return
        }
        if exitWorkItem == nil
        {
            terminateApplication()
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
        let candidates =
        [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]
        for candidate in candidates
        {
            guard let url = URL(string: candidate)
            else
            {
                continue
            }
            if openSettingsURL(url)
            {
                return
            }
        }
    }

    func stopPolling()
    {
        timer?.invalidate()
        timer = nil
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
                self?.refresh()
            }
        }
    }

    private func scheduleTermination()
    {
        cancelScheduledTermination()
        guard exitDelay > 0
        else
        {
            terminateApplication()
            return
        }
        let workItem = DispatchWorkItem
        {
            [weak self] in
            guard let self
            else
            {
                return
            }
            self.exitWorkItem = nil
            self.refresh()
            if !self.isTrusted
            {
                self.terminateApplication()
            }
        }
        exitWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + exitDelay,
            execute: workItem
        )
    }

    private func cancelScheduledTermination()
    {
        exitWorkItem?.cancel()
        exitWorkItem = nil
    }
}
