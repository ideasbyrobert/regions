import Foundation

@MainActor
protocol DesktopWorkspaceProviding
{
    var runningApplications: [any DesktopApplicationManaging] { get }
    var frontmostApplication: (any DesktopApplicationManaging)? { get }
}
