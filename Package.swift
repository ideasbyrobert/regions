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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.4")
    ],
    targets: [
        .executableTarget(
            name: "Regions",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Regions",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .target(
            name: "WindowFixtureApp",
            path: "Sources/WindowFixtureApp",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "RegionsTests",
            dependencies: [
                "Regions",
                "WindowFixtureApp"
            ],
            path: "Tests/RegionsTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
