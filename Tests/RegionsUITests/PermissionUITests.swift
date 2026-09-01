import XCTest

@MainActor
final class PermissionUITests: XCTestCase
{
    func testPermissionSurfaceExplainsTheWindowControlBoundary()
    {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing", "--ui-testing-permission"]
        application.launch()

        let ready = application.staticTexts["Ready to Arrange Windows"]
        let required = application.staticTexts["Allow Window Control"]
        XCTAssertTrue(
            ready.waitForExistence(timeout: 3) || required.waitForExistence(timeout: 3)
        )
        if required.exists
        {
            XCTAssertTrue(application.buttons["Open Privacy & Security"].exists)
            XCTAssertTrue(
                application.staticTexts.matching(
                    NSPredicate(
                        format: "label CONTAINS %@",
                        "Device Control and Data Access"
                    )
                ).firstMatch.exists
            )
            XCTAssertTrue(
                application.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS %@", "Regions.app itself")
                ).firstMatch.exists
            )
            XCTAssertTrue(
                application.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS %@", "Tests-Runner")
                ).firstMatch.exists
            )
            XCTAssertFalse(application.buttons["Open Accessibility Settings"].exists)
            XCTAssertFalse(application.buttons["Allow Accessibility"].exists)
            XCTAssertFalse(application.buttons["Open System Settings"].exists)
        }
    }
}
