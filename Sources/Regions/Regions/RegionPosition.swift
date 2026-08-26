import Foundation

enum RegionPosition: String, CaseIterable, Codable, Equatable, Sendable
{
    case leading
    case center
    case trailing
    case fill

    func title(for orientation: RegionOrientation) -> String
    {
        switch (self, orientation)
        {
        case (.leading, .landscape):
            "Left"
        case (.leading, .portrait):
            "Top"
        case (.center, _):
            "Center"
        case (.trailing, .landscape):
            "Right"
        case (.trailing, .portrait):
            "Bottom"
        case (.fill, _):
            "Fill"
        }
    }

    func systemImage(for orientation: RegionOrientation) -> String
    {
        switch (self, orientation)
        {
        case (.leading, .landscape):
            "rectangle.lefthalf.inset.filled"
        case (.leading, .portrait):
            "rectangle.tophalf.inset.filled"
        case (.center, _):
            "rectangle.center.inset.filled"
        case (.trailing, .landscape):
            "rectangle.righthalf.inset.filled"
        case (.trailing, .portrait):
            "rectangle.bottomhalf.inset.filled"
        case (.fill, _):
            "rectangle.inset.filled"
        }
    }
}
