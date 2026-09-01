import Foundation
@testable import Regions

@MainActor
final class FakeDesktopWorkspace: DesktopWorkspaceProviding
{
    var runningApplications: [any DesktopApplicationManaging]
    var frontmostApplication: (any DesktopApplicationManaging)?

    init(
        runningApplications: [any DesktopApplicationManaging],
        frontmostApplication: (any DesktopApplicationManaging)?
    )
    {
        self.runningApplications = runningApplications
        self.frontmostApplication = frontmostApplication
    }
}
