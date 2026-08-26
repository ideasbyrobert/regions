import AppKit
import Foundation

@testable import Regions

@MainActor
final class FakeDesktopApplication: DesktopApplicationManaging
{
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let activationPolicy: NSApplication.ActivationPolicy
    var isHidden: Bool
    var isTerminated: Bool
    var hideSucceeds = true
    var unhideSucceeds = true
    var activateSucceeds = true
    private(set) var hideCount = 0
    private(set) var unhideCount = 0
    private(set) var activationCount = 0

    init(
        processIdentifier: pid_t,
        bundleIdentifier: String?,
        activationPolicy: NSApplication.ActivationPolicy = .regular,
        isHidden: Bool = false,
        isTerminated: Bool = false
    )
    {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.activationPolicy = activationPolicy
        self.isHidden = isHidden
        self.isTerminated = isTerminated
    }

    func hide() -> Bool
    {
        hideCount += 1
        if hideSucceeds
        {
            isHidden = true
        }
        return hideSucceeds
    }

    func unhide() -> Bool
    {
        unhideCount += 1
        if unhideSucceeds
        {
            isHidden = false
        }
        return unhideSucceeds
    }

    func activate(options: NSApplication.ActivationOptions) -> Bool
    {
        activationCount += 1
        return activateSucceeds
    }
}
