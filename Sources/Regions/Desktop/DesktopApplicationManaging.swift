import AppKit
import Foundation

@MainActor
protocol DesktopApplicationManaging: AnyObject
{
    var processIdentifier: pid_t { get }
    var bundleIdentifier: String? { get }
    var activationPolicy: NSApplication.ActivationPolicy { get }
    var isHidden: Bool { get }
    var isTerminated: Bool { get }

    func hide() -> Bool
    func unhide() -> Bool
    func activate(options: NSApplication.ActivationOptions) -> Bool
}
