import SwiftUI

struct MenuBarContent: View
{
    @ObservedObject var controller: AppController
    @ObservedObject private var preferences: AppPreferences
    @ObservedObject private var authorization: AccessibilityAuthorizationService
    @ObservedObject private var desktopVisibility: DesktopVisibilityService
    @ObservedObject private var updates: UpdateController

    init(controller: AppController)
    {
        self.controller = controller
        preferences = controller.preferences
        authorization = controller.authorization
        desktopVisibility = controller.desktopVisibility
        updates = controller.updates
    }

    var body: some View
    {
        Button("Open Layout Palette")
        {
            controller.openPalette()
        }

        Button("Arrange App Windows 3 × 2")
        {
            controller.arrangeAllWindowsThreeByTwo()
        }
        .disabled(!controller.batchArrangementAvailability.isAvailable)

        Button("Arrange App Windows 4 × 2")
        {
            controller.arrangeAllWindowsFourByTwo()
        }
        .disabled(!controller.batchArrangementAvailability.isAvailable)

        Text(controller.batchArrangementAvailability.detailText)
            .onAppear
            {
                controller.refreshBatchArrangementAvailability()
            }

        Text("Shortcut: \(preferences.paletteShortcut.displayName)")

        Menu("Pro Splits")
        {
            CommandButtons(LayoutPreset.masterStackCases, perform: controller.applyPreset)
        }

        Menu("Thirds")
        {
            CommandButtons(LayoutPreset.horizontalThirdCases, perform: controller.applyPreset)

            Divider()

            CommandButtons(LayoutPreset.verticalThirdCases, perform: controller.applyPreset)
        }

        Menu("Triptych & Center Focus")
        {
            CommandButtons(LayoutPreset.triptychCases, perform: controller.applyPreset)

            Divider()

            CommandButtons(LayoutPreset.centeredSizeCases, perform: controller.applyPreset)
        }

        Menu("Common Layouts")
        {
            CommandButtons(LayoutPreset.paletteCases, perform: controller.applyPreset)
        }

        Menu("Size and Position")
        {
            Button(LayoutPreset.maximizeWidth.title)
            {
                controller.applyPreset(.maximizeWidth)
            }

            Button(LayoutPreset.maximizeHeight.title)
            {
                controller.applyPreset(.maximizeHeight)
            }

            Divider()

            CommandButtons(WindowMovePosition.allCases, perform: controller.moveWindow)
        }

        Menu("Move and Resize")
        {
            CommandButtons(WindowAdjustment.allCases, perform: controller.applyAdjustment)
        }

        Menu("Saved App Layouts")
        {
            ForEach(1...3, id: \.self)
            {
                slot in
                Menu("Slot \(slot)")
                {
                    Button("Restore")
                    {
                        controller.restoreAppLayout(slot: slot)
                    }
                    .disabled(!controller.savedLayoutSlots.contains(slot))

                    Button("Save Current Arrangement")
                    {
                        controller.saveAppLayout(slot: slot)
                    }

                    if controller.savedLayoutSlots.contains(slot)
                    {
                        Divider()

                        Button("Delete", role: .destructive)
                        {
                            controller.deleteAppLayout(slot: slot)
                        }
                    }
                }
            }
        }
        .onAppear
        {
            controller.refreshSavedLayoutSlots()
        }

        Button(desktopVisibility.isDesktopShown ? "Restore Desktop" : "Show Desktop")
        {
            controller.showOrRestoreDesktop()
        }

        Menu("Displays")
        {
            Button("Swap Windows Between Displays")
            {
                controller.swapWindowsBetweenDisplays()
            }

            Divider()

            Button("Gather App Windows on This Display")
            {
                controller.gatherAppWindowsOnFocusedDisplay()
            }

            Button("Move App Windows to Previous Display")
            {
                controller.moveAppWindowsToPreviousDisplay()
            }

            Button("Move App Windows to Next Display")
            {
                controller.moveAppWindowsToNextDisplay()
            }

            Divider()

            Button("Move Focused Window to Previous Display")
            {
                controller.moveToPreviousDisplay()
            }

            Button("Move Focused Window to Next Display")
            {
                controller.moveToNextDisplay()
            }
        }

        Divider()

        Button("Restore Previous Frame")
        {
            controller.restorePreviousFrame()
        }

        Menu("Window Actions")
        {
            CommandButtons(WindowFocusDirection.allCases, perform: controller.focusAppWindow)

            Divider()

            CommandButtons(WindowLifecycleAction.menuCases, perform: controller.performWindowAction)
        }

        if let statusMessage = controller.statusMessage
        {
            Divider()
            Text(statusMessage)
        }

        Divider()

        Button(authorization.isTrusted ? "Window Control: Allowed" : "Window Control: Required")
        {
            controller.showPermissionWindow()
        }

        SettingsLink
        {
            Text("Settings…")
        }

        Button("About Regions")
        {
            controller.showAbout()
        }

        Button("Check for Updates…")
        {
            updates.checkForUpdates()
        }
        .disabled(!updates.canCheck)

        Divider()

        Button("Quit Regions")
        {
            controller.quit()
        }
    }
}
