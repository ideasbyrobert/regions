import Foundation
import XCTest
@testable import Regions

@MainActor
final class SavedAppLayoutStoreTests: XCTestCase
{
    func testSaveReplaceAndReload()
    {
        let suiteName = "SavedAppLayoutStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storageKey = "layouts"
        let store = SavedAppLayoutStore(defaults: defaults, storageKey: storageKey)
        let first = SavedAppLayout(
            bundleIdentifier: "example.app",
            slot: 1,
            windowFrames:
            [
                SavedWindowFrame(
                    frame: CGRect(x: 0, y: 0, width: 500, height: 400),
                    within: CGRect(x: 0, y: 0, width: 1000, height: 800)
                )
            ]
        )
        let replacement = SavedAppLayout(
            bundleIdentifier: "example.app",
            slot: 1,
            windowFrames: first.windowFrames + first.windowFrames
        )

        store.save(first)
        store.save(replacement)
        let reloaded = SavedAppLayoutStore(defaults: defaults, storageKey: storageKey)

        XCTAssertEqual(reloaded.layout(bundleIdentifier: "example.app", slot: 1), replacement)
        XCTAssertEqual(reloaded.slots(bundleIdentifier: "example.app"), [1])
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRemoveAffectsOnlyMatchingAppAndSlot()
    {
        let suiteName = "SavedAppLayoutStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SavedAppLayoutStore(defaults: defaults, storageKey: "layouts")
        let frame = SavedWindowFrame(
            frame: CGRect(x: 0, y: 0, width: 500, height: 400),
            within: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )
        store.save(SavedAppLayout(
            bundleIdentifier: "first.app",
            slot: 1,
            windowFrames: [frame]
        ))
        store.save(SavedAppLayout(
            bundleIdentifier: "second.app",
            slot: 1,
            windowFrames: [frame]
        ))

        store.remove(bundleIdentifier: "first.app", slot: 1)

        XCTAssertNil(store.layout(bundleIdentifier: "first.app", slot: 1))
        XCTAssertNotNil(store.layout(bundleIdentifier: "second.app", slot: 1))
        defaults.removePersistentDomain(forName: suiteName)
    }
}
