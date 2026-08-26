import AppKit

@MainActor
struct DesktopWorkspaceProvider: DesktopWorkspaceProviding
{
    var runningApplications: [any DesktopApplicationManaging]
    {
        NSWorkspace.shared.runningApplications
    }

    var frontmostApplication: (any DesktopApplicationManaging)?
    {
        NSWorkspace.shared.frontmostApplication
    }
}
