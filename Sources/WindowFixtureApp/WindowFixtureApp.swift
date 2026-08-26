import AppKit
import SwiftUI

@main
struct WindowFixtureApp: App
{
    init()
    {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene
    {
        WindowGroup("Window Fixtures", id: "controls")
        {
            FixtureControlView()
        }
        .defaultSize(width: 520, height: 420)

        Window("Resizable Fixture", id: "resizable")
        {
            ResizableFixtureView()
        }
        .defaultSize(width: 640, height: 480)

        Window("Minimum Size Fixture", id: "minimum")
        {
            MinimumSizeFixtureView()
        }
        .defaultSize(width: 720, height: 520)

        Window("Fixed Size Fixture", id: "fixed")
        {
            FixedSizeFixtureView()
        }
        .windowResizability(.contentSize)
    }
}
