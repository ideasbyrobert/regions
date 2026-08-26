import Foundation

struct RegionContext: Equatable, Sendable
{
    let window: ManagedWindowSnapshot
    let screen: ScreenSnapshot
    let applicationWindowCount: Int
    let displayCount: Int
    let isTerminal: Bool
    let hasSavedLayout: Bool
    let savedWindowCount: Int?
    let canUndo: Bool

    var orientation: RegionOrientation
    {
        RegionOrientation(visibleFrame: screen.visibleFrame)
    }

    var canArrangeApplication: Bool
    {
        (2...8).contains(applicationWindowCount)
    }

    var canRestoreSavedLayout: Bool
    {
        hasSavedLayout && savedWindowCount == applicationWindowCount
    }
}
