import SwiftUI

struct ShortcutRecorderView: View
{
    let shortcut: KeyboardShortcut
    let errorMessage: String?
    @StateObject private var recorder: ShortcutRecordingController

    init(
        shortcut: KeyboardShortcut,
        errorMessage: String?,
        onShortcut: @escaping @MainActor (KeyboardShortcut) -> Void
    )
    {
        self.shortcut = shortcut
        self.errorMessage = errorMessage
        _recorder = StateObject(
            wrappedValue: ShortcutRecordingController(onShortcut: onShortcut)
        )
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 6)
        {
            Button
            {
                recorder.toggle()
            }
            label:
            {
                Text(recorder.isRecording ? "Type Shortcut" : shortcut.displayName)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 112)
            }
            .accessibilityLabel("Layout palette shortcut")
            .accessibilityValue(recorder.isRecording ? "Recording" : shortcut.displayName)

            if let errorMessage
            {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            else if recorder.isRecording
            {
                Text("Press Escape to cancel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear
        {
            recorder.stop()
        }
    }
}
