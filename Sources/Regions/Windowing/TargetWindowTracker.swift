import AppKit
import Combine
import Foundation

@MainActor
final class TargetWindowTracker: NSObject, ObservableObject
{
    @Published private(set) var processIdentifier: pid_t?

    private var isStarted = false
    private var pinnedProcessIdentifier: pid_t?

    func start()
    {
        guard !isStarted
        else
        {
            return
        }
        isStarted = true
        update(with: NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func pinTargetApplicationForTesting(_ application: NSRunningApplication)
    {
        pinnedProcessIdentifier = application.processIdentifier
        processIdentifier = application.processIdentifier
    }

    @objc
    private func applicationDidActivate(_ notification: Notification)
    {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        update(with: application)
    }

    private func update(with application: NSRunningApplication?)
    {
        guard pinnedProcessIdentifier == nil,
              let application,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !application.isTerminated
        else
        {
            return
        }
        processIdentifier = application.processIdentifier
    }
}
