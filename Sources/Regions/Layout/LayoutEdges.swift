import Foundation

struct LayoutEdges: OptionSet, Hashable, Sendable
{
    let rawValue: UInt8

    static let left = LayoutEdges(rawValue: 1 << 0)
    static let right = LayoutEdges(rawValue: 1 << 1)
    static let top = LayoutEdges(rawValue: 1 << 2)
    static let bottom = LayoutEdges(rawValue: 1 << 3)
    static let all: LayoutEdges = [.left, .right, .top, .bottom]
}
