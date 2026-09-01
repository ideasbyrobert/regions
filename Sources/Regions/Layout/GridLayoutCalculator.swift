import CoreGraphics
import Foundation

struct GridLayoutCalculator: LayoutCalculating
{
    func target(
        for command: LayoutCommand,
        on screen: ScreenSnapshot,
        currentWindowFrame: CGRect,
        spacing: CGFloat
    ) -> LayoutTarget
    {
        switch command
        {
        case .grid(let region):
            return gridTarget(
                columns: region.dimension.columnCount,
                rows: region.dimension.rowCount,
                minimumColumn: region.minimumColumn,
                maximumColumn: region.maximumColumn,
                minimumRow: region.minimumRow,
                maximumRow: region.maximumRow,
                screen: screen,
                spacing: spacing
            )
        case .preset(let preset):
            return presetTarget(
                preset,
                screen: screen,
                currentWindowFrame: currentWindowFrame,
                spacing: spacing
            )
        case .move(let position):
            return moveTarget(
                position,
                screen: screen,
                currentWindowFrame: currentWindowFrame,
                spacing: spacing
            )
        case .adjustment(let adjustment, let amount):
            return adjustmentTarget(
                adjustment,
                amount: CGFloat(amount),
                screen: screen,
                currentWindowFrame: currentWindowFrame,
                spacing: spacing
            )
        }
    }

