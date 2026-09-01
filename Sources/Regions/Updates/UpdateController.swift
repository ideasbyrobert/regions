import AppKit
import Combine
import Foundation
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject, @preconcurrency SPUStandardUserDriverDelegate
{
    @Published private(set) var canCheck = false

    private let versionDisplay = SpreadVersionDisplay()
    private var controller: SPUStandardUpdaterController?
    private var observation: NSKeyValueObservation?

    override init()
    {
        super.init()
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        else
        {
            return
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )

        observation = controller?.updater.observe(\.canCheckForUpdates, options: [.initial, .new])
        {
            [weak self] updater, _ in
            DispatchQueue.main.async
            {
                self?.canCheck = updater.canCheckForUpdates
            }
        }
    }

    func checkForUpdates()
    {
        controller?.checkForUpdates(nil)
    }

    func standardUserDriverRequestsVersionDisplayer() -> (any SUVersionDisplay)?
    {
        versionDisplay
    }

    var automaticallyChecks: Bool
    {
        get
        {
            controller?.updater.automaticallyChecksForUpdates ?? false
        }
        set
        {
            controller?.updater.automaticallyChecksForUpdates = newValue
        }
    }

    var automaticallyDownloads: Bool
    {
        get
        {
            controller?.updater.automaticallyDownloadsUpdates ?? false
        }
        set
        {
            controller?.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    var lastCheck: Date?
    {
        controller?.updater.lastUpdateCheckDate
    }

    var feedURL: String
    {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? "not configured"
    }

    var isConfigured: Bool
    {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
            && Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil
    }
}
