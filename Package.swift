// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "GalaxyBudsMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GalaxyBudsMac",
            path: "Sources/GalaxyBudsMac",
            linkerSettings: [.linkedFramework("IOBluetooth")]
        ),
        .testTarget(
            name: "GalaxyBudsMacTests",
            dependencies: ["GalaxyBudsMac"],
            path: "Tests/GalaxyBudsMacTests"
        ),
    ]
)
