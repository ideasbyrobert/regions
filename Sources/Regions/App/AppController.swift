import AppKit
import Combine
import Foundation

@MainActor
final class AppController: ObservableObject
{
    static let shared = AppController()

    @Published private(set) var statusMessage: String?
    @Published private(set) var shortcutErrorMessage: String?
    @Published private(set) var regionContext: RegionContext?

    let preferences = AppPreferences.shared
    let authorization = AccessibilityAuthorizationService()
    let launchAtLogin = LaunchAtLoginService()
    let terminalWindowSizing = TerminalWindowSizingService()

    private let tracker = TargetWindowTracker()
    private let displayProvider = DisplaySnapshotProvider()
    private let calculator: any LayoutCalculating = GridLayoutCalculator()
    private let transferCalculator = DisplayTransferCalculator()
    private let windowManager: any WindowManaging =
        AccessibilityWindowActor()
    private let hotKeyService = HotKeyService()
    private let savedAppLayoutStore = SavedAppLayoutStore()
    private lazy var paletteController = PaletteController(
        calculator: calculator,
        preferences: preferences
    )
    private lazy var arrangementService =
        BalancedWindowArrangementService(
            windowManager: windowManager,
            terminalWindowSizing: terminalWindowSizing,
            calculator: calculator
        )
    private lazy var displayService = DisplayWindowManagementService(
        windowManager: windowManager,
        displayProvider: displayProvider,
        calculator: calculator,
        transferCalculator: transferCalculator
    )
    private lazy var permissionWindowController =
        PermissionWindowController(authorization: authorization)
    private var contextRequestIdentifier = UUID()
    private var isStarted = false

    private init()
    {
    }

    func start()
    {
        guard !isStarted
        else
        {
            return
        }
        isStarted = true
        tracker.start()
        if let bundleIdentifier = liveUITestTargetBundleIdentifier,
            let application = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).first
        {
            tracker.pinTargetApplicationForTesting(application)
        }
        authorization.refresh()
        if isUITesting
        {
            preferences.spacing = 8
            preferences.showsPreview = false
            preferences.adjustmentStep = 32
        }
        registerPaletteShortcut(preferences.paletteShortcut)

