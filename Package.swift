// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CallDP",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CallDPCore",
            targets: ["CallDPCore"]
        ),
        .executable(
            name: "CallDPApp",
            targets: ["CallDPApp"]
        ),
    ],
    targets: [
        .target(
            name: "CallDPCore"
        ),
        .executableTarget(
            name: "CallDPApp",
            dependencies: ["CallDPCore"]
        ),
        .testTarget(
            name: "CallDPCoreTests",
            dependencies: ["CallDPCore"]
        ),
    ]
)
