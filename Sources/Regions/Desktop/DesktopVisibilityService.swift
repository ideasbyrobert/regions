import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class DesktopVisibilityService: ObservableObject
{
    @Published private(set) var isDesktopShown = false

    private let workspace: any DesktopWorkspaceProviding
    private let currentProcessIdentifier: pid_t
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.ideasbyrobert.Regions",
        category: "Desktop"
    )
    private var hiddenApplications: [any DesktopApplicationManaging] = []
    private var previouslyFrontmostApplication:
        (any DesktopApplicationManaging)?

    convenience init()
    {
        self.init(
            workspace: DesktopWorkspaceProvider(),
            currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )
    }

    init(
        workspace: any DesktopWorkspaceProviding,
        currentProcessIdentifier: pid_t = ProcessInfo.processInfo
            .processIdentifier
    )
    {
        self.workspace = workspace
        self.currentProcessIdentifier = currentProcessIdentifier
    }

    func showDesktop() -> DesktopVisibilityResult
    {
        guard !isDesktopShown
        else
        {
            return .alreadyShown
        }
        let frontmostApplication = workspace.frontmostApplication
        let candidates = workspace.runningApplications.filter
        {
            application in
            application.processIdentifier != currentProcessIdentifier
                && application.bundleIdentifier != "com.apple.finder"
                && application.activationPolicy == .regular
                && !application.isHidden
                && !application.isTerminated
        }
        var hidden: [any DesktopApplicationManaging] = []
        for application in candidates
        {
            guard application.hide()
            else
            {
                var rollbackFailures: [any DesktopApplicationManaging] = []
                for hiddenApplication in hidden
                {
                    if !hiddenApplication.unhide()
                    {
                        rollbackFailures.append(hiddenApplication)
                    }
                }
                if !rollbackFailures.isEmpty
                {
                    previouslyFrontmostApplication = frontmostApplication
                    hiddenApplications = rollbackFailures
                    isDesktopShown = true
                    logger.error(
                        """
                        Show Desktop failed and retained retryable \
                        restore state
                        """
                    )
                    return .failed(
                        "An application could not be hidden, and some "
                            + "hidden applications still need restoration."
                    )
                }
                logger.error(
                    "Show Desktop failed and reverted hidden applications")
                return .failed(
                    "An application could not be hidden. "
                        + "No desktop state was saved."
                )
            }
            hidden.append(application)
        }
        previouslyFrontmostApplication = frontmostApplication
        hiddenApplications = hidden
        isDesktopShown = true
        logger.info(
            """
            Showed desktop by hiding \
            \(hidden.count, privacy: .public) applications
            """
        )
        return .shown(hiddenApplicationCount: hidden.count)
    }

    func restoreDesktop() -> DesktopVisibilityResult
    {
        guard isDesktopShown
        else
        {
            return .nothingToRestore
        }
        var restoredCount = 0
        var failedApplications: [any DesktopApplicationManaging] = []
        for application in hiddenApplications
        {
            if application.isTerminated || !application.isHidden
            {
                continue
            }
            if application.unhide()
            {
                restoredCount += 1
            } else
            {
                failedApplications.append(application)
            }
        }
        guard failedApplications.isEmpty
        else
        {
            hiddenApplications = failedApplications
            logger.error("Restore Desktop could not unhide every application")
            return .failed("Some applications could not be restored.")
        }
        let frontmostApplication = previouslyFrontmostApplication
        hiddenApplications = []
        previouslyFrontmostApplication = nil
        isDesktopShown = false
        if let frontmostApplication,
            !frontmostApplication.isTerminated
        {
            _ = frontmostApplication.activate(options: [.activateAllWindows])
        }
        logger.info(
            """
            Restored desktop visibility for \
            \(restoredCount, privacy: .public) applications
            """
        )
        return .restored(applicationCount: restoredCount)
    }
}
