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
        .library(
            name: "CallDPUI",
            targets: ["CallDPUI"]
        ),
    ],
    targets: [
        .target(
            name: "CallDPCore"
        ),
        .target(
            name: "CallDPUI",
            dependencies: ["CallDPCore"]
            ,
            path: "Sources/CallDPApp"
        ),
        .testTarget(
            name: "CallDPCoreTests",
            dependencies: ["CallDPCore"]
        ),
    ]
)
