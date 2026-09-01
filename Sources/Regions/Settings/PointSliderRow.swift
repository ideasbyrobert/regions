import SwiftUI

/// A slider over a point measurement, with its current value read out beside it.
///
/// The two rows this replaces were written separately and had drifted: their
/// readouts reserved 42 and 48 points, so the sliders above and below each
/// other ended at different places. One row means one width, and the width is
/// derived from the widest value the range can actually produce rather than
/// guessed.
struct PointSliderRow: View
{
    private let label: String
    private let value: Binding<Double>
    private let range: ClosedRange<Double>
    private let step: Double

    init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double
    )
    {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
    }

    /// Wide enough for the largest reading the range allows, so the column
    /// never reflows as the slider moves.
    private var readoutWidth: CGFloat
    {
        let widestDigits = String(Int(range.upperBound)).count
        return CGFloat(widestDigits) * 10 + 22
    }

    var body: some View
    {
        HStack
        {
            Slider(value: value, in: range, step: step)
            Text("\(Int(value.wrappedValue)) pt")
                .monospacedDigit()
                .frame(width: readoutWidth, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}
