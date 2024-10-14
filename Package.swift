// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "SPMate",
    products: [
        .executable(name: "SPMate", targets: ["SPMate"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/jpsim/SourceKitten", exact: "0.32.0"),
        .package(url: "https://github.com/KittyMac/Hitch.git", from: "0.4.0"),
        .package(url: "https://github.com/KittyMac/Spanker.git", from: "0.2.0"),
        .package(url: "https://github.com/KittyMac/Studding.git", from: "0.0.11"),
        .package(url: "https://github.com/KittyMac/Sextant.git", from: "0.4.0"),
        .package(url: "https://github.com/KittyMac/Flynn.git", from: "0.4.0")
    ],
    targets: [
        .executableTarget(
            name: "SPMate",
            dependencies: [
                "SPMateFramework",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "SPMateFramework",
            dependencies: [
                "Hitch",
                "Studding",
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
            dependencies: [ "SPMate" ],
            path: "Tests/NotRealTests"
        )
    ]
)
