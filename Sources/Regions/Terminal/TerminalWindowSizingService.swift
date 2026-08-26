import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class TerminalWindowSizingService: ObservableObject, TerminalWindowSizing
{
    nonisolated static let bundleIdentifier = "com.apple.Terminal"
    nonisolated static let managedColumns = 80
    nonisolated static let managedRows = 48

    @Published private(set) var authorizationState =
        TerminalAutomationAuthorizationState.notRequested

    func requestAuthorization() async -> TerminalAutomationAuthorizationState
    {
        let state = await Task.detached
        {
            Self.determinePermission(askUserIfNeeded: true)
        }
        .value
        authorizationState = state
        return state
    }

    func refreshAuthorization() async
    {
        let state = await Task.detached
        {
            Self.determinePermission(askUserIfNeeded: false)
        }
        .value
        authorizationState = state
    }

    func openSystemSettings()
    {
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:"
                    + "com.apple.preference.security?Privacy_Automation"
            )
        else
        {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func captureStates() throws -> [TerminalWindowState]
    {
        let source = """
            tell application id "com.apple.Terminal"
                set stateValues to {}
                repeat with terminalWindow in windows
                    set end of stateValues to id of terminalWindow
                    set end of stateValues to number of columns ¬
                        of selected tab of terminalWindow
                    set end of stateValues to number of rows ¬
                        of selected tab of terminalWindow
                end repeat
                return stateValues
            end tell
            """
        return try Self.states(from: execute(source))
    }

    func apply(_ states: [TerminalWindowState]) throws
    {
        guard !states.isEmpty,
            states.allSatisfy(
                {
                    $0.windowIdentifier > 0 && $0.columns > 0 && $0.rows > 0
                })
        else
        {
            throw TerminalWindowSizingError.invalidState
        }
        let commands = states.map
        {
            state in
            """
                set number of columns of selected tab ¬
                    of window id \(state.windowIdentifier) ¬
                    to \(state.columns)
                set number of rows of selected tab ¬
                    of window id \(state.windowIdentifier) ¬
                    to \(state.rows)
            """
        }
        .joined(separator: "\n")
        let source = """
            tell application id "com.apple.Terminal"
            \(commands)
            end tell
            """
        _ = try execute(source)
        let captured = try captureStates()
        guard Self.normalized(captured) == Self.normalized(states)
        else
        {
            throw TerminalWindowSizingError.verificationFailed
        }
    }

    static func managedStates(from states: [TerminalWindowState])
        -> [TerminalWindowState]
    {
        states.map
        {
            TerminalWindowState(
                windowIdentifier: $0.windowIdentifier,
                columns: managedColumns,
                rows: managedRows
            )
        }
    }

    static func normalized(_ states: [TerminalWindowState])
        -> [TerminalWindowState]
    {
        states.sorted
        {
            $0.windowIdentifier < $1.windowIdentifier
        }
    }

    static func states(from descriptor: NSAppleEventDescriptor) throws
        -> [TerminalWindowState]
    {
        let itemCount = descriptor.numberOfItems
        guard itemCount.isMultiple(of: 3)
        else
        {
            throw TerminalWindowSizingError.malformedResponse
        }
        var states: [TerminalWindowState] = []
        var index = 1
        while index <= itemCount
        {
            guard let identifier = descriptor.atIndex(index),
                let columns = descriptor.atIndex(index + 1),
                let rows = descriptor.atIndex(index + 2)
            else
            {
                throw TerminalWindowSizingError.malformedResponse
            }
            let state = TerminalWindowState(
                windowIdentifier: identifier.int32Value,
                columns: Int(columns.int32Value),
                rows: Int(rows.int32Value)
            )
            guard state.windowIdentifier > 0,
                state.columns > 0,
                state.rows > 0
            else
            {
                throw TerminalWindowSizingError.invalidState
            }
            states.append(state)
            index += 3
        }
        return states
    }

    private func execute(_ source: String) throws -> NSAppleEventDescriptor
    {
        guard authorizationState.permitsAutomation
        else
        {
            throw TerminalWindowSizingError.automation(authorizationState)
        }
        guard let script = NSAppleScript(source: source)
        else
        {
            throw TerminalWindowSizingError.malformedResponse
        }
        var errorInformation: NSDictionary?
        let executionResult: NSAppleEventDescriptor? =
            script.executeAndReturnError(
                &errorInformation
            )
        guard let result = executionResult
        else
        {
            let code =
                (errorInformation?[NSAppleScript.errorNumber] as? NSNumber)?
                .intValue ?? 0
            let message =
                errorInformation?[NSAppleScript.errorMessage] as? String
                ?? "Unknown error"
            if code == Int(errAEEventNotPermitted)
            {
                authorizationState = .denied
                throw TerminalWindowSizingError.automation(.denied)
            }
            throw TerminalWindowSizingError.scriptFailure(
                code: code, message: message)
        }
        return result
    }

    nonisolated private static func determinePermission(
        askUserIfNeeded: Bool
    ) -> TerminalAutomationAuthorizationState
    {
        let identifierData = Data(bundleIdentifier.utf8)
        var target = AEAddressDesc()
        let creationStatus = identifierData.withUnsafeBytes
        {
            bytes in
            AECreateDesc(
                DescType(typeApplicationBundleID),
                bytes.baseAddress,
                identifierData.count,
                &target
            )
        }
        guard creationStatus == noErr
        else
        {
            return .unavailable(Int32(creationStatus))
        }
        defer
        {
            AEDisposeDesc(&target)
        }
        let status = AEDeterminePermissionToAutomateTarget(
            &target,
            AEEventClass(typeWildCard),
            AEEventID(typeWildCard),
            askUserIfNeeded
        )
        switch status
        {
        case noErr:
            return .allowed
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .requiresConsent
        case OSStatus(errAEEventNotPermitted):
            return .denied
        default:
            return .unavailable(status)
        }
    }
}
