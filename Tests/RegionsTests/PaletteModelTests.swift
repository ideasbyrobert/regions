import CoreGraphics
import XCTest

@testable import Regions

@MainActor
final class PaletteModelTests: XCTestCase
{
    func testSelectionPreviewsWithoutCommitting()
    {
        var previews: [RegionPlacement?] = []
        var commits: [RegionPlacement] = []
        let model = makeModel(
            onPreview:
            {
                previews.append($0)
            },
            onCommit:
            {
                commits.append($0)
            }
        )

        model.select(.leading)
        model.select(.quarter)

        XCTAssertEqual(
            previews.compactMap { $0 }.last?.position,
            .leading
        )
        XCTAssertEqual(
            previews.compactMap { $0 }.last?.size,
            .quarter
        )
        XCTAssertTrue(commits.isEmpty)

        model.commit()

        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(commits.first?.position, .leading)
        XCTAssertEqual(commits.first?.size, .quarter)
    }

    func testCancelClearsPreviewWithoutCommit()
    {
        var previews: [RegionPlacement?] = []
        var commitCount = 0
        var cancelCount = 0
        let model = makeModel(
            onPreview:
            {
                previews.append($0)
            },
            onCommit:
            {
                _ in
                commitCount += 1
            },
            onCancel:
            {
                cancelCount += 1
            }
        )

        model.cancel()

        XCTAssertNil(previews.last!)
        XCTAssertEqual(commitCount, 0)
        XCTAssertEqual(cancelCount, 1)
    }

    func testNonResizableWindowOffersPositionOnly()
    {
        let model = makeModel(isResizable: false)
        let initial = model.placement

        XCTAssertEqual(model.positions, [.leading, .center, .trailing])
        XCTAssertTrue(model.sizes.isEmpty)

        model.select(.fill)
        model.resize(width: 1, height: 1)

        XCTAssertEqual(model.placement, initial)
    }

    func testPositionChangesChooseNearestAvailableSize()
    {
        let model = makeModel()

        model.select(.center)
        model.select(.ninety)
        model.select(.leading)

        XCTAssertEqual(model.placement.position, .leading)
        XCTAssertEqual(model.placement.size, .seventy)
        XCTAssertEqual(model.sizes, [.quarter, .half, .seventy])
    }

    func testKeyboardRefinementUsesConfiguredStep()
    {
        let model = makeModel(adjustmentAmount: 32)

        model.nudge(horizontal: 1, vertical: -1)
        model.resize(width: -1, height: 1)
        model.grow()

        XCTAssertEqual(model.placement.horizontalOffset, 32)
        XCTAssertEqual(model.placement.verticalOffset, -32)
        XCTAssertEqual(model.placement.widthDelta, 0)
        XCTAssertEqual(model.placement.heightDelta, 64)
    }

    private func makeModel(
        isResizable: Bool = true,
        adjustmentAmount: Double = 32,
        onPreview: @escaping @MainActor (RegionPlacement?) -> Void =
            {
                _ in
            },
        onCommit: @escaping @MainActor (RegionPlacement) -> Void =
            {
                _ in
            },
        onCancel: @escaping @MainActor () -> Void =
            {
            }
    ) -> PaletteModel
    {
        PaletteModel(
            context: context(isResizable: isResizable),
            adjustmentAmount: adjustmentAmount,
            onPreview: onPreview,
            onCommit: onCommit,
            onCancel: onCancel
        )
    }

    private func context(isResizable: Bool) -> RegionContext
    {
        let screen = ScreenSnapshot(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(
                x: 0,
                y: 0,
                width: 1000,
                height: 800
            ),
            backingScaleFactor: 2
        )
        return RegionContext(
            window: ManagedWindowSnapshot(
                token: ManagedWindowToken(id: UUID()),
                processIdentifier: 42,
                frame: CGRect(x: 150, y: 100, width: 700, height: 600),
                isResizable: isResizable
            ),
            screen: screen,
            applicationWindowCount: 3,
            displayCount: 1,
            isTerminal: false,
            hasSavedLayout: false,
            savedWindowCount: nil,
            canUndo: false
        )
    }
}
