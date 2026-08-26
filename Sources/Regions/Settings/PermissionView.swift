import AppKit
import SwiftUI

struct PermissionView: View
{
    @ObservedObject var authorization: AccessibilityAuthorizationService
    let close: @MainActor () -> Void

    var body: some View
    {
        VStack(alignment: .leading, spacing: 20)
        {
            Image(
                systemName: authorization.isTrusted
                    ? "checkmark.shield.fill" : "rectangle.3.group"
            )
            .font(.system(size: 38, weight: .medium))
            .foregroundStyle(
                authorization.isTrusted ? Color.green : Color.accentColor)

            VStack(alignment: .leading, spacing: 8)
            {
                Text(
                    authorization.isTrusted
                        ? "Ready to Arrange Windows" : "Allow Window Control"
                )
                .font(.title2.weight(.semibold))
                Text(
                    authorization.isTrusted
                        ? "Regions can now move and arrange standard windows."
                        : "Open Privacy & Security. Choose Device Control "
                            + "and Data Access on this macOS version, or "
                            + "Accessibility on earlier versions. Enable "
                            + "Regions.app itself, not a Tests-Runner app, "
                            + "then return. This window closes when macOS "
                            + "confirms access. Regions does not read window "
                            + "titles, documents, general typing, or screen "
                            + "contents."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack
            {
                if authorization.isTrusted
                {
                    Spacer()
                    Button("Done", action: close)
                        .keyboardShortcut(.defaultAction)
                } else
                {
                    Button("Not Now")
                    {
                        close()
                    }
                    Spacer()
                    Button("Open Privacy & Security")
                    {
                        authorization.requestAuthorizationInSystemSettings()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(28)
        .frame(width: 500)
        .onAppear(perform: authorization.refresh)
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification)
        )
        {
            _ in
            authorization.refresh()
        }
        .onChange(of: authorization.isTrusted)
        {
            _, trusted in
            if trusted
            {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4)
                {
                    close()
                }
            }
        }
    }
}
