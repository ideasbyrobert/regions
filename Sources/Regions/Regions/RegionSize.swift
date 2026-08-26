import Foundation

enum RegionSize: Int, CaseIterable, Codable, Equatable, Sendable
{
    case quarter = 25
    case half = 50
    case seventy = 70
    case ninety = 90

    var title: String
    {
        "\(rawValue)%"
    }

    var fraction: Double
    {
        Double(rawValue) / 100
    }
}
