import Foundation

struct RegionPlacement: Codable, Equatable, Hashable, Sendable
{
    let orientation: RegionOrientation
    let position: RegionPosition
    let size: RegionSize?
    let horizontalOffset: Double
    let verticalOffset: Double
    let widthDelta: Double
    let heightDelta: Double

    init(
        orientation: RegionOrientation,
        position: RegionPosition,
        size: RegionSize?,
        horizontalOffset: Double = 0,
        verticalOffset: Double = 0,
        widthDelta: Double = 0,
        heightDelta: Double = 0
    )
    {
        self.orientation = orientation
        self.position = position
        self.size = size
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.widthDelta = widthDelta
        self.heightDelta = heightDelta
    }

    var title: String
    {
        let positionTitle = position.title(for: orientation)
        guard let size
        else
        {
            return positionTitle
        }
        return "\(positionTitle) \(size.title)"
    }

    func replacing(position: RegionPosition, size: RegionSize?)
        -> RegionPlacement
    {
        RegionPlacement(
            orientation: orientation,
            position: position,
            size: size,
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset,
            widthDelta: widthDelta,
            heightDelta: heightDelta
        )
    }

    func replacing(size: RegionSize?) -> RegionPlacement
    {
        replacing(position: position, size: size)
    }

    func replacing(orientation: RegionOrientation) -> RegionPlacement
    {
        RegionPlacement(
            orientation: orientation,
            position: position,
            size: size,
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset,
            widthDelta: widthDelta,
            heightDelta: heightDelta
        )
    }

    func offsetBy(horizontal: Double, vertical: Double) -> RegionPlacement
    {
        RegionPlacement(
            orientation: orientation,
            position: position,
            size: size,
            horizontalOffset: horizontalOffset + horizontal,
            verticalOffset: verticalOffset + vertical,
            widthDelta: widthDelta,
            heightDelta: heightDelta
        )
    }

    func resizedBy(width: Double, height: Double) -> RegionPlacement
    {
        RegionPlacement(
            orientation: orientation,
            position: position,
            size: size,
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset,
            widthDelta: widthDelta + width,
            heightDelta: heightDelta + height
        )
    }
}