        if isLiveArrangementUITesting
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)
            {
                self.arrangeApplicationWindows()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3)
            {
                self.restorePreviousFrame()
            }
        }

        if isLiveDisplayTransferUITesting
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)
            {
                self.moveFocusedWindowToNextDisplay()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3)
            {
                self.restorePreviousFrame()
            }
        }

        if isPaletteUITesting
        {
            DispatchQueue.main.async
            {
                self.presentUITestPalette()
            }
        } else if isPermissionUITesting
        {
            DispatchQueue.main.async
            {
                self.showPermissionWindow()
            }
        } else if !authorization.isTrusted && !isUITesting
        {
            showPermissionWindow()
        }
    }

    func openPalette()
    {
        if isUITesting
        {
            presentUITestPalette()
            return
        }
        Task
        {
            [self] in
            guard
                let context = await captureRegionContext(
                    reportsFailure: true
                )
            else
            {
                return
            }
            presentPalette(context: context)
        }
    }

    func refreshRegionContext()
    {
        if isUITesting
        {
            regionContext = testingContext()
            return
        }
        let requestIdentifier = UUID()
        contextRequestIdentifier = requestIdentifier
        Task
        {
            [self] in
            let context = await captureRegionContext(
                reportsFailure: false
            )
            guard contextRequestIdentifier == requestIdentifier
            else
            {
                return
            }
            regionContext = context
        }
    }

    func arrangeApplicationWindows()
    {
        Task
        {
            [self] in
            guard
                let context = await captureRegionContext(
                    reportsFailure: true
                )
            else
            {
                return
            }
            guard context.canArrangeApplication
            else
            {
                statusMessage =
                    context.applicationWindowCount < 2
                    ? "Open another app window first."
                    : "Regions can arrange at most eight windows."
                return
            }
            let converter = currentConverter()
            let result: WindowArrangementResult
            if context.isTerminal
                || context.applicationWindowCount > 6
            {
                result = await arrangementService.arrange(
                    processIdentifier: context.window.processIdentifier,
                    bundleIdentifier: targetBundleIdentifier,
                    targetScreen: context.screen,
                    spacing: preferences.spacing,
                    converter: converter
                )
            } else
            {
                result = await arrangementService.arrangeThreeByTwo(
                    processIdentifier: context.window.processIdentifier,
                    targetScreen: context.screen,
                    spacing: preferences.spacing,
                    converter: converter
                )
            }
            handle(result)
            refreshRegionContext()
        }
    }

    func saveAppLayout()
    {
        Task
        {
            [self] in
            guard let bundleIdentifier = targetBundleIdentifier,
                let capture = await captureWindowsOnFocusedDisplay()
            else
            {
                return
            }
            guard capture.windows.count > 1
            else
            {
                statusMessage = "Open another app window before saving."
                return
            }
            let layout = SavedAppLayout(
                bundleIdentifier: bundleIdentifier,
                windowFrames: capture.windows.map
                {
                    SavedWindowFrame(
                        frame: $0.frame,
                        within: capture.screen.visibleFrame
                    )
                }
            )
            savedAppLayoutStore.save(layout)
            statusMessage =
                "Saved \(capture.windows.count) app window positions."
            refreshRegionContext()
        }
    }

    func restoreAppLayout()
    {
        Task
        {
            [self] in
            guard let bundleIdentifier = targetBundleIdentifier,
                let layout = savedAppLayoutStore.layout(
                    bundleIdentifier: bundleIdentifier
                ),
                let capture = await captureWindowsOnFocusedDisplay()
            else
            {
                statusMessage = "No saved layout is available for this app."
                return
            }
            guard capture.windows.count == layout.windowFrames.count
            else
            {
                statusMessage =
                    "The saved layout expects "
                    + "\(layout.windowFrames.count) windows."
                return
            }
            let requests = zip(
                capture.windows,
                layout.windowFrames
            ).map
            {
                window, savedFrame in
                WindowPlacementRequest(
                    token: window.token,
                    target: savedFrame.target(on: capture.screen),
                    historyPreviousFrame: window.frame,
                    command: nil
                )
            }
            let result = await windowManager.applyBatch(
                requests,
                terminalState: nil,
                converter: currentConverter()
            )
            handle(result)
            refreshRegionContext()
        }
    }

    func forgetAppLayout()
    {
        guard let bundleIdentifier = targetBundleIdentifier
        else
        {
            statusMessage = MoveFailure.noTargetApplication.message
            return
        }
        savedAppLayoutStore.remove(bundleIdentifier: bundleIdentifier)
        statusMessage = "Forgot the saved layout for this app."
        refreshRegionContext()
    }

    func gatherAppWindows()
    {
        Task
        {
            [self] in
            guard
                let context = await captureRegionContext(
                    reportsFailure: true
                )
            else
            {
                return
            }
            let screens = displayProvider.snapshots()
            guard screens.count > 1
            else
            {
                statusMessage = "No other display is connected."
                return
            }
            let result = await displayService.moveAppWindows(
                processIdentifier: context.window.processIdentifier,
                to: context.screen,
                screens: screens,
                spacing: preferences.spacing,
                converter: currentConverter()
            )
            handle(result)
            refreshRegionContext()
        }
    }

    func moveFocusedWindowToPreviousDisplay()
    {
        moveFocusedWindow(to: .previous)
    }

    func moveFocusedWindowToNextDisplay()
    {
        moveFocusedWindow(to: .next)
    }

    func restorePreviousFrame()
    {
        Task
        {
            [self] in
            let result = await arrangementService.restorePrevious(
                converter: currentConverter()
            )
            handle(result)
            refreshRegionContext()
        }
    }

    func showPermissionWindow()
    {
        authorization.refresh()
        permissionWindowController.present()
    }

    func updatePaletteShortcut(_ shortcut: KeyboardShortcut)
    {
        let previousShortcut = preferences.paletteShortcut
        let result = hotKeyService.register(shortcut)
        {
            [weak self] in
            self?.openPalette()
        }
        switch result
        {
        case .registered:
            preferences.setPaletteShortcut(shortcut)
            shortcutErrorMessage = nil
        case .conflict:
            shortcutErrorMessage = "That shortcut is already in use."
            registerPaletteShortcut(previousShortcut)
        case .failed(let status):
            shortcutErrorMessage =
                "Shortcut registration failed with status \(status)."
            registerPaletteShortcut(previousShortcut)
        }
    }

    func showAbout()
    {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func quit()
    {
        NSApp.terminate(nil)
    }

    private func presentPalette(context: RegionContext)
    {
        let session = PaletteSession(context: context)
        paletteController.present(session: session)
        {
            [weak self] placement, session in
            self?.apply(placement, to: session)
        }
    }

    private func apply(
        _ placement: RegionPlacement,
        to session: PaletteSession
    )
    {
        Task
        {
            [self] in
            let snapshotResult = await windowManager.snapshot(
                for: session.window.token,
                converter: currentConverter()
            )
            guard case .captured(let currentWindow) = snapshotResult,
                currentWindow.processIdentifier
                    == session.window.processIdentifier,
                currentWindow.isResizable
                    || placement.size == nil,
                let currentScreen = currentScreen(for: currentWindow),
                currentScreen.displayID == session.screen.displayID,
                RegionOrientation(
                    visibleFrame: currentScreen.visibleFrame
                ) == placement.orientation
            else
            {
                statusMessage =
                    "The window or display changed. Open Regions again."
                return
            }
            let command = LayoutCommand.region(placement)
            let target = calculator.target(
                for: command,
                on: currentScreen,
                currentWindowFrame: currentWindow.frame,
                spacing: preferences.spacing
            )
            let result = await windowManager.apply(
                target: target,
                to: currentWindow.token,
                converter: currentConverter(),
                command: command
            )
            handle(result)
            refreshRegionContext()
        }
    }

    private func captureRegionContext(
        reportsFailure: Bool
    ) async -> RegionContext?
    {
        authorization.refresh()
        guard authorization.isTrusted
        else
        {
            if reportsFailure
            {
                statusMessage =
                    MoveFailure.accessibilityPermissionRequired.message
                showPermissionWindow()
            }
            return nil
        }
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            if reportsFailure
            {
                statusMessage = MoveFailure.noTargetApplication.message
            }
            return nil
        }
        let converter = currentConverter()
        let focusedResult = await windowManager.captureFocusedWindow(
            processIdentifier: processIdentifier,
            converter: converter
        )
        guard case .captured(let window) = focusedResult,
            let screen = currentScreen(for: window)
        else
        {
            if reportsFailure,
                case .failed(let failure) = focusedResult
            {
                statusMessage = failure.message
            }
            return nil
        }
        let windowsResult = await windowManager.captureStandardWindows(
            processIdentifier: processIdentifier,
            converter: converter
        )
        let windowCount: Int
        if case .success(let windows) = windowsResult
        {
            windowCount = windows.count
        } else
        {
            windowCount = 1
        }
        let bundleIdentifier = targetBundleIdentifier
        let savedLayout = bundleIdentifier.flatMap
        {
            savedAppLayoutStore.layout(bundleIdentifier: $0)
        }
        let undoPreparation = await windowManager.prepareUndo(
            converter: converter
        )
        let canUndo: Bool
        if case .success = undoPreparation
        {
            canUndo = true
        } else
        {
            canUndo = false
        }
        return RegionContext(
            window: window,
            screen: screen,
            applicationWindowCount: windowCount,
            displayCount: displayProvider.snapshots().count,
            isTerminal:
                bundleIdentifier
                == TerminalWindowSizingService.bundleIdentifier,
            hasSavedLayout: savedLayout != nil,
            savedWindowCount: savedLayout?.windowFrames.count,
            canUndo: canUndo
        )
    }

    private func captureWindowsOnFocusedDisplay()
        async -> (screen: ScreenSnapshot, windows: [ManagedWindowSnapshot])?
    {
        guard
            let context = await captureRegionContext(
                reportsFailure: true
            )
        else
        {
            return nil
        }
        let result = await windowManager.captureStandardWindows(
            processIdentifier: context.window.processIdentifier,
            converter: currentConverter()
        )
        guard case .success(let capturedWindows) = result
        else
        {
            statusMessage = MoveFailure.noManageableWindows.message
            return nil
        }
        let screens = displayProvider.snapshots()
        var windows = capturedWindows.filter
        {
            displayProvider.screen(containing: $0.frame, in: screens)?
                .displayID == context.screen.displayID
        }
        if let focusedIndex = windows.firstIndex(where:
        {
            $0.token == context.window.token
        })
        {
            windows.remove(at: focusedIndex)
            windows.insert(context.window, at: 0)
        }
        guard !windows.isEmpty
        else
        {
            statusMessage = MoveFailure.noManageableWindows.message
            return nil
        }
        return (context.screen, windows)
    }

    private func moveFocusedWindow(to direction: DisplayDirection)
    {
        Task
        {
            [self] in
            guard
                let context = await captureRegionContext(
                    reportsFailure: true
                )
            else
            {
                return
            }
            let screens = displayProvider.snapshots()
            guard
                let destination = displayProvider.adjacent(
                    to: context.screen,
                    direction: direction,
                    in: screens
                )
            else
            {
                statusMessage = "No other display is connected."
                return
            }
            let previousCommand = await windowManager.lastCommand(
                for: context.window.token
            )
            let command = previousCommand?.adapted(to: destination)
            let target: LayoutTarget
            if let command
            {
                target = calculator.target(
                    for: command,
                    on: destination,
                    currentWindowFrame: context.window.frame,
                    spacing: preferences.spacing
                )
            } else
            {
                target = transferCalculator.target(
                    for: context.window.frame,
                    from: context.screen,
                    to: destination,
                    spacing: preferences.spacing
                )
            }
            let result = await windowManager.apply(
                target: target,
                to: context.window.token,
                converter: currentConverter(),
                command: command
            )
            handle(result)
            refreshRegionContext()
        }
    }

    private func currentScreen(
        for snapshot: ManagedWindowSnapshot
    ) -> ScreenSnapshot?
    {
        let screens = displayProvider.snapshots()
        let screen = displayProvider.screen(
            containing: snapshot.frame,
            in: screens
        )
        if screen == nil
        {
            statusMessage = MoveFailure.noDisplays.message
        }
        return screen
    }

    private func currentConverter() -> ScreenCoordinateConverter
    {
        ScreenCoordinateConverter(
            primaryDisplayMaximumY:
                displayProvider.primaryDisplayMaximumY()
        )
    }

    private func handle(_ result: MoveResult)
    {
        switch result
        {
        case .moved:
            statusMessage = nil
        case .bestEffort:
            statusMessage =
                "The app applied the closest size this window permits."
        case .failed(let failure):
            statusMessage = failure.message
        }
    }

    private func handle(_ result: WindowArrangementResult)
    {
        switch result
        {
        case .arranged(
            let windowCount,
            let usedBestEffort,
            let terminalSized
        ):
            if terminalSized
            {
                statusMessage =
                    usedBestEffort
                    ? "Arranged \(windowCount) Terminal windows with limits."
                    : "Arranged \(windowCount) Terminal windows at 80 × 48."
            } else
            {
                statusMessage =
                    usedBestEffort
                    ? "Arranged \(windowCount) windows with size limits."
                    : "Arranged \(windowCount) app windows."
            }
        case .restored(let windowCount, let usedBestEffort):
            statusMessage =
                usedBestEffort
                ? "Restored \(windowCount) windows with size limits."
                : "Restored \(windowCount) windows."
        case .failed(let failure):
            statusMessage = failure.message
        }
    }

    private func handle(_ result: DisplayWindowManagementResult)
    {
        switch result
        {
        case .moved(let windowCount, let usedBestEffort):
            statusMessage =
                usedBestEffort
                ? "Moved \(windowCount) app windows with size limits."
                : "Moved \(windowCount) app windows."
        case .alreadyOnDisplay:
            statusMessage = "All app windows are already on this display."
        case .failed(let failure):
            statusMessage = failure.message
        }
    }

    private func registerPaletteShortcut(_ shortcut: KeyboardShortcut)
    {
        let result = hotKeyService.register(shortcut)
        {
            [weak self] in
            self?.openPalette()
        }
        switch result
        {
        case .registered:
            shortcutErrorMessage = nil
        case .conflict:
            shortcutErrorMessage =
                "The saved shortcut is already in use."
        case .failed(let status):
            shortcutErrorMessage =
                "Shortcut registration failed with status \(status)."
        }
    }

    private var targetBundleIdentifier: String?
    {
        guard let processIdentifier = tracker.processIdentifier
        else
        {
            return nil
        }
        return NSRunningApplication(
            processIdentifier: processIdentifier
        )?.bundleIdentifier
    }

    private var isUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    private var isPaletteUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-palette"
        )
    }

    private var isPermissionUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-permission"
        )
    }

    private var isLiveArrangementUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-live-arrange-and-restore"
        )
    }

    private var isLiveDisplayTransferUITesting: Bool
    {
        ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-live-display-transfer-and-restore"
        )
    }

    private var liveUITestTargetBundleIdentifier: String?
    {
        let prefix = "--ui-testing-live-target-bundle-identifier="
        guard
            let argument = ProcessInfo.processInfo.arguments.first(where:
            {
                $0.hasPrefix(prefix)
            })
        else
        {
            return nil
        }
        return String(argument.dropFirst(prefix.count))
    }

    private func integerArgument(
        prefix: String,
        fallback: Int
    ) -> Int
    {
        guard
            let argument = ProcessInfo.processInfo.arguments.first(where:
            {
                $0.hasPrefix(prefix)
            })
        else
        {
            return fallback
        }
        return Int(argument.dropFirst(prefix.count)) ?? fallback
    }

    private func testingContext() -> RegionContext?
    {
        guard let baseScreen = displayProvider.snapshots().first
        else
        {
            return nil
        }
        let isPortrait = ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-portrait"
        )
        let visibleFrame: CGRect
        if isPortrait
        {
            visibleFrame = CGRect(
                x: baseScreen.visibleFrame.minX + 20,
                y: baseScreen.visibleFrame.minY + 20,
                width: min(500, baseScreen.visibleFrame.width - 40),
                height: min(700, baseScreen.visibleFrame.height - 40)
            )
        } else
        {
            visibleFrame = baseScreen.visibleFrame
        }
        let screen = ScreenSnapshot(
            displayID: baseScreen.displayID,
            frame: baseScreen.frame,
            visibleFrame: visibleFrame,
            backingScaleFactor: baseScreen.backingScaleFactor
        )
        let window = ManagedWindowSnapshot(
            token: ManagedWindowToken(id: UUID()),
            processIdentifier:
                ProcessInfo.processInfo.processIdentifier,
            frame: CGRect(
                x: visibleFrame.midX - visibleFrame.width * 0.35,
                y: visibleFrame.midY - visibleFrame.height * 0.35,
                width: visibleFrame.width * 0.7,
                height: visibleFrame.height * 0.7
            ),
            isResizable: !ProcessInfo.processInfo.arguments.contains(
                "--ui-testing-nonresizable"
            )
        )
        let windowCount = integerArgument(
            prefix: "--ui-testing-window-count=",
            fallback: 3
        )
        let savedCount = integerArgument(
            prefix: "--ui-testing-saved-window-count=",
            fallback: windowCount
        )
        let hasSaved = ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-saved-layout"
        )
        return RegionContext(
            window: window,
            screen: screen,
            applicationWindowCount: windowCount,
            displayCount: ProcessInfo.processInfo.arguments.contains(
                "--ui-testing-multiple-displays"
            ) ? 2 : 1,
            isTerminal: ProcessInfo.processInfo.arguments.contains(
                "--ui-testing-terminal"
            ),
            hasSavedLayout: hasSaved,
            savedWindowCount: hasSaved ? savedCount : nil,
            canUndo: ProcessInfo.processInfo.arguments.contains(
                "--ui-testing-can-undo"
            )
        )
    }

    private func presentUITestPalette()
    {
        for window in NSApp.windows where !(window is PalettePanel)
        {
            window.orderOut(nil)
        }
        guard let context = testingContext()
        else
        {
            return
        }
        presentPalette(context: context)
        if let path = ProcessInfo.processInfo.environment[
            "REGIONS_PALETTE_SNAPSHOT"
        ]
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1)
            {
                self.paletteController.snapshot(to: path)
                NSApp.terminate(nil)
            }
        }
    }
}
