import SwiftUI

@main
struct RegionsApp: App
{
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController.shared

    var body: some Scene
    {
        MenuBarExtra("Regions", systemImage: "rectangle.3.group")
        {
            MenuBarContent(controller: controller)
        }
        .menuBarExtraStyle(.menu)

        Settings
        {
            SettingsView(controller: controller)
        }
        .restorationBehavior(.disabled)
    }
}
