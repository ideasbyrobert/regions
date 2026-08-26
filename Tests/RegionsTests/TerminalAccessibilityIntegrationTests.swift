import AppKit
import ApplicationServices
import XCTest

@testable import Regions

@MainActor
final class TerminalAccessibilityIntegrationTests: XCTestCase
{
    func testTerminalWindowsArrangeAtEightyByFortyEightAndRestore() async throws
    {
        try XCTSkipUnless(
            Self.liveModeEnabled,
            "Run with --live-terminal to automate disposable Terminal windows."
        )
        try XCTSkipUnless(
            AXIsProcessTrusted(),
            "Grant RegionsTests-Runner.app Window Control permission."
        )
        try XCTSkipIf(
            !NSRunningApplication.runningApplications(
                withBundleIdentifier: TerminalWindowSizingService
                    .bundleIdentifier
            ).isEmpty,
            "Quit Terminal before running the disposable live test."
        )

        let application = try await launchFreshTerminal()
        defer
        {
            application.terminate()
        }

        let terminalWindowSizing = TerminalWindowSizingService()
        let authorization = await terminalWindowSizing.requestAuthorization()
        try XCTSkipUnless(
            authorization.permitsAutomation,
            "Grant the development test runner Terminal Automation permission."
        )

        let initialStates = try await waitForTerminalStates(
            terminalWindowSizing,
            count: 1
        )
        guard initialStates.count == 1
        else
        {
            XCTFail(
                "The fresh Terminal instance did not expose one disposable "
                    + "window"
            )
            return
        }
        try createTerminalWindows(count: 4)
        let originalStates = try await waitForTerminalStates(
            terminalWindowSizing,
            count: 5
        )
        guard originalStates.count == 5
        else
        {
            XCTFail("Terminal did not expose five disposable windows")
            return
        }

        let provider = DisplaySnapshotProvider()
        let converter = ScreenCoordinateConverter(
            primaryDisplayMaximumY: provider.primaryDisplayMaximumY()
        )
        let manager = AccessibilityWindowActor()
        let originalWindows = try await waitForWindows(
            manager,
            processIdentifier: application.processIdentifier,
            count: 5,
            converter: converter
        )
        guard originalWindows.count == 5
        else
        {
            XCTFail(
                "Accessibility did not expose five disposable Terminal windows")
            return
        }
        guard
            let targetScreen = provider.screen(
                containing: originalWindows[0].frame,
                in: provider.snapshots()
            )
        else
        {
            XCTFail("No display contains the fresh Terminal windows")
            return
        }
        let service = BalancedWindowArrangementService(
            windowManager: manager,
            terminalWindowSizing: terminalWindowSizing,
            calculator: GridLayoutCalculator()
        )

        let arrangement = await service.arrange(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: TerminalWindowSizingService.bundleIdentifier,
            targetScreen: targetScreen,
            spacing: 8,
            converter: converter
        )
        XCTAssertEqual(
            arrangement,
            .arranged(
                windowCount: 5, usedBestEffort: false, terminalSized: true)
        )
        let managedStates = try terminalWindowSizing.captureStates()
        XCTAssertEqual(
            TerminalWindowSizingService.normalized(managedStates),
            TerminalWindowSizingService.normalized(
                TerminalWindowSizingService.managedStates(from: originalStates)
            )
        )
        let arrangedWindows = try await waitForWindows(
            manager,
            processIdentifier: application.processIdentifier,
            count: 5,
            converter: converter
        )
        XCTAssertEqual(rowCounts(in: arrangedWindows), [3, 2])
        XCTAssertTrue(
            arrangedWindows.allSatisfy
            {
                targetScreen.visibleFrame.contains($0.frame)
            })

        let restore = await service.restorePrevious(converter: converter)
        XCTAssertEqual(
            restore,
            .restored(windowCount: 5, usedBestEffort: false)
        )
        let restoredStates = try terminalWindowSizing.captureStates()
        XCTAssertEqual(
            TerminalWindowSizingService.normalized(restoredStates),
            TerminalWindowSizingService.normalized(originalStates)
        )
        for originalWindow in originalWindows
        {
            let capture = await manager.snapshot(
                for: originalWindow.token,
                converter: converter
            )
            guard case .captured(let restoredWindow) = capture
            else
            {
                XCTFail("A restored Terminal window could not be recaptured")
                return
            }
            XCTAssertTrue(
                approximatelyEqual(
                    restoredWindow.frame,
                    originalWindow.frame,
                    tolerance: 4
                )
            )
        }
    }

