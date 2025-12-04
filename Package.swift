// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-metadata-xmp",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "SPFKMetadataXMP",
            targets: [
                "SPFKMetadataXMP",
                "SPFKMetadataXMPC",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-base", branch: "development"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-time", branch: "development"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-utils", branch: "development"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", branch: "development"),
    ],
    targets: [
        .target(
            name: "SPFKMetadataXMP",
            dependencies: [
                "SPFKMetadataXMPC",
                .product(name: "SPFKBase", package: "spfk-base"),
                .product(name: "SPFKTime", package: "spfk-time"),
                .product(name: "SPFKUtils", package: "spfk-utils"),
            ]
        ),

        .target(
            name: "SPFKMetadataXMPC",
            dependencies: [
                .target(name: "XMPCore"),
                .target(name: "XMPFiles"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include_private")
            ],
            cxxSettings: [
                .headerSearchPath("include_private"),
                .headerSearchPath("Adobe"),
                .headerSearchPath("Adobe/client-glue"),
                .headerSearchPath("Adobe/XMPCommon"),
                .headerSearchPath("Adobe/XMPCore"),
                .headerSearchPath("Adobe/XMPCommon/Interfaces"),
                .headerSearchPath("Adobe/XMPCommon/Utilities"),
                .headerSearchPath("Adobe/XMPCommon/Interfaces/BaseInterfaces"),
                .headerSearchPath("Adobe/XMPCore/Interfaces")
            ]
        ),

        .binaryTarget(
            name: "XMPCore",
            path: "Frameworks/XMPCore.xcframework"
        ),
        .binaryTarget(
            name: "XMPFiles",
            path: "Frameworks/XMPFiles.xcframework"
        ),

        .testTarget(
            name: "SPFKMetadataXMPTests",
            dependencies: [
                "SPFKMetadataXMP",
                "SPFKMetadataXMPC",
                .product(name: "SPFKTesting", package: "spfk-testing"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-strict-concurrency=complete"]),
            ],
        ),
    ],
    cxxLanguageStandard: .cxx20
)
