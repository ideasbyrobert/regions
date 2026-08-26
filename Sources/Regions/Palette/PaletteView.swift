import SwiftUI

struct PaletteView: View
{
    static let preferredWidth: CGFloat = 340
    static let preferredHeight: CGFloat = 356

    @ObservedObject var model: PaletteModel
    let spacing: CGFloat

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            HStack(alignment: .firstTextBaseline)
            {
                Text("Place Window")
                    .font(.headline)
                Spacer()
                Text(contextTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6)
            {
                ForEach(model.positions, id: \.self)
                {
                    position in
                    Button
                    {
                        model.select(position)
                    } label:
                    {
                        VStack(spacing: 3)
                        {
                            Image(
                                systemName: position.systemImage(
                                    for: model.context.orientation
                                )
                            )
                            Text(
                                position.title(
                                    for: model.context.orientation
                                )
                            )
                            .font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(
                        model.placement.position == position
                            ? Color.accentColor
                            : nil
                    )
                    .accessibilityIdentifier(
                        "palette.position.\(position.rawValue)"
                    )
                }
            }

            Group
            {
                if !model.sizes.isEmpty
                {
                    HStack(spacing: 6)
                    {
                        Text("Size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(model.sizes, id: \.self)
                        {
                            size in
                            Button(size.title)
                            {
                                model.select(size)
                            }
                            .buttonStyle(.bordered)
                            .tint(
                                model.placement.size == size
                                    ? Color.accentColor
                                    : nil
                            )
                            .accessibilityIdentifier(
                                "palette.size.\(size.rawValue)"
                            )
                        }
                    }
                } else
                {
                    Text(sizeExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 30, alignment: .leading)

            RegionPreviewView(
                context: model.context,
                placement: model.placement,
                spacing: spacing
            )
            .frame(height: 104)

            Text("L C R F · 2 5 7 9 · +/- refine · Return applies")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack
            {
                Button("Cancel")
                {
                    model.cancel()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Place")
                {
                    model.commit()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("palette.place")
            }
        }
        .padding(16)
        .frame(
            width: Self.preferredWidth,
            height: Self.preferredHeight,
            alignment: .topLeading
        )
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var contextTitle: String
    {
        let resizeTitle = model.isResizable ? "Resizable" : "Position only"
        return "\(model.context.orientation.title) · \(resizeTitle)"
    }

    private var sizeExplanation: String
    {
        model.isResizable
            ? "Fill uses the visible area."
            : "This window keeps its current size."
    }
}
