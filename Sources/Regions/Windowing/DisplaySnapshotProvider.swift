import AppKit
import CoreGraphics
import Foundation

@MainActor
struct DisplaySnapshotProvider
{
    func snapshots() -> [ScreenSnapshot]
    {
        NSScreen.screens.compactMap
        {
            screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else
            {
                return nil
            }
            return ScreenSnapshot(
                displayID: CGDirectDisplayID(number.uint32Value),
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                backingScaleFactor: screen.backingScaleFactor
            )
        }
    }

    func primaryDisplayMaximumY() -> CGFloat
    {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    func screen(containing windowFrame: CGRect, in screens: [ScreenSnapshot]) -> ScreenSnapshot?
    {
        guard !screens.isEmpty
        else
        {
            return nil
        }

        let intersecting = screens.max
        {
            left, right in
            intersectionArea(windowFrame, left.frame) < intersectionArea(windowFrame, right.frame)
        }
        if let intersecting, intersectionArea(windowFrame, intersecting.frame) > 0
        {
            return intersecting
        }

        return screens.min
        {
            left, right in
            squaredDistance(from: windowFrame, to: left.frame) < squaredDistance(from: windowFrame, to: right.frame)
        }
    }

    func screen(containing point: CGPoint, in screens: [ScreenSnapshot]) -> ScreenSnapshot?
    {
        screens.first
        {
            $0.frame.contains(point)
        }
    }

    func adjacent(
        to current: ScreenSnapshot,
        direction: DisplayDirection,
        in screens: [ScreenSnapshot]
    ) -> ScreenSnapshot?
    {
        let orderedScreens = screens.sorted
        {
            left, right in
            if left.frame.minX == right.frame.minX
            {
                return left.frame.maxY > right.frame.maxY
            }
            return left.frame.minX < right.frame.minX
        }
        guard orderedScreens.count > 1,
              let currentIndex = orderedScreens.firstIndex(where:
              {
                  $0.displayID == current.displayID
              })
        else
        {
            return nil
        }

        switch direction
        {
        case .previous:
            let index = currentIndex == 0 ? orderedScreens.count - 1 : currentIndex - 1
            return orderedScreens[index]
        case .next:
            let index = currentIndex == orderedScreens.count - 1 ? 0 : currentIndex + 1
            return orderedScreens[index]
        }
    }

    private func intersectionArea(_ first: CGRect, _ second: CGRect) -> CGFloat
    {
        let intersection = first.intersection(second)
        guard !intersection.isNull
        else
        {
            return 0
        }
        return intersection.width * intersection.height
    }

    private func squaredDistance(from first: CGRect, to second: CGRect) -> CGFloat
    {
        let deltaX = first.midX - second.midX
        let deltaY = first.midY - second.midY
        return deltaX * deltaX + deltaY * deltaY
    }
}
