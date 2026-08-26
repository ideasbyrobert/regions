import SwiftUI

struct SettingsView: View
{
    @ObservedObject var controller: AppController

    var body: some View
    {
        TabView
        {
            GeneralSettingsView(controller: controller)
                .tabItem
                {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 520, height: 430)
    }
}
