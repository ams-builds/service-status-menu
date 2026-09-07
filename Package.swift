// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ServiceStatusMenu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ServiceStatusMenu",
            targets: ["ServiceStatusMenu"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ServiceStatusMenu"
        )
    ]
)
