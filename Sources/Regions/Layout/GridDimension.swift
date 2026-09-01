import Foundation

enum GridDimension: Int, CaseIterable, Codable, Sendable
{
    case twoByTwo = 22
    case threeByTwo = 32
    case twoByThree = 23
    case three = 3
    case fourByTwo = 42
    case four = 4

    var columnCount: Int
    {
        switch self
        {
        case .twoByTwo, .twoByThree:
            return 2
        case .threeByTwo, .three:
            return 3
        case .fourByTwo, .four:
            return 4
        }
    }

    var rowCount: Int
    {
        switch self
        {
        case .twoByTwo, .threeByTwo, .fourByTwo:
            return 2
        case .twoByThree, .three:
            return 3
        case .four:
            return 4
        }
    }

    var title: String
    {
        "\(columnCount) × \(rowCount)"
    }
}
