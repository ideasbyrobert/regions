import Foundation

extension LayoutCommand
{
    func adapted(to screen: ScreenSnapshot) -> LayoutCommand
    {
        switch self
        {
        case .region(let placement):
            return .region(
                placement.replacing(
                    orientation: RegionOrientation(
                        visibleFrame: screen.visibleFrame
                    )
                ))
        default:
            return self
        }
    }
}
