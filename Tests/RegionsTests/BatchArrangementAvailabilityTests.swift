import XCTest
@testable import Regions

final class BatchArrangementAvailabilityTests: XCTestCase
{
    func testEightWindowsIsAvailable()
    {
        let availability = BatchArrangementAvailability.available(windowCount: 8)

        XCTAssertTrue(availability.isAvailable)
        XCTAssertEqual(availability.detailText, "8 of 8 positions")
    }

    func testMoreThanEightWindowsIsUnavailable()
    {
        let availability = BatchArrangementAvailability.unavailableTooMany(windowCount: 9)

        XCTAssertFalse(availability.isAvailable)
        XCTAssertEqual(availability.detailText, "Unavailable: 9 windows")
    }

    func testAccessibilityFailureIsUnavailable()
    {
        let availability = BatchArrangementAvailability.unavailable(
            .accessibilityPermissionRequired
        )

        XCTAssertFalse(availability.isAvailable)
        XCTAssertEqual(availability.detailText, "Window Control required")
    }
}
