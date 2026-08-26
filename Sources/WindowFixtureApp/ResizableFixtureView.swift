import SwiftUI

struct ResizableFixtureView: View
{
    var body: some View
    {
        ZStack
        {
            Color(nsColor: .windowBackgroundColor)
            VStack(spacing: 12)
            {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 40))
                Text("Resizable Window")
                    .font(.title2)
                Text(
                    "This window should match every requested frame within "
                        + "tolerance."
                )
                .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 220, minHeight: 160)
    }
}
