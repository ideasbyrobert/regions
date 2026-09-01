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
           let decoded = try? JSONDecoder().decode([SavedAppLayout].self, from: data)
        {
            layouts = decoded
        }
        else
        {
            layouts = []
        }
    }

    func layout(bundleIdentifier: String, slot: Int) -> SavedAppLayout?
    {
        layouts.first
        {
            $0.bundleIdentifier == bundleIdentifier && $0.slot == slot
        }
    }

    func slots(bundleIdentifier: String) -> Set<Int>
    {
        Set(layouts.filter
        {
            $0.bundleIdentifier == bundleIdentifier
        }.map(\.slot))
    }

    func save(_ layout: SavedAppLayout)
    {
        layouts.removeAll
        {
            $0.bundleIdentifier == layout.bundleIdentifier && $0.slot == layout.slot
        }
        layouts.append(layout)
        persist()
    }

    func remove(bundleIdentifier: String, slot: Int)
    {
        layouts.removeAll
        {
            $0.bundleIdentifier == bundleIdentifier && $0.slot == slot
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
