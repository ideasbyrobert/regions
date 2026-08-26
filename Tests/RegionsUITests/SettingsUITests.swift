import XCTest

@MainActor
final class SettingsUITests: XCTestCase
{
    func testSettingsExposeOnlyPersistentPlacementControls()
    {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"]
        application.launch()

        application.activate()
        application.typeKey(",", modifierFlags: .command)

        XCTAssertTrue(
            application.sliders["Window spacing"].waitForExistence(
                timeout: 3
            )
        )
        XCTAssertTrue(application.sliders["Keyboard refinement"].exists)
        XCTAssertTrue(application.staticTexts["Place window"].exists)
        XCTAssertTrue(application.staticTexts["Window Control"].exists)
        XCTAssertTrue(
            application.staticTexts["Launch at login"].exists
        )
        XCTAssertTrue(
            application.staticTexts["Show placement preview"].exists
        )
        XCTAssertEqual(application.switches.count, 2)
        XCTAssertFalse(application.staticTexts["Terminal Automation"].exists)
        XCTAssertFalse(application.staticTexts["Updates"].exists)
        XCTAssertFalse(application.staticTexts["Grid"].exists)
        XCTAssertFalse(application.staticTexts["Edge snapping"].exists)
        XCTAssertFalse(application.sheets.firstMatch.exists)
        application.terminate()
    }
}
