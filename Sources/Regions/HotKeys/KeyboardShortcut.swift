import AppKit
import Carbon
import Foundation

struct KeyboardShortcut: Codable, Equatable, Sendable
{
    let keyCode: UInt32
    let modifierFlags: UInt
    let displayKey: String

    static let defaultPaletteShortcut = KeyboardShortcut(
        keyCode: 15,
        modifierFlags: NSEvent.ModifierFlags([.control, .option, .command])
            .rawValue,
        displayKey: "R"
    )

    init(keyCode: UInt32, modifierFlags: UInt, displayKey: String)
    {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.displayKey = displayKey.uppercased()
    }

    init?(event: NSEvent)
    {
        guard event.type == .keyDown,
            let characters = event.charactersIgnoringModifiers,
            !characters.isEmpty
        else
        {
            return nil
        }
        let flags = event.modifierFlags.intersection(
            .deviceIndependentFlagsMask)
        guard !flags.isEmpty
        else
        {
            return nil
        }
        keyCode = UInt32(event.keyCode)
        modifierFlags = flags.rawValue
        displayKey = Self.keyName(event: event)
    }

    var displayName: String
    {
        var value = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        if flags.contains(.control)
        {
            value += "⌃"
        }
        if flags.contains(.option)
        {
            value += "⌥"
        }
        if flags.contains(.shift)
        {
            value += "⇧"
        }
        if flags.contains(.command)
        {
            value += "⌘"
        }
        return value + displayKey
    }

    var carbonModifiers: UInt32
    {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var value: UInt32 = 0
        if flags.contains(.control)
        {
            value |= UInt32(controlKey)
        }
        if flags.contains(.option)
        {
            value |= UInt32(optionKey)
        }
        if flags.contains(.shift)
        {
            value |= UInt32(shiftKey)
        }
        if flags.contains(.command)
        {
            value |= UInt32(cmdKey)
        }
        return value
    }

    private static func keyName(event: NSEvent) -> String
    {
        switch event.keyCode
        {
        case 36:
            return "↩"
        case 48:
            return "⇥"
        case 49:
            return "Space"
        case 51:
            return "⌫"
        case 53:
            return "⎋"
        case 123:
            return "←"
        case 124:
            return "→"
        case 125:
            return "↓"
        case 126:
            return "↑"
        default:
            return event.charactersIgnoringModifiers?.uppercased()
                ?? "Key \(event.keyCode)"
        }
    }
}
