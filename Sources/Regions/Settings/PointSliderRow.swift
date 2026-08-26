import SwiftUI

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
