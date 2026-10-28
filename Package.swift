// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EveryDevice",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "EveryDeviceCore", targets: ["EveryDeviceCore"]),
        .executable(name: "EveryDevice", targets: ["EveryDevice"])
    ],
    targets: [
        .target(
            name: "EveryDeviceCore",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "EveryDevice",
            dependencies: ["EveryDeviceCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
