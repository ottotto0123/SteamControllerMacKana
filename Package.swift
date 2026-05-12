// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SteamControllerMacKana",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SteamControllerMacKana",
            path: "Sources/SteamControllerMacKana",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)
