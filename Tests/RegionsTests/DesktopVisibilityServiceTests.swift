import AppKit
import XCTest
@testable import Regions

@MainActor
final class DesktopVisibilityServiceTests: XCTestCase
{
    func testShowAndRestoreAffectOnlyEligibleApplications()
    {
        let frontmost = FakeDesktopApplication(
            processIdentifier: 10,
            bundleIdentifier: "com.example.Frontmost"
        )
        let second = FakeDesktopApplication(
            processIdentifier: 11,
            bundleIdentifier: "com.example.Second"
        )
        let finder = FakeDesktopApplication(
            processIdentifier: 12,
            bundleIdentifier: "com.apple.finder"
        )
        let accessory = FakeDesktopApplication(
            processIdentifier: 13,
            bundleIdentifier: "com.example.Accessory",
            activationPolicy: .accessory
        )
        let alreadyHidden = FakeDesktopApplication(
            processIdentifier: 14,
            bundleIdentifier: "com.example.Hidden",
            isHidden: true
        )
        let workspace = FakeDesktopWorkspace(
            runningApplications: [frontmost, second, finder, accessory, alreadyHidden],
            frontmostApplication: frontmost
        )
        let service = DesktopVisibilityService(
            workspace: workspace,
            currentProcessIdentifier: 99
        )

        let showResult = service.showDesktop()

        XCTAssertEqual(showResult, .shown(hiddenApplicationCount: 2))
        XCTAssertTrue(service.isDesktopShown)
        XCTAssertEqual(frontmost.hideCount, 1)
        XCTAssertEqual(second.hideCount, 1)
        XCTAssertEqual(finder.hideCount, 0)
        XCTAssertEqual(accessory.hideCount, 0)
        XCTAssertEqual(alreadyHidden.hideCount, 0)

        let restoreResult = service.restoreDesktop()

        XCTAssertEqual(restoreResult, .restored(applicationCount: 2))
        XCTAssertFalse(service.isDesktopShown)
        XCTAssertEqual(frontmost.unhideCount, 1)
        XCTAssertEqual(second.unhideCount, 1)
        XCTAssertEqual(frontmost.activationCount, 1)
    }

    func testHideFailureRestoresApplicationsAlreadyHiddenByCommand()
    {
        let first = FakeDesktopApplication(
            processIdentifier: 10,
            bundleIdentifier: "com.example.First"
        )
        let failing = FakeDesktopApplication(
            processIdentifier: 11,
            bundleIdentifier: "com.example.Failing"
        )
        failing.hideSucceeds = false
        let workspace = FakeDesktopWorkspace(
            runningApplications: [first, failing],
            frontmostApplication: first
        )
        let service = DesktopVisibilityService(
            workspace: workspace,
            currentProcessIdentifier: 99
        )

        let result = service.showDesktop()

        guard case .failed = result
        else
        {
            XCTFail("Expected a transactional hide failure")
            return
        }
        XCTAssertFalse(service.isDesktopShown)
        XCTAssertFalse(first.isHidden)
        XCTAssertEqual(first.unhideCount, 1)
    }

    func testRestoreFailureRetainsRetryableDesktopState()
    {
        let application = FakeDesktopApplication(
            processIdentifier: 10,
            bundleIdentifier: "com.example.Application"
        )
        let workspace = FakeDesktopWorkspace(
            runningApplications: [application],
            frontmostApplication: application
        )
        let service = DesktopVisibilityService(
            workspace: workspace,
            currentProcessIdentifier: 99
        )
        _ = service.showDesktop()
        application.unhideSucceeds = false

        let failedRestore = service.restoreDesktop()

        guard case .failed = failedRestore
        else
        {
            XCTFail("Expected restore failure")
            return
        }
        XCTAssertTrue(service.isDesktopShown)
        application.unhideSucceeds = true

        let retry = service.restoreDesktop()

        XCTAssertEqual(retry, .restored(applicationCount: 1))
        XCTAssertFalse(service.isDesktopShown)
    }

    func testHideRollbackFailureRetainsRetryableDesktopState()
    {
        let first = FakeDesktopApplication(
            processIdentifier: 10,
            bundleIdentifier: "com.example.First"
        )
        first.unhideSucceeds = false
        let failing = FakeDesktopApplication(
            processIdentifier: 11,
            bundleIdentifier: "com.example.Failing"
        )
        failing.hideSucceeds = false
        let workspace = FakeDesktopWorkspace(
            runningApplications: [first, failing],
            frontmostApplication: first
        )
        let service = DesktopVisibilityService(
            workspace: workspace,
            currentProcessIdentifier: 99
        )

        let result = service.showDesktop()

        guard case .failed = result
        else
        {
            XCTFail("Expected a hide and rollback failure")
            return
        }
        XCTAssertTrue(service.isDesktopShown)
        XCTAssertTrue(first.isHidden)
        first.unhideSucceeds = true

        let retry = service.restoreDesktop()

        XCTAssertEqual(retry, .restored(applicationCount: 1))
        XCTAssertFalse(service.isDesktopShown)
        XCTAssertEqual(first.activationCount, 1)
    }
}
