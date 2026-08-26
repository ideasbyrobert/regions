import SwiftUI

struct FootprintView: View
{
    var body: some View
    {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.accentColor.opacity(0.18))
            .overlay
            {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 2)
            }
            .padding(3)
    }
}
