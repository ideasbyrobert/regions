import CoreGraphics
import Foundation

struct BalancedFourByTwoLayout: Sendable
{
    static let capacity =
        GridDimension.fourByTwo.columnCount
        * GridDimension.fourByTwo.rowCount

    func rowCounts(forWindowCount windowCount: Int) -> [Int]?
    {
        switch windowCount
        {
        case 1...4:
            return [windowCount]
        case 5:
            return [3, 2]
        case 6:
            return [3, 3]
        case 7:
            return [4, 3]
        case 8:
            return [4, 4]
        default:
            return nil
        }
    }

    func placements(
        for windowSizes: [CGSize],
        in visibleFrame: CGRect,
        spacing: CGFloat,
        backingScaleFactor: CGFloat
    ) -> BalancedFourByTwoLayoutResult
    {
        guard let rowCounts = rowCounts(forWindowCount: windowSizes.count)
        else
        {
            return .unsupportedWindowCount(windowSizes.count)
        }
        let gap = max(0, spacing)
        let rows = rows(from: windowSizes, counts: rowCounts)
        guard
            rows.allSatisfy(
                {
                    row in
                    row.allSatisfy
                    {
                        size in
                        size.width.isFinite
                            && size.height.isFinite
                            && size.width > 0
                            && size.height > 0
                    }
                })
        else
        {
            return .doesNotFit(
                required: CGSize(
                    width: CGFloat.infinity, height: CGFloat.infinity),
                available: visibleFrame.size
            )
        }
        let rowWidths = rows.map
        {
            row in
            row.reduce(0)
            {
                $0 + $1.width
            } + gap * CGFloat(max(0, row.count - 1))
        }
        let rowHeights = rows.map
        {
            row in
            row.map(\.height).max() ?? 0
        }
        let requiredSize = CGSize(
            width: (rowWidths.max() ?? 0) + gap * 2,
            height: rowHeights.reduce(0, +)
                + gap * CGFloat(max(0, rows.count - 1))
                + gap * 2
        )
        guard requiredSize.width <= visibleFrame.width,
            requiredSize.height <= visibleFrame.height
        else
        {
            return .doesNotFit(
                required: requiredSize, available: visibleFrame.size)
        }

        let contentHeight = requiredSize.height - gap * 2
        var rowTop = visibleFrame.midY + contentHeight / 2
        var frames: [CGRect] = []
        let scale = max(1, backingScaleFactor)
        for rowIndex in rows.indices
        {
            let row = rows[rowIndex]
            let rowWidth = rowWidths[rowIndex]
            let rowHeight = rowHeights[rowIndex]
            let rowBottom = rowTop - rowHeight
            var windowLeft = visibleFrame.midX - rowWidth / 2
            for size in row
            {
                let origin = CGPoint(
                    x: align(windowLeft, scale: scale),
                    y: align(
                        rowBottom + (rowHeight - size.height) / 2,
                        scale: scale
                    )
                )
                frames.append(CGRect(origin: origin, size: size))
                windowLeft += size.width + gap
            }
            rowTop = rowBottom - gap
        }
        return .placements(frames)
    }

    private func rows(from sizes: [CGSize], counts: [Int]) -> [[CGSize]]
    {
        var startIndex = 0
        return counts.map
        {
            count in
            defer
            {
                startIndex += count
            }
            return Array(sizes[startIndex..<(startIndex + count)])
        }
    }

    private func align(_ value: CGFloat, scale: CGFloat) -> CGFloat
    {
        (value * scale).rounded() / scale
    }
}
