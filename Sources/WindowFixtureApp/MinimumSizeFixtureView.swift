import SwiftUI

struct MinimumSizeFixtureView: View
{
    var body: some View
    {
        ZStack
        {
            Color(nsColor: .windowBackgroundColor)
            VStack(spacing: 12)
            {
                Image(systemName: "rectangle.badge.plus")
                    .font(.system(size: 40))
                Text("Minimum 680 × 480")
                    .font(.title2)
                Text(
                    "Small regions should produce bounded best-effort "
                        + "placement."
                )
                .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 680, minHeight: 480)
    }
}
