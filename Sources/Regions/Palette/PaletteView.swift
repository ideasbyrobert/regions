import SwiftUI

struct PaletteView: View
{
    static let preferredWidth: CGFloat = 360

    @ObservedObject var model: PaletteModel
    @State private var selectedDimension: GridDimension

    init(model: PaletteModel)
    {
        self.model = model
        _selectedDimension = State(initialValue: model.dimension)
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 16)
        {
            VStack(alignment: .leading, spacing: 10)
            {
                Text("Arrange Window")
                    .font(.headline)
                Picker("Grid", selection: $selectedDimension)
                {
                    ForEach(GridDimension.allCases, id: \.self)
                    {
                        dimension in
                        Text(dimension.title)
                            .tag(dimension)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .onChange(of: selectedDimension)
                {
                    _, dimension in
                    if model.dimension != dimension
                    {
                        model.setDimension(dimension)
                    }
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
                spacing: 6
            )
            {
                ForEach(LayoutPreset.paletteCases, id: \.self)
                {
                    preset in
                    Button
                    {
                        model.commit(preset)
                    }
                    label:
                    {
                        Image(systemName: preset.systemImage)
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                    .buttonStyle(.bordered)
                    .help(preset.title)
                    .accessibilityIdentifier("palette.preset.\(preset.rawValue)")
                    .accessibilityLabel(preset.title)
                }
            }

            HStack(spacing: 8)
            {
                Menu("Splits")
                {
                    ForEach(LayoutPreset.masterStackCases, id: \.self)
                    {
                        preset in
                        Button(preset.title)
                        {
                            model.commit(preset)
                        }
                    }
                }

                Menu("Thirds")
                {
                    ForEach(LayoutPreset.horizontalThirdCases, id: \.self)
                    {
                        preset in
                        Button(preset.title)
                        {
                            model.commit(preset)
                        }
                    }

                    Divider()

                    ForEach(LayoutPreset.verticalThirdCases, id: \.self)
                    {
                        preset in
                        Button(preset.title)
                        {
                            model.commit(preset)
                        }
                    }
                }

                Menu("Center")
                {
                    ForEach(LayoutPreset.triptychCases, id: \.self)
                    {
                        preset in
                        Button(preset.title)
                        {
                            model.commit(preset)
                        }
                    }

                    Divider()

                    ForEach(LayoutPreset.centeredSizeCases, id: \.self)
                    {
                        preset in
                        Button(preset.title)
                        {
                            model.commit(preset)
                        }
                    }

                    Divider()

                    Button(LayoutPreset.maximizeWidth.title)
                    {
                        model.commit(.maximizeWidth)
                    }

                    Button(LayoutPreset.maximizeHeight.title)
                    {
                        model.commit(.maximizeHeight)
                    }
                }

                Menu("Move")
                {
                    ForEach(WindowMovePosition.allCases, id: \.self)
                    {
                        position in
                        Button(position.title)
                        {
                            model.commit(.move(position))
                        }
                    }

                    Divider()

                    ForEach(WindowAdjustment.moveCases, id: \.self)
                    {
                        adjustment in
                        Button(adjustment.title)
                        {
                            model.commit(adjustment)
                        }
                    }
                }

                Menu("Resize")
                {
                    ForEach(WindowAdjustment.resizeCases, id: \.self)
                    {
                        adjustment in
                        Button(adjustment.title)
                        {
                            model.commit(adjustment)
                        }
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: false, vertical: true)

            ZStack
            {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 6),
                        count: model.dimension.columnCount
                    ),
                    spacing: 6
                )
                {
                    ForEach(cells, id: \.self)
                    {
                        cell in
                        GridCellView(
                            cell: cell,
                            dimension: model.dimension,
                            isSelected: model.selectedRegion?.contains(cell) == true
                        )
                        {
                            model.select(cell)
                        }
                    }
                }

                GridInteractionView(
                    begin:
                    {
                        location, size in
                        model.beginDrag(at: location, in: size)
                    },
                    update:
                    {
                        location, size in
                        model.updateDrag(at: location, in: size)
                    },
                    end:
                    {
                        location, size in
                        model.endDrag(at: location, in: size)
                    }
                )
                .accessibilityHidden(true)
            }
            .frame(height: gridHeight)
            .accessibilityIdentifier("palette.grid")
            .accessibilityLabel("Window layout grid")

            Text("Drag across cells. Numbers set the grid; F fills; C centers; ⌥ arrows move; ⌘ arrows resize.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(
            width: Self.preferredWidth,
            height: Self.preferredHeight(for: model.dimension),
            alignment: .topLeading
        )
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .onChange(of: model.dimension)
        {
            _, dimension in
            if selectedDimension != dimension
            {
                selectedDimension = dimension
            }
        }
    }

    private var cells: [GridCell]
    {
        (0..<model.dimension.rowCount).flatMap
        {
            row in
            (0..<model.dimension.columnCount).map
            {
                column in
                GridCell(row: row, column: column)
            }
        }
    }

    private var gridHeight: CGFloat
    {
        let spacing: CGFloat = 6
        let width: CGFloat = 324
        let cellWidth = (
            width - spacing * CGFloat(model.dimension.columnCount - 1)
        ) / CGFloat(model.dimension.columnCount)
        return cellWidth * CGFloat(model.dimension.rowCount)
            + spacing * CGFloat(model.dimension.rowCount - 1)
    }

    static func preferredHeight(for dimension: GridDimension) -> CGFloat
    {
        switch dimension
        {
        case .twoByTwo:
            return 590
        case .threeByTwo:
            return 480
        case .twoByThree:
            return 755
        case .three:
            return 590
        case .fourByTwo:
            return 448
        case .four:
            return 590
        }
    }
}
