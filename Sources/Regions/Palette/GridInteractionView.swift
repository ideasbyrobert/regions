import SwiftUI

struct GridInteractionView: NSViewRepresentable
{
    let begin: @MainActor (CGPoint, CGSize) -> Void
    let update: @MainActor (CGPoint, CGSize) -> Void
    let end: @MainActor (CGPoint, CGSize) -> Void

    func makeNSView(context: Context) -> GridTrackingView
    {
        let view = GridTrackingView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: GridTrackingView, context: Context)
    {
        configure(nsView)
    }

    private func configure(_ view: GridTrackingView)
    {
        view.begin = begin
        view.update = update
        view.end = end
    }
}