    private func launchFreshTerminal() async throws -> NSRunningApplication
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-F", "-a", "Terminal"]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0
        else
        {
            throw CocoaError(.executableRuntimeMismatch)
        }

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline
        {
            if let application = NSRunningApplication.runningApplications(
                withBundleIdentifier: TerminalWindowSizingService
                    .bundleIdentifier
            ).first
            {
                return application
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CocoaError(.fileNoSuchFile)
    }

    private func createTerminalWindows(count: Int) throws
    {
        let source = """
            tell application id "com.apple.Terminal"
                repeat (count) times
                    do script ""
                end repeat
            end tell
            """
        guard let script = NSAppleScript(source: source)
        else
        {
            throw CocoaError(.coderInvalidValue)
        }
        var errorInformation: NSDictionary?
        _ = script.executeAndReturnError(&errorInformation)
        if let errorInformation
        {
            let message =
                errorInformation[NSAppleScript.errorMessage] as? String
                ?? "Terminal did not create disposable windows"
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code:
                    (
                        errorInformation[
                            NSAppleScript.errorNumber
                        ] as? NSNumber
                    )?.intValue ?? 0,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private func waitForTerminalStates(
        _ service: TerminalWindowSizingService,
        count: Int
    ) async throws -> [TerminalWindowState]
    {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline
        {
            let states = try service.captureStates()
            if states.count == count
            {
                return states
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        return try service.captureStates()
    }

    private func waitForWindows(
        _ manager: AccessibilityWindowActor,
        processIdentifier: pid_t,
        count: Int,
        converter: ScreenCoordinateConverter
    ) async throws -> [ManagedWindowSnapshot]
    {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline
        {
            let capture = await manager.captureStandardWindows(
                processIdentifier: processIdentifier,
                converter: converter
            )
            if case .success(let windows) = capture, windows.count == count
            {
                return windows
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let capture = await manager.captureStandardWindows(
            processIdentifier: processIdentifier,
            converter: converter
        )
        switch capture
        {
        case .success(let windows):
            return windows
        case .failure(let failure):
            throw NSError(
                domain: "Regions.TerminalAccessibilityIntegrationTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: failure.message]
            )
        }
    }

    private func rowCounts(
        in windows: [ManagedWindowSnapshot]
    ) -> [Int]
    {
        let ordered = windows.sorted
        {
            $0.frame.minY > $1.frame.minY
        }
        var rows: [[ManagedWindowSnapshot]] = []
        for window in ordered
        {
            if let index = rows.firstIndex(where:
            {
                guard let first = $0.first
                else
                {
                    return false
                }
                return abs(first.frame.minY - window.frame.minY) <= 4
            })
            {
                rows[index].append(window)
            } else
            {
                rows.append([window])
            }
        }
        return rows.map(\.count).sorted(by: >)
    }

    private func approximatelyEqual(
        _ first: CGRect,
        _ second: CGRect,
        tolerance: CGFloat
    ) -> Bool
    {
        abs(first.minX - second.minX) <= tolerance
            && abs(first.minY - second.minY) <= tolerance
            && abs(first.width - second.width) <= tolerance
            && abs(first.height - second.height) <= tolerance
    }

    private static var liveModeEnabled: Bool
    {
        #if REGIONS_RUN_TERMINAL_TESTS
            true
        #else
            false
        #endif
    }
}
