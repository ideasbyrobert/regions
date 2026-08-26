import CoreGraphics
import Foundation

enum RegionOrientation: String, Codable, Equatable, Sendable
{
    case landscape
    case portrait

    init(visibleFrame: CGRect)
    {
        self =
            visibleFrame.width >= visibleFrame.height
            ? .landscape
            : .portrait
    }

    var title: String
    {
        switch self
        {
        case .landscape:
            "Landscape"
        case .portrait:
            "Portrait"
        }
    }
}
