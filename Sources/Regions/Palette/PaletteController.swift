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
    private var commitAction: (@MainActor (LayoutCommand, PaletteSession) -> Void)?
    private var isClosing = false
    private var isCommitting = false

    init(calculator: any LayoutCalculating, preferences: AppPreferences)
    {
        self.calculator = calculator
        self.preferences = preferences
    }

    func present(
        session: PaletteSession,
        commit: @escaping @MainActor (LayoutCommand, PaletteSession) -> Void
    )
    {
        close(restoreTarget: false)
        self.session = session
        commitAction = commit

        let model = PaletteModel(
            dimension: preferences.gridDimension,
            adjustmentAmount: preferences.adjustmentStep,
            onDimensionChange:
            {
                [weak self] dimension in
                self?.resizePanel(for: dimension)
            },
            onPreview:
            {
                [weak self] command in
                self?.preview(command)
            },
            onCommit:
            {
                [weak self] command in
                self?.commit(command)
            },
            onCancel:
            {
                [weak self] in
                self?.close(restoreTarget: true)
            }
        )
        self.model = model

        let panel = PalettePanel(
            contentRect: CGRect(
                x: 0,
                y: 0,
                width: PaletteView.preferredWidth,
                height: PaletteView.preferredHeight(for: model.dimension)
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.contentViewController = NSHostingController(rootView: PaletteView(model: model))
        panel.handlesKeyEvent =
        {
            [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }

        let visibleFrame = session.screen.visibleFrame
        let origin = CGPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.midY - panel.frame.height / 2
        )
        panel.setFrameOrigin(origin)
        self.panel = panel
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        panel.makeKeyAndOrderFront(nil)
        preview(.grid(GridRegion(
            dimension: preferences.gridDimension,
            anchor: GridCell(row: 0, column: 0),
            extent: GridCell(row: 0, column: 0)
        )))
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
        let targetProcessIdentifier = session?.window.processIdentifier
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
           let targetProcessIdentifier,
           let application = NSRunningApplication(processIdentifier: targetProcessIdentifier)
        {
            application.activate(options: [.activateAllWindows])
        }
        isClosing = false
    }

    func windowDidResignKey(_ notification: Notification)
    {
        close(restoreTarget: false)
    }

    private func preview(_ command: LayoutCommand?)
    {
        guard preferences.showsPreview,
              let command,
              let session
        else
        {
            footprintController.hide()
            return
        }
        let target = calculator.target(
            for: command,
            on: session.screen,
            currentWindowFrame: session.window.frame,
            spacing: preferences.spacing
        )
        footprintController.show(frame: target.frame)
    }

    private func commit(_ command: LayoutCommand)
    {
        guard !isCommitting
        else
        {
            return
        }
        guard let session,
              let commitAction
        else
        {
            close(restoreTarget: false)
            return
        }
        isCommitting = true
        preferences.gridDimension = model?.dimension ?? preferences.gridDimension
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
            commitAction(command, session)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool
    {
        guard let model
        else
        {
            return false
        }
        let extending = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)
        let command = event.modifierFlags.contains(.command)
        switch event.keyCode
        {
        case 19:
            model.setDimension(.twoByTwo)
        case 20:
            model.setDimension(.three)
        case 21:
            model.setDimension(.four)
        case 23:
            model.setDimension(.threeByTwo)
        case 22:
            model.setDimension(.fourByTwo)
        case 26:
            model.setDimension(.twoByThree)
        case 36, 76:
            model.commitSelection()
        case 53:
            model.cancel()
        case 123:
            if option
            {
                model.commit(.moveLeft)
            }
            else if command
            {
                model.commit(.narrow)
            }
            else
            {
                model.moveSelection(rowDelta: 0, columnDelta: -1, extending: extending)
            }
        case 124:
            if option
            {
                model.commit(.moveRight)
            }
            else if command
            {
                model.commit(.widen)
            }
            else
            {
                model.moveSelection(rowDelta: 0, columnDelta: 1, extending: extending)
            }
        case 125:
            if option
            {
                model.commit(.moveDown)
            }
            else if command
            {
                model.commit(.shorter)
            }
            else
            {
                model.moveSelection(rowDelta: 1, columnDelta: 0, extending: extending)
            }
        case 126:
            if option
            {
                model.commit(.moveUp)
            }
            else if command
            {
                model.commit(.taller)
            }
            else
            {
                model.moveSelection(rowDelta: -1, columnDelta: 0, extending: extending)
            }
        case 3:
            model.commit(.fill)
        case 8:
            model.commit(.center)
        case 13:
            model.commit(.maximizeWidth)
        case 4:
            model.commit(.maximizeHeight)
        default:
            return false
        }
        return true
    }

    private func resizePanel(for dimension: GridDimension)
    {
        guard let panel
        else
        {
            return
        }
        let height = PaletteView.preferredHeight(for: dimension)
        guard abs(panel.frame.height - height) > 0.5
        else
        {
            return
        }
        var frame = panel.frame
        let centerY = frame.midY
        frame.origin.y = centerY - height / 2
        frame.size.height = height
        panel.setFrame(frame, display: true, animate: true)
    }
}
