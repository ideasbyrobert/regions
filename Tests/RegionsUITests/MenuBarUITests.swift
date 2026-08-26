import XCTest

@MainActor
final class MenuBarUITests: XCTestCase
{
    func testSingleWindowMenuExposesOnlyPlacement()
    {
        let application = launchMenu(windowCount: 1)

        XCTAssertTrue(application.menuItems["Place Window"].exists)
        XCTAssertFalse(application.menuItems["Arrange 1 Windows"].exists)
        XCTAssertFalse(application.menuItems["Save App Layout"].exists)
        XCTAssertFalse(application.menuItems["Displays"].exists)
        XCTAssertFalse(application.menuItems["Undo Placement"].exists)
        dismiss(application)
    }

    func testMenuExposesActionsJustifiedByContext()
    {
        let application = launchMenu(
            windowCount: 4,
            arguments: [
                "--ui-testing-multiple-displays",
                "--ui-testing-can-undo",
            ]
        )

        XCTAssertTrue(application.menuItems["Arrange 4 Windows"].exists)
        XCTAssertTrue(application.menuItems["Save App Layout"].exists)
        XCTAssertTrue(application.menuItems["Displays"].exists)
        XCTAssertTrue(application.menuItems["Undo Placement"].exists)
        XCTAssertFalse(application.menuItems["Show Desktop"].exists)
        XCTAssertFalse(application.menuItems["Common Layouts"].exists)
        XCTAssertFalse(application.menuItems["Thirds"].exists)
        dismiss(application)
    }

    func testSavedLayoutRestoresOnlyForMatchingWindowCount()
    {
        let matching = launchMenu(
            windowCount: 3,
            arguments: [
                "--ui-testing-saved-layout",
                "--ui-testing-saved-window-count=3",
            ]
        )

        XCTAssertTrue(matching.menuItems["Restore App Layout"].exists)
        XCTAssertTrue(matching.menuItems["Update App Layout"].exists)
        XCTAssertTrue(matching.menuItems["Forget App Layout"].exists)
        dismiss(matching)

        let mismatched = launchMenu(
            windowCount: 3,
            arguments: [
                "--ui-testing-saved-layout",
                "--ui-testing-saved-window-count=2",
            ]
        )

        XCTAssertFalse(mismatched.menuItems["Restore App Layout"].exists)
        XCTAssertTrue(mismatched.menuItems["Update App Layout"].exists)
        XCTAssertTrue(mismatched.menuItems["Forget App Layout"].exists)
        dismiss(mismatched)
    }

    func testArrangementIsAbsentOutsideSupportedRange()
    {
        for count in [1, 9]
        {
            let application = launchMenu(windowCount: count)

            XCTAssertFalse(
                application.menuItems["Arrange \(count) Windows"].exists
            )
            dismiss(application)
        }
    }

    private func launchMenu(
        windowCount: Int,
        arguments: [String] = []
    ) -> XCUIApplication
    {
        let application = XCUIApplication()
        application.launchArguments =
            [
                "--ui-testing",
                "--ui-testing-window-count=\(windowCount)",
            ] + arguments
        application.launch()

        let statusItem = application.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 3))
        return application
    }

    private func dismiss(_ application: XCUIApplication)
    {
        application.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        application.terminate()
    }
}
