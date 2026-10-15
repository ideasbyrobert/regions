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
            HStack(spacing: 14)
            {
                Image(systemName: authorization.isTrusted ? "checkmark.shield.fill" : "rectangle.3.group")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(authorization.isTrusted ? Color.green : Color.accentColor)

                VStack(alignment: .leading, spacing: 4)
                {
                    Text(authorization.isTrusted ? "Ready to Arrange Windows" : "Allow Window Control")
                        .font(.title2.weight(.semibold))
                    Text(
                        authorization.isTrusted
                            ? "Regions can now move and arrange standard windows."
                            : "Regions needs Accessibility permission in System Settings to move and resize windows."
                    )
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !authorization.isTrusted
            {
                VStack(alignment: .leading, spacing: 10)
                {
                    stepRow(
                        number: "1",
                        text: "Click Open Privacy & Security to add Regions to Accessibility."
                    )
                    stepRow(
                        number: "2",
                        text: "Turn on Regions in System Settings → Privacy & Security → Accessibility."
                    )
                    stepRow(
                        number: "3",
                        text: "Reopen Regions. The app will exit now so the permission is in place when you start it again."
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                Text("Regions does not read window titles, documents, general typing, or screen contents.")
                    .font(.footnote)
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
                }
                else
                {
                    Button("Quit")
                    {
                        close()
                        authorization.exitIfUntrusted()
                    }
                    Spacer()
                    Button("Open Privacy & Security")
                    {
                        authorization.requestAuthorizationInSystemSettings()
                        close()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(28)
        .frame(width: 500)
        .onAppear
        {
            authorization.startMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
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
        .onDisappear
        {
            authorization.stopPolling()
        }
    }

    private func stepRow(number: String, text: String) -> some View
    {
        HStack(alignment: .firstTextBaseline, spacing: 10)
        {
            Text("\(number).")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, alignment: .trailing)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
