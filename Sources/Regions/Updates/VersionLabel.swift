import Foundation

enum VersionLabel
{
    static func make(displayVersion: String, buildNumber: String) -> String
    {
        let suffix = "(\(buildNumber))"
        if displayVersion == buildNumber || displayVersion.hasSuffix(" \(suffix)")
        {
            return displayVersion
        }
        return "\(displayVersion) \(suffix)"
    }
}
