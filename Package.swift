// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Regions",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Regions", targets: ["Regions"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Regions",
            dependencies: [],
            path: "Sources/Regions",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "RegionsTests",
            dependencies: ["Regions"],
            path: "Tests/RegionsTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
