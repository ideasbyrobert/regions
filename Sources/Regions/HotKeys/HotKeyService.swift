import Carbon
import Foundation
import OSLog

@MainActor
final class HotKeyService
{
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.ideasbyrobert.Regions",
        category: "HotKeys"
    )
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var action: (@MainActor () -> Void)?

    init()
    {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    func register(
        _ shortcut: KeyboardShortcut,
        action: @escaping @MainActor () -> Void
    ) -> HotKeyRegistrationResult
    {
        if let hotKey
        {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        self.action = action
        let identifier = EventHotKeyID(signature: 0x4757_4D47, id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status == noErr
        {
            logger.info("Registered palette hot key")
            return .registered
        }
        if status == eventHotKeyExistsErr
        {
            logger.error(
                "Palette hot key conflicts with an existing registration")
            return .conflict
        }
        logger.error(
            """
            Palette hot key registration failed with status \
            \(status, privacy: .public)
            """
        )
        return .failed(status)
    }

    func performAction()
    {
        action?()
    }
}

private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus
{
    guard let userData
    else
    {
        return OSStatus(eventNotHandledErr)
    }
    let service = Unmanaged<HotKeyService>.fromOpaque(userData)
        .takeUnretainedValue()
    Task
    {
        @MainActor in
        service.performAction()
    }
    return noErr
}
