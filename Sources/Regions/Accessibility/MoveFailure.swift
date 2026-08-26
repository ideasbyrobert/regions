import Foundation

enum MoveFailure: Error, Equatable, Sendable
{
    case accessibilityPermissionRequired
    case noTargetApplication
    case noFocusedWindow
    case noManageableWindows
    case unsupportedWindow
    case minimizedWindow
    case fullScreenWindow
    case windowNotMovable
    case windowActionUnavailable
    case staleWindow
    case windowChanged
    case nothingToUndo
    case terminalStateRestoreRequired
    case noDisplays
    case accessibilityFailure(Int32)

    var message: String
    {
        switch self
        {
        case .accessibilityPermissionRequired:
            "Window Control permission is required."
        case .noTargetApplication:
            "No application window is available."
        case .noFocusedWindow:
            "The target application has no focused window."
        case .noManageableWindows:
            "The target application has no manageable standard windows."
        case .unsupportedWindow:
            "This window type cannot be managed."
        case .minimizedWindow:
            "Restore the minimized window before moving it."
        case .fullScreenWindow:
            "Leave full screen before moving this window."
        case .windowNotMovable:
            "This window does not allow its position to be changed."
        case .windowActionUnavailable:
            "This window does not support that action."
        case .staleWindow:
            "The selected window is no longer available."
        case .windowChanged:
            "Undo was skipped because the window changed."
        case .nothingToUndo:
            "Nothing to undo."
        case .terminalStateRestoreRequired:
            "Terminal dimensions must be restored with the complete "
                + "arrangement."
        case .noDisplays:
            "No usable display is available."
        case .accessibilityFailure(let code):
            "The window rejected the request with Accessibility error \(code)."
        }
    }
}
