import Foundation

enum LayoutPreset: String, CaseIterable, Codable, Sendable
{
    case fill
    case almostFill
    case center
    case maximizeWidth
    case maximizeHeight
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case leftThird
    case centerThird
    case rightThird
    case leftTwoThirds
    case rightTwoThirds
    case topThird
    case middleThird
    case bottomThird
    case topTwoThirds
    case bottomTwoThirds
    case centeredHalf
    case centeredTwoThirds
    case centeredThreeQuarters
    case leftSixtyPercent
    case rightFortyPercent
    case leftFortyPercent
    case rightSixtyPercent
    case leftSeventyPercent
    case rightThirtyPercent
    case leftThirtyPercent
    case rightSeventyPercent
    case topSeventyPercent
    case bottomThirtyPercent
    case centerFocusFiftyPercent
    case centerFocusSixtyPercent
    case centeredSixtyPercent
    case centeredEightyPercent
    case firstQuarterColumn
    case secondQuarterColumn
    case thirdQuarterColumn
    case fourthQuarterColumn

    static let paletteCases: [LayoutPreset] = [
        .fill,
        .center,
        .leftHalf,
        .rightHalf,
        .topHalf,
        .bottomHalf,
        .topLeftQuarter,
        .topRightQuarter,
        .bottomLeftQuarter,
        .bottomRightQuarter,
    ]

    static let horizontalThirdCases: [LayoutPreset] = [
        .leftThird,
        .centerThird,
        .rightThird,
        .leftTwoThirds,
        .rightTwoThirds,
    ]

    static let verticalThirdCases: [LayoutPreset] = [
        .topThird,
        .middleThird,
        .bottomThird,
        .topTwoThirds,
        .bottomTwoThirds,
    ]

    static let centeredSizeCases: [LayoutPreset] = [
        .centeredHalf,
        .centeredSixtyPercent,
        .centeredTwoThirds,
        .centeredThreeQuarters,
        .centeredEightyPercent,
        .almostFill,
    ]

    static let masterStackCases: [LayoutPreset] = [
        .leftSixtyPercent,
        .rightFortyPercent,
        .leftFortyPercent,
        .rightSixtyPercent,
        .leftSeventyPercent,
        .rightThirtyPercent,
        .leftThirtyPercent,
        .rightSeventyPercent,
        .topSeventyPercent,
        .bottomThirtyPercent,
    ]

    static let triptychCases: [LayoutPreset] = [
        .centerFocusFiftyPercent,
        .centerFocusSixtyPercent,
    ]

    static let fourColumnCases: [LayoutPreset] = [
        .firstQuarterColumn,
        .secondQuarterColumn,
        .thirdQuarterColumn,
        .fourthQuarterColumn,
    ]

    var title: String
    {
        switch self
        {
        case .fill:
            "Fill"
        case .almostFill:
            "Almost Fill"
        case .center:
            "Center"
        case .maximizeWidth:
            "Maximize Width"
        case .maximizeHeight:
            "Maximize Height"
        case .leftHalf:
            "Left Half"
        case .rightHalf:
            "Right Half"
        case .topHalf:
            "Top Half"
        case .bottomHalf:
            "Bottom Half"
        case .topLeftQuarter:
            "Top Left"
        case .topRightQuarter:
            "Top Right"
        case .bottomLeftQuarter:
            "Bottom Left"
        case .bottomRightQuarter:
            "Bottom Right"
        case .leftThird:
            "Left Third"
        case .centerThird:
            "Center Third"
        case .rightThird:
            "Right Third"
        case .leftTwoThirds:
            "Left Two Thirds"
        case .rightTwoThirds:
            "Right Two Thirds"
        case .topThird:
            "Top Third"
        case .middleThird:
            "Middle Third"
        case .bottomThird:
            "Bottom Third"
        case .topTwoThirds:
            "Top Two Thirds"
        case .bottomTwoThirds:
            "Bottom Two Thirds"
        case .centeredHalf:
            "Centered Half"
        case .centeredTwoThirds:
            "Centered Two Thirds"
        case .centeredThreeQuarters:
            "Centered Three Quarters"
        case .leftSixtyPercent:
            "Left 60%"
        case .rightFortyPercent:
            "Right 40%"
        case .leftFortyPercent:
            "Left 40%"
        case .rightSixtyPercent:
            "Right 60%"
        case .leftSeventyPercent:
            "Left 70%"
        case .rightThirtyPercent:
            "Right 30%"
        case .leftThirtyPercent:
            "Left 30%"
        case .rightSeventyPercent:
            "Right 70%"
        case .topSeventyPercent:
            "Top 70%"
        case .bottomThirtyPercent:
            "Bottom 30%"
        case .centerFocusFiftyPercent:
            "Center Focus 50%"
        case .centerFocusSixtyPercent:
            "Center Focus 60%"
        case .centeredSixtyPercent:
            "Centered 60%"
        case .centeredEightyPercent:
            "Centered 80%"
        case .firstQuarterColumn:
            "First Column (1/4)"
        case .secondQuarterColumn:
            "Second Column (2/4)"
        case .thirdQuarterColumn:
            "Third Column (3/4)"
        case .fourthQuarterColumn:
            "Fourth Column (4/4)"
        }
    }

    var systemImage: String
    {
        switch self
        {
        case .fill, .almostFill:
            "rectangle.inset.filled"
        case .center:
            "rectangle.center.inset.filled"
        case .maximizeWidth:
            "arrow.left.and.right"
        case .maximizeHeight:
            "arrow.up.and.down"
        case .leftHalf, .leftSixtyPercent, .leftSeventyPercent:
            "rectangle.lefthalf.inset.filled"
        case .rightHalf, .rightFortyPercent, .rightThirtyPercent:
            "rectangle.righthalf.inset.filled"
        case .leftFortyPercent, .leftThirtyPercent:
            "rectangle.leadingthird.inset.filled"
        case .rightSixtyPercent, .rightSeventyPercent:
            "rectangle.trailingthird.inset.filled"
        case .topHalf, .topSeventyPercent:
            "rectangle.tophalf.inset.filled"
        case .bottomHalf, .bottomThirtyPercent:
            "rectangle.bottomhalf.inset.filled"
        case .topLeftQuarter:
            "rectangle.topthird.inset.filled"
        case .topRightQuarter:
            "rectangle.topthird.inset.filled"
        case .bottomLeftQuarter:
            "rectangle.bottomthird.inset.filled"
        case .bottomRightQuarter:
            "rectangle.bottomthird.inset.filled"
        case .leftThird, .centerThird, .rightThird, .leftTwoThirds,
            .rightTwoThirds:
            "rectangle.split.3x1"
        case .topThird, .middleThird, .bottomThird, .topTwoThirds,
            .bottomTwoThirds:
            "rectangle.split.1x2"
        case .centeredHalf, .centeredSixtyPercent, .centeredTwoThirds,
            .centeredThreeQuarters, .centeredEightyPercent:
            "rectangle.center.inset.filled"
        case .centerFocusFiftyPercent, .centerFocusSixtyPercent:
            "rectangle.center.inset.filled"
        case .firstQuarterColumn, .secondQuarterColumn, .thirdQuarterColumn,
            .fourthQuarterColumn:
            "rectangle.split.3x1"
        }
    }
}
