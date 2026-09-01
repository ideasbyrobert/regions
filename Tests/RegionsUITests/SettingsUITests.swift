import XCTest

@MainActor
final class SettingsUITests: XCTestCase
{
    func testSettingsExposeTerminalAutomationWithoutPromptingAtLaunch()
    {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"]
        application.launch()

        application.activate()
        application.typeKey(",", modifierFlags: .command)

        XCTAssertTrue(
            application.staticTexts["Terminal Automation"].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(application.sheets.firstMatch.exists)
        RunLoop.current.run(until: Date().addingTimeInterval(6))
        XCTAssertTrue(application.exists)
        XCTAssertTrue(application.staticTexts["Launch at login"].exists)
        application.terminate()
    }
}
