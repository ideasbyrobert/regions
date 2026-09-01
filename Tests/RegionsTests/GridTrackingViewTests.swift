import AppKit
import XCTest
@testable import Regions

@MainActor
final class GridTrackingViewTests: XCTestCase
{
    func testMouseSequenceUsesFlippedGridCoordinates()
    {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let view = GridTrackingView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.contentView = view

        var beganAt: CGPoint?
        var updatedAt: CGPoint?
        var endedAt: CGPoint?
        var reportedSize: CGSize?
        view.begin =
        {
            location, size in
            beganAt = location
            reportedSize = size
        }
        view.update =
        {
            location, _ in
            updatedAt = location
        }
        view.end =
        {
            location, _ in
            endedAt = location
        }

        view.mouseDown(with: event(type: .leftMouseDown, location: CGPoint(x: 25, y: 75)))
        view.mouseDragged(with: event(type: .leftMouseDragged, location: CGPoint(x: 50, y: 50)))
        view.mouseUp(with: event(type: .leftMouseUp, location: CGPoint(x: 75, y: 25)))

        XCTAssertEqual(beganAt, CGPoint(x: 25, y: 25))
        XCTAssertEqual(updatedAt, CGPoint(x: 50, y: 50))
        XCTAssertEqual(endedAt, CGPoint(x: 75, y: 75))
        XCTAssertEqual(reportedSize, CGSize(width: 100, height: 100))
    }

    private func event(type: NSEvent.EventType, location: CGPoint) -> NSEvent
    {
        NSEvent.mouseEvent(
            with: type,
            location: location,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }
}
