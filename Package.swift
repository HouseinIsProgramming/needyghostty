// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NeedyGhostty",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "needyghostty", targets: ["NeedyGhostty"]),
        .library(name: "NeedyGhosttyCore", targets: ["NeedyGhosttyCore"]),
    ],
    targets: [
        .target(
            name: "NeedyGhosttyCore",
            path: "Sources/NeedyGhosttyCore"
        ),
        .executableTarget(
            name: "NeedyGhostty",
            dependencies: ["NeedyGhosttyCore"],
            path: "Sources/NeedyGhostty",
            linkerSettings: [.linkedFramework("Cocoa")]
        ),
        .testTarget(
            name: "NeedyGhosttyTests",
            dependencies: ["NeedyGhosttyCore"],
            path: "Tests/NeedyGhosttyTests"
        ),
    ]
)
