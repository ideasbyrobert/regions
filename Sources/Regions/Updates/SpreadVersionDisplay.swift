import AppKit
import Foundation
import Sparkle

final class SpreadVersionDisplay: NSObject, SUVersionDisplay
{
    func formatUpdateVersion(
        fromUpdate update: SUAppcastItem,
        andBundleDisplayVersion bundleDisplayVersion: AutoreleasingUnsafeMutablePointer<NSString>,
        withBundleVersion bundleVersion: String
    ) -> String
    {
        bundleDisplayVersion.pointee = VersionLabel.make(
            displayVersion: bundleDisplayVersion.pointee as String,
            buildNumber: bundleVersion
        ) as NSString
        return VersionLabel.make(
            displayVersion: update.displayVersionString,
            buildNumber: update.versionString
        )
    }

    func formatBundleDisplayVersion(
        _ bundleDisplayVersion: String,
        withBundleVersion bundleVersion: String,
        matchingUpdate _: SUAppcastItem?
    ) -> String
    {
        VersionLabel.make(displayVersion: bundleDisplayVersion, buildNumber: bundleVersion)
    }
}
