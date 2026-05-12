// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SteamMacKana",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SteamMacKana",
            path: "Sources/SteamMacKana",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)
