import Foundation

struct GridRegion: Hashable, Codable, Sendable
{
    let dimension: GridDimension
    let minimumRow: Int
    let maximumRow: Int
    let minimumColumn: Int
    let maximumColumn: Int

    init(dimension: GridDimension, anchor: GridCell, extent: GridCell)
    {
        let rowLimit = dimension.rowCount - 1
        let columnLimit = dimension.columnCount - 1
        let anchorRow = min(max(anchor.row, 0), rowLimit)
        let anchorColumn = min(max(anchor.column, 0), columnLimit)
        let extentRow = min(max(extent.row, 0), rowLimit)
        let extentColumn = min(max(extent.column, 0), columnLimit)

        self.dimension = dimension
        minimumRow = min(anchorRow, extentRow)
        maximumRow = max(anchorRow, extentRow)
        minimumColumn = min(anchorColumn, extentColumn)
        maximumColumn = max(anchorColumn, extentColumn)
    }

    var accessibilityLabel: String
    {
        let rowDescription = minimumRow == maximumRow
            ? "row \(minimumRow + 1)"
            : "rows \(minimumRow + 1) through \(maximumRow + 1)"
        let columnDescription = minimumColumn == maximumColumn
            ? "column \(minimumColumn + 1)"
            : "columns \(minimumColumn + 1) through \(maximumColumn + 1)"
        return "\(dimension.title), \(rowDescription), \(columnDescription)"
    }

    func contains(_ cell: GridCell) -> Bool
    {
        minimumRow...maximumRow ~= cell.row
            && minimumColumn...maximumColumn ~= cell.column
    }
}
