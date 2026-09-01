import Foundation

struct SavedAppLayout: Codable, Equatable, Sendable
{
    let bundleIdentifier: String
    let slot: Int
    let windowFrames: [SavedWindowFrame]
}
