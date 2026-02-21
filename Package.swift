// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-metadata-xmp",
    defaultLocalization: "en",
    platforms: [.macOS(.v12),],
    products: [
        .library(
            name: "SPFKMetadataXMP",
            targets: ["SPFKMetadataXMP", "SPFKMetadataXMPC",]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-base", from: "0.0.3"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-time", from: "0.0.1"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-utils", from: "0.0.3"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "SPFKMetadataXMP",
            dependencies: [
                .targetItem(name: "SPFKMetadataXMPC", condition: nil),
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
                .headerSearchPath("Adobe/XMPCore/Interfaces"),
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
                .targetItem(name: "SPFKMetadataXMP", condition: nil),
                .targetItem(name: "SPFKMetadataXMPC", condition: nil),
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
