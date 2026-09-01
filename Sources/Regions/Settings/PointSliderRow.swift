import SwiftUI

struct PointSliderRow: View
{
    private static let digitWidth: CGFloat = 10
    private static let unitLabelWidth: CGFloat = 22

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

    private var digitsInWidestReading: Int
    {
        String(Int(range.upperBound)).count
    }

    private var readoutWidth: CGFloat
    {
        CGFloat(digitsInWidestReading) * Self.digitWidth
            + Self.unitLabelWidth
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
