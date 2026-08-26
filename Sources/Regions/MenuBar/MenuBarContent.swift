import SwiftUI

struct MenuBarContent: View
{
    @ObservedObject var controller: AppController
    @ObservedObject private var authorization: AccessibilityAuthorizationService

    init(controller: AppController)
    {
        self.controller = controller
        authorization = controller.authorization
    }

    var body: some View
    {
        Group
        {
            Button("Place Window")
            {
                controller.openPalette()
            }

            if let context = controller.regionContext
            {
                contextualActions(context)
            }

            if let status = controller.statusMessage
            {
                Divider()
                Text(short(status))
            }

            Divider()

            if !authorization.isTrusted
            {
                Button("Allow Window Control")
                {
                    controller.showPermissionWindow()
                }
            }

            SettingsLink
            {
                Text("Settings…")
            }

            Button("About Regions")
            {
                controller.showAbout()
            }

            Button("Quit Regions")
            {
                controller.quit()
            }
        }
        .onAppear
        {
            authorization.refresh()
            controller.refreshRegionContext()
        }
    }

    @ViewBuilder
    private func contextualActions(_ context: RegionContext) -> some View
    {
        if context.canArrangeApplication
        {
            Button("Arrange \(context.applicationWindowCount) Windows")
            {
                controller.arrangeApplicationWindows()
            }
        }

        if context.displayCount > 1
        {
            Menu("Displays")
            {
                Button("Gather App Windows")
                {
                    controller.gatherAppWindows()
                }

                Button("Move Window Previous")
                {
                    controller.moveFocusedWindowToPreviousDisplay()
                }

                Button("Move Window Next")
                {
                    controller.moveFocusedWindowToNextDisplay()
                }
            }
        }

        if context.applicationWindowCount > 1
        {
            if context.hasSavedLayout
            {
                if context.canRestoreSavedLayout
                {
                    Button("Restore App Layout")
                    {
                        controller.restoreAppLayout()
                    }
                }

                Button("Update App Layout")
                {
                    controller.saveAppLayout()
                }

                Button("Forget App Layout")
                {
                    controller.forgetAppLayout()
                }
            } else
            {
                Button("Save App Layout")
                {
                    controller.saveAppLayout()
                }
            }
        }

        if context.canUndo
        {
            Button("Undo Placement")
            {
                controller.restorePreviousFrame()
            }
        }
    }

    private func short(_ value: String) -> String
    {
        guard value.count > 30
        else
        {
            return value
        }
        return String(value.prefix(27)) + "..."
    }
}
