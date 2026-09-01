import SwiftUI

struct GridCellView: View
{
    let cell: GridCell
    let dimension: GridDimension
    let isSelected: Bool
    let action: @MainActor () -> Void

    var body: some View
    {
        Button(action: action)
        {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                .overlay
                {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.secondary.opacity(0.32),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityIdentifier("palette.cell.\(cell.row).\(cell.column)")
        .accessibilityLabel(
            "\(dimension.title), row \(cell.row + 1), column \(cell.column + 1)"
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
