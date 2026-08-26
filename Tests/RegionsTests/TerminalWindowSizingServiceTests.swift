import Foundation
import XCTest

@testable import Regions

@MainActor
final class TerminalWindowSizingServiceTests: XCTestCase
{
    func testParsesFlatWindowStateResponse() throws
    {
        let descriptor = NSAppleEventDescriptor.list()
        [101, 80, 48, 202, 120, 64].enumerated().forEach
        {
            offset, value in
            descriptor.insert(
                NSAppleEventDescriptor(int32: Int32(value)),
                at: offset + 1
            )
        }

        let states = try TerminalWindowSizingService.states(from: descriptor)

        XCTAssertEqual(
            states,
            [
                TerminalWindowState(
                    windowIdentifier: 101, columns: 80, rows: 48),
                TerminalWindowState(
                    windowIdentifier: 202, columns: 120, rows: 64),
            ])
    }

    func testRejectsMalformedWindowStateResponse()
    {
        let descriptor = NSAppleEventDescriptor.list()
        descriptor.insert(NSAppleEventDescriptor(int32: 101), at: 1)
        descriptor.insert(NSAppleEventDescriptor(int32: 80), at: 2)

        XCTAssertThrowsError(
            try TerminalWindowSizingService.states(from: descriptor)
        )
    }

    func testManagedStatesPreserveIdentifiersAndUseEightyByFortyEight()
    {
        let states = [
            TerminalWindowState(windowIdentifier: 202, columns: 120, rows: 64),
            TerminalWindowState(windowIdentifier: 101, columns: 40, rows: 24),
        ]

        let managed = TerminalWindowSizingService.managedStates(from: states)

        XCTAssertEqual(
            managed,
            [
                TerminalWindowState(
                    windowIdentifier: 202, columns: 80, rows: 48),
                TerminalWindowState(
                    windowIdentifier: 101, columns: 80, rows: 48),
            ])
    }
}
