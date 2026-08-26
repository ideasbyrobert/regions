import Foundation

@MainActor
protocol TerminalWindowSizing: AnyObject
{
    var authorizationState: TerminalAutomationAuthorizationState { get }

    func requestAuthorization() async -> TerminalAutomationAuthorizationState

    func captureStates() throws -> [TerminalWindowState]

    func apply(_ states: [TerminalWindowState]) throws
}
