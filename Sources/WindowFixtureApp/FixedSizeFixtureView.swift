import SwiftUI

struct FixedSizeFixtureView: View
{
    var body: some View
    {
        VStack(spacing: 12)
        {
            Image(systemName: "lock.rectangle")
                .font(.system(size: 40))
            Text("Fixed 480 × 320")
                .font(.title2)
            Text(
                "The manager should preserve this size and align it inside "
                    + "the selected region."
            )
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 480, height: 320)
    }
}
