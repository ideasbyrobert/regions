import Combine
import Foundation

@MainActor
final class AppPreferences: ObservableObject
{
    static let shared: AppPreferences =
        {
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
                let defaults = UserDefaults(
                    suiteName: "com.ideasbyrobert.Regions.UITests"
                )
            {
                return AppPreferences(defaults: defaults)
            }
            return AppPreferences()
        }()

    @Published var spacing: Double
    {
        didSet
        {
            defaults.set(min(max(spacing, 0), 32), forKey: spacingKey)
        }
    }

    @Published var showsPreview: Bool
    {
        didSet
        {
            defaults.set(showsPreview, forKey: showsPreviewKey)
        }
    }

    @Published var adjustmentStep: Double
    {
        didSet
        {
            defaults.set(
                min(max(adjustmentStep, 8), 128),
                forKey: adjustmentStepKey
            )
        }
    }

    @Published private(set) var paletteShortcut: KeyboardShortcut

    private let defaults: UserDefaults
    private let spacingKey = "spacing"
    private let showsPreviewKey = "showsPreview"
    private let adjustmentStepKey = "adjustmentStep"
    private let paletteShortcutKey = "paletteShortcut"

    private init(defaults: UserDefaults = .standard)
    {
        self.defaults = defaults
        defaults.register(defaults: [
            spacingKey: 8.0,
            showsPreviewKey: true,
            adjustmentStepKey: 32.0,
        ])
        spacing = defaults.double(forKey: spacingKey)
        showsPreview = defaults.bool(forKey: showsPreviewKey)
        adjustmentStep = defaults.double(forKey: adjustmentStepKey)

        if let data = defaults.data(forKey: paletteShortcutKey),
            let shortcut = try? JSONDecoder().decode(
                KeyboardShortcut.self,
                from: data
            )
        {
            paletteShortcut = shortcut
        } else
        {
            paletteShortcut = .defaultPaletteShortcut
        }
    }

    func setPaletteShortcut(_ shortcut: KeyboardShortcut)
    {
        paletteShortcut = shortcut
        if let data = try? JSONEncoder().encode(shortcut)
        {
            defaults.set(data, forKey: paletteShortcutKey)
        }
    }
}
