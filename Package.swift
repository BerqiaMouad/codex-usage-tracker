// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodexUsageTracker",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CodexUsageTracker", targets: ["CodexUsageTracker"]),
    ],
    targets: [
        .executableTarget(
            name: "CodexUsageTracker",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