    private func presetTarget(
        _ preset: LayoutPreset,
        screen: ScreenSnapshot,
        currentWindowFrame: CGRect,
        spacing: CGFloat
    ) -> LayoutTarget
    {
        switch preset
        {
        case .fill:
            return gridTarget(
                columns: 1,
                rows: 1,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .almostFill:
            return centeredTarget(
                widthFraction: 0.9,
                heightFraction: 0.9,
                screen: screen,
                spacing: spacing
            )
        case .center:
            return moveTarget(
                .center,
                screen: screen,
                currentWindowFrame: currentWindowFrame,
                spacing: spacing
            )
        case .maximizeWidth:
            let availableFrame = availableFrame(screen: screen, spacing: spacing)
            let boundedFrame = bounded(currentWindowFrame, within: availableFrame)
            return target(
                frame: CGRect(
                    x: availableFrame.minX,
                    y: boundedFrame.minY,
                    width: availableFrame.width,
                    height: boundedFrame.height
                ),
                screen: screen,
                availableFrame: availableFrame,
                explicitEdges: [.left, .right]
            )
        case .maximizeHeight:
            let availableFrame = availableFrame(screen: screen, spacing: spacing)
            let boundedFrame = bounded(currentWindowFrame, within: availableFrame)
            return target(
                frame: CGRect(
                    x: boundedFrame.minX,
                    y: availableFrame.minY,
                    width: boundedFrame.width,
                    height: availableFrame.height
                ),
                screen: screen,
                availableFrame: availableFrame,
                explicitEdges: [.top, .bottom]
            )
        case .leftHalf:
            return gridTarget(
                columns: 2,
                rows: 1,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .rightHalf:
            return gridTarget(
                columns: 2,
                rows: 1,
                minimumColumn: 1,
                maximumColumn: 1,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .topHalf:
            return gridTarget(
                columns: 1,
                rows: 2,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .bottomHalf:
            return gridTarget(
                columns: 1,
                rows: 2,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 1,
                maximumRow: 1,
                screen: screen,
                spacing: spacing
            )
        case .topLeftQuarter:
            return gridTarget(
                columns: 2,
                rows: 2,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .topRightQuarter:
            return gridTarget(
                columns: 2,
                rows: 2,
                minimumColumn: 1,
                maximumColumn: 1,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .bottomLeftQuarter:
            return gridTarget(
                columns: 2,
                rows: 2,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 1,
                maximumRow: 1,
                screen: screen,
                spacing: spacing
            )
        case .bottomRightQuarter:
            return gridTarget(
                columns: 2,
                rows: 2,
                minimumColumn: 1,
                maximumColumn: 1,
                minimumRow: 1,
                maximumRow: 1,
                screen: screen,
                spacing: spacing
            )
        case .leftThird:
            return gridTarget(
                columns: 3,
                rows: 1,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .centerThird:
            return gridTarget(
                columns: 3,
                rows: 1,
                minimumColumn: 1,
                maximumColumn: 1,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .rightThird:
            return gridTarget(
                columns: 3,
                rows: 1,
                minimumColumn: 2,
                maximumColumn: 2,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .leftTwoThirds:
            return gridTarget(
                columns: 3,
                rows: 1,
                minimumColumn: 0,
                maximumColumn: 1,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .rightTwoThirds:
            return gridTarget(
                columns: 3,
                rows: 1,
                minimumColumn: 1,
                maximumColumn: 2,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .topThird:
            return gridTarget(
                columns: 1,
                rows: 3,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .middleThird:
            return gridTarget(
                columns: 1,
                rows: 3,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 1,
                maximumRow: 1,
                screen: screen,
                spacing: spacing
            )
        case .bottomThird:
            return gridTarget(
                columns: 1,
                rows: 3,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 2,
                maximumRow: 2,
                screen: screen,
                spacing: spacing
            )
        case .topTwoThirds:
            return gridTarget(
                columns: 1,
                rows: 3,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 0,
                maximumRow: 1,
                screen: screen,
                spacing: spacing
            )
        case .bottomTwoThirds:
            return gridTarget(
                columns: 1,
                rows: 3,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 1,
                maximumRow: 2,
                screen: screen,
                spacing: spacing
            )
        case .centeredHalf:
            return centeredTarget(
                widthFraction: 0.5,
                heightFraction: 0.5,
                screen: screen,
                spacing: spacing
            )
        case .centeredTwoThirds:
            return centeredTarget(
                widthFraction: 2 / 3,
                heightFraction: 2 / 3,
                screen: screen,
                spacing: spacing
            )
        case .centeredThreeQuarters:
            return centeredTarget(
                widthFraction: 0.75,
                heightFraction: 0.75,
                screen: screen,
                spacing: spacing
            )
        case .leftSixtyPercent:
            return horizontalSplitTarget(
                startFraction: 0.0,
                widthFraction: 0.6,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.left, .top, .bottom]
            )
        case .rightFortyPercent:
            return horizontalSplitTarget(
                startFraction: 0.6,
                widthFraction: 0.4,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.right, .top, .bottom]
            )
        case .leftFortyPercent:
            return horizontalSplitTarget(
                startFraction: 0.0,
                widthFraction: 0.4,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.left, .top, .bottom]
            )
        case .rightSixtyPercent:
            return horizontalSplitTarget(
                startFraction: 0.4,
                widthFraction: 0.6,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.right, .top, .bottom]
            )
        case .leftSeventyPercent:
            return horizontalSplitTarget(
                startFraction: 0.0,
                widthFraction: 0.7,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.left, .top, .bottom]
            )
        case .rightThirtyPercent:
            return horizontalSplitTarget(
                startFraction: 0.7,
                widthFraction: 0.3,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.right, .top, .bottom]
            )
        case .leftThirtyPercent:
            return horizontalSplitTarget(
                startFraction: 0.0,
                widthFraction: 0.3,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.left, .top, .bottom]
            )
        case .rightSeventyPercent:
            return horizontalSplitTarget(
                startFraction: 0.3,
                widthFraction: 0.7,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.right, .top, .bottom]
            )
        case .topSeventyPercent:
            return verticalSplitTarget(
                startFraction: 0.0,
                heightFraction: 0.7,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.left, .right, .top]
            )
        case .bottomThirtyPercent:
            return verticalSplitTarget(
                startFraction: 0.7,
                heightFraction: 0.3,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.left, .right, .bottom]
            )
        case .centerFocusFiftyPercent:
            return horizontalSplitTarget(
                startFraction: 0.25,
                widthFraction: 0.50,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.top, .bottom]
            )
        case .centerFocusSixtyPercent:
            return horizontalSplitTarget(
                startFraction: 0.20,
                widthFraction: 0.60,
                screen: screen,
                spacing: spacing,
                explicitEdges: [.top, .bottom]
            )
        case .centeredSixtyPercent:
            return centeredTarget(
                widthFraction: 0.60,
                heightFraction: 0.60,
                screen: screen,
                spacing: spacing
            )
        case .centeredEightyPercent:
            return centeredTarget(
                widthFraction: 0.80,
                heightFraction: 0.80,
                screen: screen,
                spacing: spacing
            )
        case .firstQuarterColumn:
            return gridTarget(
                columns: 4,
                rows: 1,
                minimumColumn: 0,
                maximumColumn: 0,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .secondQuarterColumn:
            return gridTarget(
                columns: 4,
                rows: 1,
                minimumColumn: 1,
                maximumColumn: 1,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .thirdQuarterColumn:
            return gridTarget(
                columns: 4,
                rows: 1,
                minimumColumn: 2,
                maximumColumn: 2,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        case .fourthQuarterColumn:
            return gridTarget(
                columns: 4,
                rows: 1,
                minimumColumn: 3,
                maximumColumn: 3,
                minimumRow: 0,
                maximumRow: 0,
                screen: screen,
                spacing: spacing
            )
        }
    }

    private func moveTarget(
        _ position: WindowMovePosition,
        screen: ScreenSnapshot,
        currentWindowFrame: CGRect,
        spacing: CGFloat
    ) -> LayoutTarget
    {
        let availableFrame = availableFrame(screen: screen, spacing: spacing)
        var frame = bounded(currentWindowFrame, within: availableFrame)
        var edges: LayoutEdges = []
        switch position
        {
        case .center:
            frame.origin = CGPoint(
                x: availableFrame.midX - frame.width / 2,
                y: availableFrame.midY - frame.height / 2
            )
        case .leftEdge:
            frame.origin.x = availableFrame.minX
            edges.insert(.left)
        case .rightEdge:
            frame.origin.x = availableFrame.maxX - frame.width
            edges.insert(.right)
        case .topEdge:
            frame.origin.y = availableFrame.maxY - frame.height
            edges.insert(.top)
        case .bottomEdge:
            frame.origin.y = availableFrame.minY
            edges.insert(.bottom)
        case .topLeftCorner:
            frame.origin = CGPoint(
                x: availableFrame.minX,
                y: availableFrame.maxY - frame.height
            )
            edges = [.left, .top]
        case .topRightCorner:
            frame.origin = CGPoint(
                x: availableFrame.maxX - frame.width,
                y: availableFrame.maxY - frame.height
            )
            edges = [.right, .top]
        case .bottomLeftCorner:
            frame.origin = CGPoint(x: availableFrame.minX, y: availableFrame.minY)
            edges = [.left, .bottom]
        case .bottomRightCorner:
            frame.origin = CGPoint(
                x: availableFrame.maxX - frame.width,
                y: availableFrame.minY
            )
            edges = [.right, .bottom]
        }
        return target(
            frame: frame,
            screen: screen,
            availableFrame: availableFrame,
            explicitEdges: edges
        )
    }

    private func adjustmentTarget(
        _ adjustment: WindowAdjustment,
        amount: CGFloat,
        screen: ScreenSnapshot,
        currentWindowFrame: CGRect,
        spacing: CGFloat
    ) -> LayoutTarget
    {
        let availableFrame = availableFrame(screen: screen, spacing: spacing)
        var frame = bounded(currentWindowFrame, within: availableFrame)
        let resolvedAmount = min(max(amount, 1), max(availableFrame.width, availableFrame.height))
        switch adjustment
        {
        case .moveLeft:
            frame.origin.x -= resolvedAmount
        case .moveRight:
            frame.origin.x += resolvedAmount
        case .moveUp:
            frame.origin.y += resolvedAmount
        case .moveDown:
            frame.origin.y -= resolvedAmount
        case .grow:
            frame = resized(
                frame,
                widthDelta: resolvedAmount * 2,
                heightDelta: resolvedAmount * 2
            )
        case .shrink:
            frame = resized(
                frame,
                widthDelta: -resolvedAmount * 2,
                heightDelta: -resolvedAmount * 2
            )
        case .widen:
            frame = resized(frame, widthDelta: resolvedAmount * 2, heightDelta: 0)
        case .narrow:
            frame = resized(frame, widthDelta: -resolvedAmount * 2, heightDelta: 0)
        case .taller:
            frame = resized(frame, widthDelta: 0, heightDelta: resolvedAmount * 2)
        case .shorter:
            frame = resized(frame, widthDelta: 0, heightDelta: -resolvedAmount * 2)
        }
        frame = bounded(frame, within: availableFrame)
        return target(
            frame: frame,
            screen: screen,
            availableFrame: availableFrame,
            explicitEdges: edges(for: frame, within: availableFrame)
        )
    }

    private func horizontalSplitTarget(
        startFraction: CGFloat,
        widthFraction: CGFloat,
        screen: ScreenSnapshot,
        spacing: CGFloat,
        explicitEdges: LayoutEdges
    ) -> LayoutTarget
    {
        let availableFrame = availableFrame(screen: screen, spacing: spacing)
        let usableWidth = availableFrame.width
        let x = availableFrame.minX + usableWidth * startFraction
        let width = usableWidth * widthFraction
        let frame = CGRect(
            x: x,
            y: availableFrame.minY,
            width: width,
            height: availableFrame.height
        )
        return target(
            frame: frame,
            screen: screen,
            availableFrame: availableFrame,
            explicitEdges: explicitEdges
        )
    }

    private func verticalSplitTarget(
        startFraction: CGFloat,
        heightFraction: CGFloat,
        screen: ScreenSnapshot,
        spacing: CGFloat,
        explicitEdges: LayoutEdges
    ) -> LayoutTarget
    {
        let availableFrame = availableFrame(screen: screen, spacing: spacing)
        let usableHeight = availableFrame.height
        let height = usableHeight * heightFraction
        let y = availableFrame.maxY - (usableHeight * startFraction) - height
        let frame = CGRect(
            x: availableFrame.minX,
            y: y,
            width: availableFrame.width,
            height: height
        )
        return target(
            frame: frame,
            screen: screen,
            availableFrame: availableFrame,
            explicitEdges: explicitEdges
        )
    }

    private func centeredTarget(
        widthFraction: CGFloat,
        heightFraction: CGFloat,
        screen: ScreenSnapshot,
        spacing: CGFloat
    ) -> LayoutTarget
    {
        let availableFrame = availableFrame(screen: screen, spacing: spacing)
        let frame = CGRect(
            x: availableFrame.midX - availableFrame.width * widthFraction / 2,
            y: availableFrame.midY - availableFrame.height * heightFraction / 2,
            width: availableFrame.width * widthFraction,
            height: availableFrame.height * heightFraction
        )
        return target(
            frame: frame,
            screen: screen,
            availableFrame: availableFrame,
            explicitEdges: []
        )
    }

    private func gridTarget(
        columns: Int,
        rows: Int,
        minimumColumn: Int,
        maximumColumn: Int,
        minimumRow: Int,
        maximumRow: Int,
        screen: ScreenSnapshot,
        spacing: CGFloat
    ) -> LayoutTarget
    {
        let gap = resolvedSpacing(spacing, columns: columns, rows: rows, screen: screen)
        let scale = max(screen.backingScaleFactor, 1)
        let visibleFrame = screen.visibleFrame
        let cellWidth = (visibleFrame.width - gap * CGFloat(columns + 1)) / CGFloat(columns)
        let cellHeight = (visibleFrame.height - gap * CGFloat(rows + 1)) / CGFloat(rows)

        let minimumX = visibleFrame.minX + gap + CGFloat(minimumColumn) * (cellWidth + gap)
        let maximumX = visibleFrame.minX + gap + CGFloat(maximumColumn + 1) * cellWidth + CGFloat(maximumColumn) * gap
        let maximumY = visibleFrame.maxY - gap - CGFloat(minimumRow) * (cellHeight + gap)
        let minimumY = visibleFrame.maxY - gap - CGFloat(maximumRow + 1) * cellHeight - CGFloat(maximumRow) * gap

        let alignedMinimumX = align(minimumX, scale: scale)
        let alignedMaximumX = align(maximumX, scale: scale)
        let alignedMinimumY = align(minimumY, scale: scale)
        let alignedMaximumY = align(maximumY, scale: scale)
        let frame = CGRect(
            x: alignedMinimumX,
            y: alignedMinimumY,
            width: max(0, alignedMaximumX - alignedMinimumX),
            height: max(0, alignedMaximumY - alignedMinimumY)
        )

        var edges: LayoutEdges = []
        if minimumColumn == 0
        {
            edges.insert(.left)
        }
        if maximumColumn == columns - 1
        {
            edges.insert(.right)
        }
        if minimumRow == 0
        {
            edges.insert(.top)
        }
        if maximumRow == rows - 1
        {
            edges.insert(.bottom)
        }

        return LayoutTarget(
            frame: frame,
            visibleFrame: visibleFrame,
            edges: edges,
            backingScaleFactor: screen.backingScaleFactor
        )
    }

    private func availableFrame(screen: ScreenSnapshot, spacing: CGFloat) -> CGRect
    {
        let gap = resolvedSpacing(spacing, columns: 1, rows: 1, screen: screen)
        return screen.visibleFrame.insetBy(dx: gap, dy: gap)
    }

    private func bounded(_ frame: CGRect, within availableFrame: CGRect) -> CGRect
    {
        let width = min(max(frame.width, 1), availableFrame.width)
        let height = min(max(frame.height, 1), availableFrame.height)
        let minimumX = availableFrame.minX
        let maximumX = availableFrame.maxX - width
        let minimumY = availableFrame.minY
        let maximumY = availableFrame.maxY - height
        return CGRect(
            x: min(max(frame.minX, minimumX), maximumX),
            y: min(max(frame.minY, minimumY), maximumY),
            width: width,
            height: height
        )
    }

    private func resized(
        _ frame: CGRect,
        widthDelta: CGFloat,
        heightDelta: CGFloat
    ) -> CGRect
    {
        let width = max(160, frame.width + widthDelta)
        let height = max(120, frame.height + heightDelta)
        return CGRect(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func edges(for frame: CGRect, within availableFrame: CGRect) -> LayoutEdges
    {
        let tolerance: CGFloat = 0.5
        var edges: LayoutEdges = []
        if abs(frame.minX - availableFrame.minX) <= tolerance
        {
            edges.insert(.left)
        }
        if abs(frame.maxX - availableFrame.maxX) <= tolerance
        {
            edges.insert(.right)
        }
        if abs(frame.maxY - availableFrame.maxY) <= tolerance
        {
            edges.insert(.top)
        }
        if abs(frame.minY - availableFrame.minY) <= tolerance
        {
            edges.insert(.bottom)
        }
        return edges
    }

    private func target(
        frame: CGRect,
        screen: ScreenSnapshot,
        availableFrame: CGRect,
        explicitEdges: LayoutEdges
    ) -> LayoutTarget
    {
        let boundedFrame = bounded(frame, within: availableFrame)
        return LayoutTarget(
            frame: aligned(boundedFrame, scale: screen.backingScaleFactor),
            visibleFrame: screen.visibleFrame,
            edges: explicitEdges,
            backingScaleFactor: screen.backingScaleFactor
        )
    }

    private func resolvedSpacing(
        _ requestedSpacing: CGFloat,
        columns: Int,
        rows: Int,
        screen: ScreenSnapshot
    ) -> CGFloat
    {
        let scale = max(screen.backingScaleFactor, 1)
        let minimumCellDimension = 1 / scale
        let maximumHorizontal = max(
            0,
            (screen.visibleFrame.width - CGFloat(columns) * minimumCellDimension) / CGFloat(columns + 1)
        )
        let maximumVertical = max(
            0,
            (screen.visibleFrame.height - CGFloat(rows) * minimumCellDimension) / CGFloat(rows + 1)
        )
        return min(min(max(requestedSpacing, 0), maximumHorizontal), maximumVertical)
    }

    private func aligned(_ frame: CGRect, scale: CGFloat) -> CGRect
    {
        let minimumX = align(frame.minX, scale: scale)
        let maximumX = align(frame.maxX, scale: scale)
        let minimumY = align(frame.minY, scale: scale)
        let maximumY = align(frame.maxY, scale: scale)
        return CGRect(
            x: minimumX,
            y: minimumY,
            width: max(0, maximumX - minimumX),
            height: max(0, maximumY - minimumY)
        )
    }

    private func align(_ value: CGFloat, scale: CGFloat) -> CGFloat
    {
        (value * max(scale, 1)).rounded() / max(scale, 1)
    }
}
