import SwiftUI

struct GeneralSettingsView: View
{
    @ObservedObject var controller: AppController
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var authorization: AccessibilityAuthorizationService
    @ObservedObject var launchAtLogin: LaunchAtLoginService
    @ObservedObject var terminalWindowSizing: TerminalWindowSizingService
    @ObservedObject var updates: UpdateController
    @State private var launchAtLoginEnabled: Bool

    init(controller: AppController)
    {
        self.controller = controller
        preferences = controller.preferences
        authorization = controller.authorization
        launchAtLogin = controller.launchAtLogin
        terminalWindowSizing = controller.terminalWindowSizing
        updates = controller.updates
        _launchAtLoginEnabled = State(initialValue: controller.launchAtLogin.isEnabled)
    }

    var body: some View
    {
        Form
        {
            Section("Layouts")
            {
                Picker("Default grid", selection: $preferences.gridDimension)
                {
                    ForEach(GridDimension.allCases, id: \.self)
                    {
                        dimension in
                        Text(dimension.title)
                            .tag(dimension)
                    }
                }
                .pickerStyle(.segmented)

                PointSliderRow(
                    "Window spacing",
                    value: $preferences.spacing,
                    in: 0...32,
                    step: 1
                )

                Toggle("Show placement preview", isOn: $preferences.showsPreview)

                Toggle("Snap windows at screen edges", isOn: $preferences.edgeSnappingEnabled)

                PointSliderRow(
                    "Move and resize step",
                    value: $preferences.adjustmentStep,
                    in: 8...128,
                    step: 8
                )
            }

            Section("Keyboard")
            {
                LabeledContent("Open layout palette")
                {
                    ShortcutRecorderView(
                        shortcut: preferences.paletteShortcut,
                        errorMessage: controller.shortcutErrorMessage,
                        onShortcut: controller.updatePaletteShortcut
                    )
                }
            }

            Section("System")
            {
                Toggle("Launch at login", isOn: $launchAtLoginEnabled)

                LabeledContent("Window Control")
                {
                    HStack
                    {
                        Text(authorization.isTrusted ? "Allowed" : "Required")
                            .foregroundStyle(
                                authorization.isTrusted ? Color.secondary : Color.red
                            )
                        Button(authorization.isTrusted ? "Open Settings" : "Allow")
                        {
                            if authorization.isTrusted
                            {
                                authorization.openSystemSettings()
                            }
                            else
                            {
                                controller.showPermissionWindow()
                            }
                        }
                    }
                }

                LabeledContent("Terminal Automation")
                {
                    HStack
                    {
                        Text(terminalWindowSizing.authorizationState.title)
                            .foregroundStyle(terminalAutomationStatusColor)
                        Button(terminalAutomationButtonTitle)
                        {
                            if terminalWindowSizing.authorizationState == .allowed
                                || terminalWindowSizing.authorizationState == .denied
                            {
                                terminalWindowSizing.openSystemSettings()
                            }
                            else
                            {
                                Task
                                {
                                    _ = await terminalWindowSizing.requestAuthorization()
                                }
                            }
                        }
                    }
                }

                if let errorMessage = launchAtLogin.errorMessage
                {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Updates")
            {
                LabeledContent("Software Update")
                {
                    Button("Check for Updates…")
                    {
                        controller.updates.checkForUpdates()
                    }
                    .disabled(!updates.canCheck)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .task
        {
            launchAtLoginEnabled = launchAtLogin.isEnabled
            await terminalWindowSizing.refreshAuthorization()
        }
        .onChange(of: launchAtLoginEnabled)
        {
            _, enabled in
            guard enabled != launchAtLogin.isEnabled
            else
            {
                return
            }
            launchAtLogin.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLogin.isEnabled
        }
    }

    private var terminalAutomationButtonTitle: String
    {
        switch terminalWindowSizing.authorizationState
        {
        case .allowed, .denied:
            return "Open Settings"
        case .notRequested, .requiresConsent:
            return "Request"
        case .unavailable:
            return "Retry"
        }
    }

    private var terminalAutomationStatusColor: Color
    {
        switch terminalWindowSizing.authorizationState
        {
        case .allowed, .notRequested:
            return .secondary
        case .requiresConsent, .unavailable:
            return .orange
        case .denied:
            return .red
        }
    }
}
