import XCTest

@MainActor
final class PaletteUITests: XCTestCase
{
    func testPalettePresentsThreeByThreeGridAndPresets()
    {
        let application = launchPalette()

        XCTAssertTrue(application.staticTexts["Arrange Window"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.buttons["palette.cell.0.0"].exists)
        XCTAssertTrue(application.buttons["palette.cell.2.2"].exists)
        XCTAssertFalse(application.buttons["palette.cell.3.3"].exists)
        XCTAssertTrue(application.buttons["palette.preset.fill"].exists)
        XCTAssertTrue(application.buttons["palette.preset.bottomRightQuarter"].exists)
    }

    func testKeyboardSwitchesToFourByFourAndCancels()
    {
        let application = launchPalette()
        XCTAssertTrue(application.staticTexts["Arrange Window"].waitForExistence(timeout: 3))

        application.typeKey("4", modifierFlags: [])

        XCTAssertTrue(application.buttons["palette.cell.3.3"].waitForExistence(timeout: 2))
        application.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertFalse(application.staticTexts["Arrange Window"].waitForExistence(timeout: 1))
    }

    func testKeyboardSwitchesToFourByTwoAndCancels()
    {
        let application = launchPalette()
        XCTAssertTrue(application.staticTexts["Arrange Window"].waitForExistence(timeout: 3))

        application.typeKey("2", modifierFlags: [])

        XCTAssertTrue(application.buttons["palette.cell.1.3"].waitForExistence(timeout: 2))
        XCTAssertFalse(application.buttons["palette.cell.2.0"].exists)
        application.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertFalse(application.staticTexts["Arrange Window"].waitForExistence(timeout: 1))
    }

    func testGridCellAppliesAndClosesPalette()
    {
        let application = launchPalette()
        let cell = application.buttons["palette.cell.2.2"]
        XCTAssertTrue(cell.waitForExistence(timeout: 3))

        cell.click()

        XCTAssertFalse(application.staticTexts["Arrange Window"].waitForExistence(timeout: 2))
    }

    func testPresetAppliesAndClosesPalette()
    {
        let application = launchPalette()
        let fill = application.buttons["palette.preset.fill"]
        XCTAssertTrue(fill.waitForExistence(timeout: 3))

        fill.click()

        XCTAssertFalse(application.staticTexts["Arrange Window"].waitForExistence(timeout: 2))
    }

    func testPaletteShowsExtendedWindowCommandMenus()
    {
        let application = launchPalette()

        XCTAssertTrue(application.menuButtons["Thirds"].waitForExistence(timeout: 3))
        XCTAssertTrue(application.menuButtons["Center"].exists)
        XCTAssertTrue(application.menuButtons["Move"].exists)
        XCTAssertTrue(application.menuButtons["Resize"].exists)
    }

    func testFillKeyboardShortcutAppliesAndClosesPalette()
    {
        let application = launchPalette()
        XCTAssertTrue(application.staticTexts["Arrange Window"].waitForExistence(timeout: 3))

        application.typeKey("f", modifierFlags: [])

        XCTAssertFalse(application.staticTexts["Arrange Window"].waitForExistence(timeout: 2))
    }

    private func launchPalette() -> XCUIApplication
    {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing", "--ui-testing-palette"]
        application.launch()
        application.activate()
        return application
    }
}
