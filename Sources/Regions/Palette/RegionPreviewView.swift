import SwiftUI

struct RegionPreviewView: View
{
    let context: RegionContext
    let placement: RegionPlacement
    let spacing: CGFloat

    var body: some View
    {
        GeometryReader
        {
            proxy in
            let visible = context.screen.visibleFrame
            let target = GridLayoutCalculator().target(
                for: .region(placement),
                on: context.screen,
                currentWindowFrame: context.window.frame,
                spacing: spacing
            )
            let scaleX = proxy.size.width / visible.width
            let scaleY = proxy.size.height / visible.height
            let width = target.frame.width * scaleX
            let height = target.frame.height * scaleY
            let x = (target.frame.minX - visible.minX) * scaleX
            let y = (visible.maxY - target.frame.maxY) * scaleY

            ZStack(alignment: .topLeading)
            {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: width, height: height)
                    .offset(x: x, y: y)
            }
        }
        .accessibilityHidden(true)
    }
}
