import Foundation

struct SavedAppLayout: Codable, Equatable, Sendable
{
    let bundleIdentifier: String
    let windowFrames: [SavedWindowFrame]
}
