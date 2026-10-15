import Foundation
import XCTest
@testable import Regions

@MainActor
final class AccessibilityAuthorizationServiceTests: XCTestCase
{
    func testRequestAuthorizationRegistersEntryOpensSettingsAndTerminatesWhenUntrusted() async
    {
        var didPrompt = false
        var openedURL: URL?
        var didTerminate = false
        let service = AccessibilityAuthorizationService(
            checkTrust:
            {
                false
            },
            promptForTrust:
            {
                didPrompt = true
                return false
            },
            openSettingsURL:
            {
                url in
                openedURL = url
                return true
            },
            terminateApplication:
            {
                didTerminate = true
            },
            exitDelay: 0.01
        )

        service.requestAuthorizationInSystemSettings()

        XCTAssertTrue(didPrompt)
        XCTAssertEqual(
            openedURL?.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        )
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(didTerminate)
    }

    func testRequestAuthorizationFallsBackToLegacySettingsURL() async
    {
        var attemptedURLs: [String] = []
        var didTerminate = false
        let service = AccessibilityAuthorizationService(
            checkTrust:
            {
                false
            },
            promptForTrust:
            {
                false
            },
            openSettingsURL:
            {
                url in
                attemptedURLs.append(url.absoluteString)
                return url.absoluteString.contains("com.apple.preference.security")
            },
            terminateApplication:
            {
                didTerminate = true
            },
            exitDelay: 0
        )

        service.requestAuthorizationInSystemSettings()

        XCTAssertEqual(
            attemptedURLs,
            [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            ]
        )
        XCTAssertTrue(didTerminate)
    }

    func testHandleWindowClosedTerminatesWhenUntrusted()
    {
        var didTerminate = false
        let service = AccessibilityAuthorizationService(
            checkTrust:
            {
                false
            },
            promptForTrust:
            {
                false
            },
            openSettingsURL:
            {
                _ in
                true
            },
            terminateApplication:
            {
                didTerminate = true
            },
            exitDelay: 0
        )

        service.handleWindowClosed()

        XCTAssertTrue(didTerminate)
    }

    func testHandleWindowClosedDoesNotTerminateWhenTrusted()
    {
        var didTerminate = false
        let service = AccessibilityAuthorizationService(
            checkTrust:
            {
                true
            },
            promptForTrust:
            {
                true
            },
            openSettingsURL:
            {
                _ in
                true
            },
            terminateApplication:
            {
                didTerminate = true
            },
            exitDelay: 0
        )

        service.handleWindowClosed()

        XCTAssertFalse(didTerminate)
    }

    func testStartMonitoringDetectsPermissionAddition() async
    {
        nonisolated(unsafe) var trusted = false
        let service = AccessibilityAuthorizationService(
            checkTrust:
            {
                trusted
            },
            promptForTrust:
            {
                trusted
            },
            openSettingsURL:
            {
                _ in
                true
            },
            terminateApplication:
            {
            },
            exitDelay: 0
        )

        XCTAssertFalse(service.isTrusted)
        service.startMonitoring()
        trusted = true
        try? await Task.sleep(for: .milliseconds(750))
        XCTAssertTrue(service.isTrusted)
        service.stopPolling()
    }
}
