import AppKit
import ApplicationServices
import XCTest

@testable import Regions

@MainActor
final class AccessibilityIntegrationTests: XCTestCase
{
    func testFixtureWindowsMoveThroughLiveAccessibilityBatchPath() async throws
    {
        try XCTSkipUnless(
            Self.liveModeEnabled,
            "Run with --live-accessibility to move fixture windows."
        )
        try XCTSkipUnless(AXIsProcessTrusted())

        let application = try await launchFixtureApplication()
        defer
        {
            application.terminate()
        }
        application.activate(options: [.activateAllWindows])
        try await Task.sleep(for: .milliseconds(750))

        let provider = DisplaySnapshotProvider()
        guard let screen = provider.snapshots().first
        else
        {
            XCTFail("No display is available")
            return
        }
        let converter = ScreenCoordinateConverter(
            primaryDisplayMaximumY: provider.primaryDisplayMaximumY()
        )
        let manager = AccessibilityWindowActor()
        let capture = await manager.captureStandardWindows(
            processIdentifier: application.processIdentifier,
            converter: converter
        )
        guard case .success(let snapshots) = capture
        else
        {
            XCTFail(
                "The fixture windows could not be captured for batch "
                    + "arrangement"
            )
            return
        }
        let arrangementService = BalancedWindowArrangementService(
            windowManager: manager,
            terminalWindowSizing: TerminalWindowSizingService(),
            calculator: GridLayoutCalculator()
        )
        let arrangementResult = await arrangementService.arrange(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            targetScreen: screen,
            spacing: 8,
            converter: converter
        )
        guard case .arranged(let arrangedCount, _, false) = arrangementResult
        else
        {
            XCTFail("The fixture windows were not arranged")
            return
        }
        XCTAssertEqual(arrangedCount, snapshots.count)
        for snapshot in snapshots
        {
            let arrangedCapture = await manager.snapshot(
                for: snapshot.token,
                converter: converter
            )
            guard case .captured(let arrangedWindow) = arrangedCapture
            else
            {
                XCTFail("The arranged fixture window could not be recaptured")
                return
            }
            XCTAssertTrue(screen.visibleFrame.intersects(arrangedWindow.frame))
        }

        guard let firstWindow = snapshots.first
        else
        {
            XCTFail("The fixture did not expose a standard window")
            return
        }
        let centeredCommand = LayoutCommand.preset(.centeredHalf)
        let centeredTarget = GridLayoutCalculator().target(
            for: centeredCommand,
            on: screen,
            currentWindowFrame: firstWindow.frame,
            spacing: 8
        )
        let centeredResult = await manager.apply(
            target: centeredTarget,
            to: firstWindow.token,
            converter: converter,
            command: centeredCommand
        )
        let centeredFrame: CGRect
        switch centeredResult
        {
        case .moved(let frame), .bestEffort(let frame):
            centeredFrame = frame
        case .failed(let failure):
            XCTFail(failure.message)
            return
        }
        let raiseResult = await manager.perform(
            .bringToFront,
            on: firstWindow.token,
            converter: converter
        )
        XCTAssertEqual(raiseResult, .completed)
        try await Task.sleep(for: .milliseconds(100))
        let hitCapture = await manager.captureStandardWindow(
            at: CGPoint(x: centeredFrame.midX, y: centeredFrame.midY),
            converter: converter
        )
        guard case .captured(let hitWindow) = hitCapture
        else
        {
            XCTFail("The positioned fixture window could not be hit-tested")
            return
        }
        XCTAssertEqual(
            hitWindow.processIdentifier, application.processIdentifier)

        let adjustmentCommand = LayoutCommand.adjustment(.moveRight, amount: 40)
        let adjustmentTarget = GridLayoutCalculator().target(
            for: adjustmentCommand,
            on: screen,
            currentWindowFrame: centeredFrame,
            spacing: 8
        )
        let adjustmentResult = await manager.apply(
            target: adjustmentTarget,
            to: firstWindow.token,
            converter: converter,
            command: adjustmentCommand
        )
        switch adjustmentResult
        {
        case .moved, .bestEffort:
            break
        case .failed(let failure):
            XCTFail(failure.message)
            return
        }
        let undoResult = await manager.undoLast(converter: converter)
        switch undoResult
        {
        case .moved(let frame), .bestEffort(let frame):
            XCTAssertEqual(frame.minX, centeredFrame.minX, accuracy: 2)
            XCTAssertEqual(frame.minY, centeredFrame.minY, accuracy: 2)
        case .failed(let failure):
            XCTFail(failure.message)
        }

        let screens = provider.snapshots()
        if let sourceScreen = provider.screen(
            containing: centeredFrame, in: screens),
            let destinationScreen = provider.adjacent(
                to: sourceScreen,
                direction: .next,
                in: screens
            )
        {
            let displayService = DisplayWindowManagementService(
                windowManager: manager,
                displayProvider: provider,
                calculator: GridLayoutCalculator(),
                transferCalculator: DisplayTransferCalculator()
            )
            let transferResult = await displayService.moveAppWindows(
                processIdentifier: application.processIdentifier,
                to: destinationScreen,
                screens: screens,
                spacing: 8,
                converter: converter
            )
            guard case .moved(let movedCount, _) = transferResult
            else
            {
                XCTFail(
                    "The fixture windows were not transferred as one "
                        + "display batch"
                )
                return
            }
            XCTAssertEqual(movedCount, snapshots.count)
            let transferredCapture = await manager.captureStandardWindows(
                processIdentifier: application.processIdentifier,
                converter: converter
            )
            guard case .success(let transferredWindows) = transferredCapture
            else
            {
                XCTFail(
                    "The transferred fixture windows could not be recaptured")
                return
            }
            XCTAssertTrue(
                transferredWindows.allSatisfy
                {
                    provider.screen(containing: $0.frame, in: screens)?
                        .displayID
                        == destinationScreen.displayID
                })

            let displayUndo = await manager.undoLast(converter: converter)
            switch displayUndo
            {
            case .moved, .bestEffort:
                break
            case .failed(let failure):
                XCTFail(failure.message)
            }
            let restoredCapture = await manager.captureStandardWindows(
                processIdentifier: application.processIdentifier,
                converter: converter
            )
            guard case .success(let restoredWindows) = restoredCapture
            else
            {
                XCTFail("The restored fixture windows could not be recaptured")
                return
            }
            XCTAssertTrue(
                restoredWindows.allSatisfy
                {
                    provider.screen(containing: $0.frame, in: screens)?
                        .displayID
                        == sourceScreen.displayID
                })
        }
    }

    private func launchFixtureApplication() async throws -> NSRunningApplication
    {
        let fixtureURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("WindowFixtureApp.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        return try await withCheckedThrowingContinuation
        {
            continuation in
            NSWorkspace.shared.openApplication(
                at: fixtureURL, configuration: configuration
            )
            {
                application, error in
                if let application
                {
                    continuation.resume(returning: application)
                } else
                {
                    continuation.resume(
                        throwing: error ?? CocoaError(.fileNoSuchFile))
                }
            }
        }
    }

    private static var liveModeEnabled: Bool
    {
        #if REGIONS_RUN_AX_TESTS
            true
        #else
            false
        #endif
    }
}
