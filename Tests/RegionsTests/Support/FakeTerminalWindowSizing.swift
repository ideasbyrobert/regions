import Foundation

@testable import Regions

@MainActor
final class FakeTerminalWindowSizing: TerminalWindowSizing
{
    private(set) var authorizationState: TerminalAutomationAuthorizationState
    private(set) var currentStates: [TerminalWindowState]
    private(set) var appliedStates: [[TerminalWindowState]] = []
    private var nextApplyFailure: TerminalWindowSizingError?

    init(
        authorizationState: TerminalAutomationAuthorizationState,
        currentStates: [TerminalWindowState]
    )
    {
        self.authorizationState = authorizationState
        self.currentStates = currentStates
    }

    func requestAuthorization() async -> TerminalAutomationAuthorizationState
    {
        authorizationState
    }

    func captureStates() throws -> [TerminalWindowState]
    {
        currentStates
    }

    func apply(_ states: [TerminalWindowState]) throws
    {
        appliedStates.append(states)
        currentStates = states
        if let nextApplyFailure
        {
            self.nextApplyFailure = nil
            throw nextApplyFailure
        }
    }

    func failNextApply(with failure: TerminalWindowSizingError)
    {
        nextApplyFailure = failure
    }

    func replaceCurrentStates(_ states: [TerminalWindowState])
    {
        currentStates = states
    }
}
