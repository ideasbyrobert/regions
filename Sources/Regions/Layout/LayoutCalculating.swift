import CoreGraphics
import Foundation

protocol LayoutCalculating: Sendable
{
    func target(
        for command: LayoutCommand,
        on screen: ScreenSnapshot,
        currentWindowFrame: CGRect,
        spacing: CGFloat
    ) -> LayoutTarget
}
