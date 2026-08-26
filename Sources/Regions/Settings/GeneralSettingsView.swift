import SwiftUI

struct GeneralSettingsView: View
{
    @ObservedObject var controller: AppController
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var authorization: AccessibilityAuthorizationService
    @ObservedObject var launchAtLogin: LaunchAtLoginService
    @State private var launchAtLoginEnabled: Bool

    init(controller: AppController)
    {
        self.controller = controller
        preferences = controller.preferences
        authorization = controller.authorization
        launchAtLogin = controller.launchAtLogin
        _launchAtLoginEnabled = State(
            initialValue: controller.launchAtLogin.isEnabled
        )
    }

    var body: some View
    {
        Form
        {
            Section("Placement")
            {
                PointSliderRow(
                    "Window spacing",
                    value: $preferences.spacing,
                    in: 0...32,
                    step: 1
                )

                Toggle(
                    "Show placement preview",
                    isOn: $preferences.showsPreview
                )

                PointSliderRow(
                    "Keyboard refinement",
                    value: $preferences.adjustmentStep,
                    in: 8...128,
                    step: 8
                )
            }

            Section("Keyboard")
            {
                LabeledContent("Place window")
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
                                authorization.isTrusted
                                    ? Color.secondary
                                    : Color.red
                            )
                        Button(
                            authorization.isTrusted ? "Open Settings" : "Allow"
                        )
                        {
                            if authorization.isTrusted
                            {
                                authorization.openSystemSettings()
                            } else
                            {
                                controller.showPermissionWindow()
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
        }
        .formStyle(.grouped)
        .padding(20)
        .task
        {
            authorization.refresh()
            launchAtLoginEnabled = launchAtLogin.isEnabled
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
}
