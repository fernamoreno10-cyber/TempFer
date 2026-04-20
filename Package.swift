// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TempFer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TempFer",
            path: "Sources/TempFer",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Cocoa"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
