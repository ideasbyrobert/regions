import Foundation
import XCTest

@testable import Regions

@MainActor
final class SavedAppLayoutStoreTests: XCTestCase
{
    func testSaveOverwritesOneLayoutPerApplication()
    {
        let suiteName = "SavedAppLayoutStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storageKey = "layouts"
        let store = SavedAppLayoutStore(
            defaults: defaults,
            storageKey: storageKey
        )
        let first = layout(bundleIdentifier: "example.app", count: 1)
        let replacement = layout(bundleIdentifier: "example.app", count: 2)

        store.save(first)
        store.save(replacement)
        let reloaded = SavedAppLayoutStore(
            defaults: defaults,
            storageKey: storageKey
        )

        XCTAssertEqual(
            reloaded.layout(bundleIdentifier: "example.app"),
            replacement
        )
        XCTAssertTrue(reloaded.contains(bundleIdentifier: "example.app"))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRemoveAffectsOnlyMatchingApplication()
    {
        let suiteName = "SavedAppLayoutStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SavedAppLayoutStore(
            defaults: defaults,
            storageKey: "layouts"
        )
        store.save(layout(bundleIdentifier: "first.app", count: 1))
        store.save(layout(bundleIdentifier: "second.app", count: 1))

        store.remove(bundleIdentifier: "first.app")

        XCTAssertNil(store.layout(bundleIdentifier: "first.app"))
        XCTAssertNotNil(store.layout(bundleIdentifier: "second.app"))
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func layout(
        bundleIdentifier: String,
        count: Int
    ) -> SavedAppLayout
    {
        let frame = SavedWindowFrame(
            frame: CGRect(x: 0, y: 0, width: 500, height: 400),
            within: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )
        return SavedAppLayout(
            bundleIdentifier: bundleIdentifier,
            windowFrames: Array(repeating: frame, count: count)
        )
    }
}
