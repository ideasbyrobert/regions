import Foundation

@MainActor
final class SavedAppLayoutStore
{
    private let defaults: UserDefaults
    private let storageKey: String
    private var layouts: [SavedAppLayout]

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "savedAppLayouts"
    )
    {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(
                [SavedAppLayout].self, from: data)
        {
            layouts = decoded
        } else
        {
            layouts = []
        }
    }

    func layout(bundleIdentifier: String) -> SavedAppLayout?
    {
        layouts.first
        {
            $0.bundleIdentifier == bundleIdentifier
        }
    }

    func contains(bundleIdentifier: String) -> Bool
    {
        layout(bundleIdentifier: bundleIdentifier) != nil
    }

    func save(_ layout: SavedAppLayout)
    {
        layouts.removeAll
        {
            $0.bundleIdentifier == layout.bundleIdentifier
        }
        layouts.append(layout)
        persist()
    }

    func remove(bundleIdentifier: String)
    {
        layouts.removeAll
        {
            $0.bundleIdentifier == bundleIdentifier
        }
        persist()
    }

    private func persist()
    {
        guard let data = try? JSONEncoder().encode(layouts)
        else
        {
            return
        }
        defaults.set(data, forKey: storageKey)
    }
}
