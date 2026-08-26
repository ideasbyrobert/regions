import XCTest

@MainActor
final class PaletteUITests: XCTestCase
{
    func testLandscapePaletteExposesOnlyUsefulPositionsAndSizes()
    {
        let application = launchPalette()

        XCTAssertTrue(
            application.staticTexts["Place Window"].waitForExistence(
                timeout: 3
            )
        )
        XCTAssertTrue(application.buttons["palette.position.leading"].exists)
        XCTAssertTrue(application.buttons["palette.position.center"].exists)
        XCTAssertTrue(application.buttons["palette.position.trailing"].exists)
        XCTAssertTrue(application.buttons["palette.position.fill"].exists)
        XCTAssertTrue(application.buttons["palette.size.50"].exists)
        XCTAssertTrue(application.buttons["palette.size.70"].exists)
        XCTAssertTrue(application.buttons["palette.size.90"].exists)
        XCTAssertFalse(application.buttons["palette.size.25"].exists)
        XCTAssertFalse(
            application.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "palette.cell.")
            ).firstMatch.exists)
    }

    func testSelectionPreviewsUntilPlaceCommits()
    {
        let application = launchPalette()
        let right = application.buttons["palette.position.trailing"]
        XCTAssertTrue(right.waitForExistence(timeout: 3))

        right.click()

        XCTAssertTrue(application.staticTexts["Place Window"].exists)
        XCTAssertTrue(application.buttons["palette.size.25"].exists)

        application.buttons["palette.place"].click()

        XCTAssertFalse(
            application.staticTexts["Place Window"].waitForExistence(
                timeout: 2
            )
        )
    }

    func testEscapeCancelsWithoutPlacement()
    {
        let application = launchPalette()
        XCTAssertTrue(
            application.staticTexts["Place Window"].waitForExistence(
                timeout: 3
            )
        )

        application.typeKey("r", modifierFlags: [])
        application.typeKey("7", modifierFlags: [])
        application.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])

        XCTAssertFalse(
            application.staticTexts["Place Window"].waitForExistence(
                timeout: 2
            )
        )
    }

    func testKeyboardCommitsAndRefinesWithoutMenus()
    {
        let application = launchPalette()
        XCTAssertTrue(
            application.staticTexts["Place Window"].waitForExistence(
                timeout: 3
            )
        )

        application.typeKey("r", modifierFlags: [])
        application.typeKey("7", modifierFlags: [])
        application.typeKey("+", modifierFlags: [])
        application.typeKey(
            XCUIKeyboardKey.rightArrow.rawValue,
            modifierFlags: .option
        )
        application.typeKey(
            XCUIKeyboardKey.return.rawValue,
            modifierFlags: []
        )

        XCTAssertFalse(
            application.staticTexts["Place Window"].waitForExistence(
                timeout: 2
            )
        )
    }

    func testPortraitPaletteAdaptsPositionLanguage()
    {
        let application = launchPalette(arguments: ["--ui-testing-portrait"])

        let top = application.buttons["palette.position.leading"]
        XCTAssertTrue(top.waitForExistence(timeout: 3))
        XCTAssertEqual(top.label, "Top")
        XCTAssertEqual(
            application.buttons["palette.position.center"].label,
            "Center"
        )
        XCTAssertEqual(
            application.buttons["palette.position.trailing"].label,
            "Bottom"
        )
    }

    func testNonResizableWindowExposesPositionOnly()
    {
        let application = launchPalette(
            arguments: ["--ui-testing-nonresizable"]
        )

        XCTAssertTrue(
            application.buttons["palette.position.leading"].waitForExistence(
                timeout: 3
            )
        )
        XCTAssertTrue(application.buttons["palette.position.center"].exists)
        XCTAssertTrue(application.buttons["palette.position.trailing"].exists)
        XCTAssertFalse(application.buttons["palette.position.fill"].exists)
        XCTAssertFalse(application.staticTexts["25%"].exists)
        XCTAssertFalse(application.staticTexts["50%"].exists)
        XCTAssertFalse(application.staticTexts["70%"].exists)
        XCTAssertFalse(application.staticTexts["90%"].exists)
        XCTAssertTrue(
            application.staticTexts[
                "This window keeps its current size."
            ].exists
        )
    }

    private func launchPalette(arguments: [String] = []) -> XCUIApplication
    {
        let application = XCUIApplication()
        application.launchArguments =
            [
                "--ui-testing",
                "--ui-testing-palette",
            ] + arguments
        application.launch()
        application.activate()
        return application
    }
}
