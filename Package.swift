// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "SPMate",
    products: [
        .library(name: "SPMate", targets: ["SPMate"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten", exact: "0.32.0"),
        .package(url: "https://github.com/KittyMac/Hitch.git", from: "0.4.0"),
        .package(url: "https://github.com/KittyMac/Spanker.git", from: "0.2.0"),
        .package(url: "https://github.com/KittyMac/Sextant.git", from: "0.4.0"),
        .package(url: "https://github.com/KittyMac/Flynn.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "SPMate",
            dependencies: [
                "Hitch",
                "Spanker",
                "Sextant",
                "Flynn",
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
            ],
            plugins: [
                .plugin(name: "FlynnPlugin", package: "Flynn")
            ]
        ),
        .testTarget(
            name: "SPMateTests",
            dependencies: [ "SPMate" ]),
    ]
)
