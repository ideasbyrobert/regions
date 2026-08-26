import Foundation

enum DesktopVisibilityResult: Equatable, Sendable
{
    case shown(hiddenApplicationCount: Int)
    case restored(applicationCount: Int)
    case alreadyShown
    case nothingToRestore
    case failed(String)
}
