import AppKit
import CoreGraphics
import XCTest

@MainActor
final class LiveAccessibilityUITests: XCTestCase
{
    func testRealAppArrangesAndRestoresFixtureWindow() throws
    {
        try XCTSkipUnless(
            Self.liveModeEnabled,
            "Run with --live-app-accessibility to move fixture windows."
        )
        let manager = XCUIApplication()
        let fixture = XCUIApplication(
            bundleIdentifier: "com.ideasbyrobert.Regions.WindowFixtureApp"
        )
        fixture.launchArguments = ["--ui-testing-open-all-windows"]
        fixture.launch()
        defer
        {
            fixture.terminate()
            manager.terminate()
        }

        let fixtureWindow = fixture.windows.firstMatch
        XCTAssertTrue(
            waitUntil(timeout: 5)
            {
                fixture.windows.count == 4
            })
        XCTAssertTrue(fixtureWindow.exists)
        fixture.activate()
        let originalFrame = fixtureWindow.frame

        manager.launchArguments =
            [
                "--ui-testing-live-target-bundle-identifier="
                    + "com.ideasbyrobert.Regions.WindowFixtureApp",
                "--ui-testing-live-arrange-and-restore",
            ]
        manager.launch()
        if manager.staticTexts["Allow Window Control"].waitForExistence(
            timeout: 1)
        {
            throw XCTSkip(
                "Regions.app does not have Window Control permission.")
        }

        XCTAssertTrue(
            waitUntil(timeout: 5)
            {
                !approximatelyEqual(
                    fixtureWindow.frame, originalFrame, tolerance: 4)
            })
        let arrangedFrame = fixtureWindow.frame
        XCTAssertLessThan(arrangedFrame.width, originalFrame.width)

        XCTAssertTrue(
            waitUntil(timeout: 5)
            {
                approximatelyEqual(
                    fixtureWindow.frame, originalFrame, tolerance: 4)
            })
    }

    func testRealAppTransfersAndRestoresEveryFixtureWindow() throws
    {
        try XCTSkipUnless(
            Self.liveModeEnabled,
            "Run with --live-app-accessibility to move fixture windows."
        )
        try XCTSkipUnless(
            NSScreen.screens.count > 1,
            "Connect a second display to test whole-app display transfer."
        )
        let manager = XCUIApplication()
        let fixture = XCUIApplication(
            bundleIdentifier: "com.ideasbyrobert.Regions.WindowFixtureApp"
        )
        fixture.launchArguments = ["--ui-testing-open-all-windows"]
        fixture.launch()
        defer
        {
            fixture.terminate()
            manager.terminate()
        }
        XCTAssertTrue(
            waitUntil(timeout: 5)
            {
                fixture.windows.count == 4
            })
        fixture.activate()
        let originalFrames = windowFrames(in: fixture)

        manager.launchArguments =
            [
                "--ui-testing-live-target-bundle-identifier="
                    + "com.ideasbyrobert.Regions.WindowFixtureApp",
                "--ui-testing-live-display-transfer-and-restore",
            ]
        manager.launch()
        if manager.staticTexts["Allow Window Control"].waitForExistence(
            timeout: 1)
        {
            throw XCTSkip(
                "Regions.app does not have Window Control permission.")
        }

        XCTAssertTrue(
            waitUntil(timeout: 5)
            {
                let transferredFrames = windowFrames(in: fixture)
                return originalFrames.keys.allSatisfy
                {
                    title in
                    guard let originalFrame = originalFrames[title],
                        let transferredFrame = transferredFrames[title]
                    else
                    {
                        return false
                    }
                    return !approximatelyEqual(
                        transferredFrame,
                        originalFrame,
                        tolerance: 4
                    )
                }
            })
        XCTAssertTrue(
            waitUntil(timeout: 5)
            {
                approximatelyEqual(
                    windowFrames(in: fixture),
                    originalFrames,
                    tolerance: 4
                )
            })
    }

    private func waitUntil(
        timeout: TimeInterval,
        condition: () -> Bool
    ) -> Bool
    {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline
        {
            if condition()
            {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
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

    private func windowFrames(in application: XCUIApplication) -> [String:
        CGRect]
    {
        Dictionary(
            uniqueKeysWithValues: application.windows.allElementsBoundByIndex
                .map
                {
                    ($0.label, $0.frame)
                })
    }

    private func approximatelyEqual(
        _ first: [String: CGRect],
        _ second: [String: CGRect],
        tolerance: CGFloat
    ) -> Bool
    {
        Set(first.keys) == Set(second.keys)
            && first.allSatisfy
            {
                title, frame in
                guard let otherFrame = second[title]
                else
                {
                    return false
                }
                return approximatelyEqual(
                    frame, otherFrame, tolerance: tolerance)
            }
    }

    private static var liveModeEnabled: Bool
    {
        #if REGIONS_RUN_APP_AX_UI_TESTS
            true
        #else
            false
        #endif
    }
}
