import AppKit
import Foundation
import SwiftUI

@MainActor
final class PaletteController: NSObject, NSWindowDelegate
{
    private let calculator: any LayoutCalculating
    private let preferences: AppPreferences
    private let footprintController = FootprintPanelController()
    private var panel: PalettePanel?
    private var model: PaletteModel?
    private var session: PaletteSession?
    private var commitAction:
        (@MainActor (RegionPlacement, PaletteSession) -> Void)?
    private var isClosing = false
    private var isCommitting = false

    init(calculator: any LayoutCalculating, preferences: AppPreferences)
    {
        self.calculator = calculator
        self.preferences = preferences
    }

    func present(
        session: PaletteSession,
        commit:
            @escaping @MainActor (
                RegionPlacement,
                PaletteSession
            ) -> Void
    )
    {
        close(restoreTarget: false)
        self.session = session
        commitAction = commit

        let model = PaletteModel(
            context: session.context,
            adjustmentAmount: preferences.adjustmentStep,
            onPreview:
            {
                [weak self] placement in
                self?.preview(placement)
            },
            onCommit:
            {
                [weak self] placement in
                self?.commit(placement)
            },
            onCancel:
            {
                [weak self] in
                self?.close(restoreTarget: true)
            }
        )
        self.model = model

        let size = CGSize(
            width: PaletteView.preferredWidth,
            height: PaletteView.preferredHeight
        )
        let panel = PalettePanel(
            contentRect: Self.clampedFrame(
                contentSize: size,
                visibleFrame: session.screen.visibleFrame
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
        ]
        panel.hidesOnDeactivate = false
        panel.contentViewController = NSHostingController(
            rootView: PaletteView(
                model: model,
                spacing: preferences.spacing
            )
        )
        panel.handlesKeyEvent =
            {
                [weak self] event in
                self?.handleKeyEvent(event) ?? false
            }
        self.panel = panel
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        panel.makeKeyAndOrderFront(nil)
        model.beginPreview()
    }

    func snapshot(to path: String)
    {
        guard let panel
        else
        {
            return
        }
        PaletteSnapshotWriter.write(panel, to: path)
    }

    func close(restoreTarget: Bool = false)
    {
        guard !isClosing
        else
        {
            return
        }
        isClosing = true
        let processIdentifier = session?.window.processIdentifier
        footprintController.hide()
        panel?.handlesKeyEvent = nil
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel = nil
        model = nil
        session = nil
        commitAction = nil
        isCommitting = false
        if restoreTarget,
            let processIdentifier,
            let application = NSRunningApplication(
                processIdentifier: processIdentifier
            )
        {
            application.activate(options: [.activateAllWindows])
        }
        isClosing = false
    }

    func windowDidResignKey(_ notification: Notification)
    {
        close(restoreTarget: true)
    }

    static func clampedFrame(
        contentSize: CGSize,
        visibleFrame: CGRect,
        inset: CGFloat = 16
    ) -> CGRect
    {
        let width = min(
            contentSize.width, max(1, visibleFrame.width - 2 * inset))
        let height = min(
            contentSize.height,
            max(1, visibleFrame.height - 2 * inset)
        )
        let minimumX = visibleFrame.minX + inset
        let maximumX = visibleFrame.maxX - inset - width
        let minimumY = visibleFrame.minY + inset
        let maximumY = visibleFrame.maxY - inset - height
        let centeredX = visibleFrame.midX - width / 2
        let centeredY = visibleFrame.midY - height / 2
        return CGRect(
            x: min(max(centeredX, minimumX), max(minimumX, maximumX)),
            y: min(max(centeredY, minimumY), max(minimumY, maximumY)),
            width: width,
            height: height
        )
    }

    private func preview(_ placement: RegionPlacement?)
    {
        guard preferences.showsPreview,
            let placement,
            let session
        else
        {
            footprintController.hide()
            return
        }
        let target = calculator.target(
            for: .region(placement),
            on: session.screen,
            currentWindowFrame: session.window.frame,
            spacing: preferences.spacing
        )
        footprintController.show(frame: target.frame)
    }

    private func commit(_ placement: RegionPlacement)
    {
        guard !isCommitting,
            let session,
            let commitAction
        else
        {
            return
        }
        isCommitting = true
        panel?.handlesKeyEvent = nil
        panel?.ignoresMouseEvents = true
        DispatchQueue.main.async
        {
            [weak self] in
            guard let self,
                self.isCommitting
            else
            {
                return
            }
            self.close(restoreTarget: true)
            commitAction(placement, session)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool
    {
        guard let model
        else
        {
            return false
        }
        let option = event.modifierFlags.contains(.option)
        let command = event.modifierFlags.contains(.command)
        switch event.keyCode
        {
        case 36, 76:
            model.commit()
        case 53:
            model.cancel()
        case 37 where model.context.orientation == .landscape:
            model.select(.leading)
        case 17 where model.context.orientation == .portrait:
            model.select(.leading)
        case 8:
            model.select(.center)
        case 15 where model.context.orientation == .landscape:
            model.select(.trailing)
        case 11 where model.context.orientation == .portrait:
            model.select(.trailing)
        case 3:
            model.select(.fill)
        case 19:
            model.select(.quarter)
        case 23:
            model.select(.half)
        case 26:
            model.select(.seventy)
        case 25:
            model.select(.ninety)
        case 24, 69:
            model.grow()
        case 27, 78:
            model.shrink()
        case 123 where option:
            model.nudge(horizontal: -1, vertical: 0)
        case 124 where option:
            model.nudge(horizontal: 1, vertical: 0)
        case 125 where option:
            model.nudge(horizontal: 0, vertical: -1)
        case 126 where option:
            model.nudge(horizontal: 0, vertical: 1)
        case 123 where command:
            model.resize(width: -1, height: 0)
        case 124 where command:
            model.resize(width: 1, height: 0)
        case 125 where command:
            model.resize(width: 0, height: -1)
        case 126 where command:
            model.resize(width: 0, height: 1)
        default:
            return false
        }
        return true
    }
}
