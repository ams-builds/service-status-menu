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
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.2")
    ],
    targets: [
        .executableTarget(
            name: "ServiceStatusMenu",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        )
    ]
)
