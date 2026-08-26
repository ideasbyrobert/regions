import AppKit
import Combine
import Foundation

@MainActor
final class ShortcutRecordingController: ObservableObject
{
    @Published private(set) var isRecording = false

    private var monitor: Any?
    private let onShortcut: @MainActor (KeyboardShortcut) -> Void

    init(onShortcut: @escaping @MainActor (KeyboardShortcut) -> Void)
    {
        self.onShortcut = onShortcut
    }

    func toggle()
    {
        isRecording ? stop() : start()
    }

    func stop()
    {
        if let monitor
        {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }

    private func start()
    {
        stop()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown)
        {
            [weak self] event in
            guard let self
            else
            {
                return event
            }
            if event.keyCode == 53
            {
                self.stop()
                return nil
            }
            guard let shortcut = KeyboardShortcut(event: event)
            else
            {
                NSSound.beep()
                return nil
            }
            self.stop()
            self.onShortcut(shortcut)
            return nil
        }
    }
}
