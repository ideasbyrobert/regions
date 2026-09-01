import Combine
import CoreGraphics
import Foundation

@MainActor
final class PaletteModel: ObservableObject
{
    @Published private(set) var dimension: GridDimension
    @Published private(set) var selectedRegion: GridRegion?

    private var anchor = GridCell(row: 0, column: 0)
    private var extent = GridCell(row: 0, column: 0)
    private var isDragging = false
    private let adjustmentAmount: Double
    private let onDimensionChange: @MainActor (GridDimension) -> Void
    private let onPreview: @MainActor (LayoutCommand?) -> Void
    private let onCommit: @MainActor (LayoutCommand) -> Void
    private let onCancel: @MainActor () -> Void

    init(
        dimension: GridDimension,
        adjustmentAmount: Double = 40,
        onDimensionChange: @escaping @MainActor (GridDimension) -> Void =
        {
            _ in
        },
        onPreview: @escaping @MainActor (LayoutCommand?) -> Void,
        onCommit: @escaping @MainActor (LayoutCommand) -> Void,
        onCancel: @escaping @MainActor () -> Void
    )
    {
        self.dimension = dimension
        self.adjustmentAmount = adjustmentAmount
        self.onDimensionChange = onDimensionChange
        self.onPreview = onPreview
        self.onCommit = onCommit
        self.onCancel = onCancel
        selectedRegion = GridRegion(dimension: dimension, anchor: anchor, extent: extent)
    }

    func setDimension(_ dimension: GridDimension)
    {
        self.dimension = dimension
        onDimensionChange(dimension)
        anchor = GridCell(row: 0, column: 0)
        extent = anchor
        updateSelection()
    }

    func select(_ cell: GridCell)
    {
        anchor = cell
        extent = cell
        updateSelection()
        commitSelection()
    }

    func beginDrag(at location: CGPoint, in size: CGSize)
    {
        guard !isDragging
        else
        {
            return
        }
        guard let cell = cell(at: location, in: size)
        else
        {
            return
        }
        isDragging = true
        anchor = cell
        extent = cell
        updateSelection()
    }

    func updateDrag(at location: CGPoint, in size: CGSize)
    {
        guard isDragging,
              let cell = cell(at: location, in: size)
        else
        {
            return
        }
        extent = cell
        updateSelection()
    }

    func endDrag(at location: CGPoint, in size: CGSize)
    {
        guard isDragging
        else
        {
            return
        }
        isDragging = false
        guard let cell = cell(at: location, in: size)
        else
        {
            cancel()
            return
        }
        extent = cell
        updateSelection()
        commitSelection()
    }

    func moveSelection(rowDelta: Int, columnDelta: Int, extending: Bool)
    {
        let movedCell = GridCell(
            row: min(max(extent.row + rowDelta, 0), dimension.rowCount - 1),
            column: min(max(extent.column + columnDelta, 0), dimension.columnCount - 1)
        )
        extent = movedCell
        if !extending
        {
            anchor = movedCell
        }
        updateSelection()
    }

    func commitSelection()
    {
        guard let selectedRegion
        else
        {
            return
        }
        onCommit(.grid(selectedRegion))
    }

    func commit(_ preset: LayoutPreset)
    {
        commit(.preset(preset))
    }

    func commit(_ command: LayoutCommand)
    {
        onCommit(command)
    }

    func commit(_ adjustment: WindowAdjustment)
    {
        commit(.adjustment(adjustment, amount: adjustmentAmount))
    }

    func cancel()
    {
        selectedRegion = nil
        onPreview(nil)
        onCancel()
    }

    private func updateSelection()
    {
        let region = GridRegion(dimension: dimension, anchor: anchor, extent: extent)
        selectedRegion = region
        onPreview(.grid(region))
    }

    private func cell(at location: CGPoint, in size: CGSize) -> GridCell?
    {
        guard size.width > 0,
              size.height > 0,
              location.x >= 0,
              location.y >= 0,
              location.x < size.width,
              location.y < size.height
        else
        {
            return nil
        }
        let column = min(
            Int(location.x / size.width * CGFloat(dimension.columnCount)),
            dimension.columnCount - 1
        )
        let row = min(
            Int(location.y / size.height * CGFloat(dimension.rowCount)),
            dimension.rowCount - 1
        )
        return GridCell(row: row, column: column)
    }
}
