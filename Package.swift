// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Swift target
private let name: String = "SPFKMetadataXMP"

// C/C++ target
private let nameC: String = "\(name)C"

private let platforms: [PackageDescription.SupportedPlatform]? = [
    .macOS(.v12)
]

private let products: [PackageDescription.Product] = [
    .library(
        name: name,
        targets: [name, nameC]
    )
]

private let dependencies: [PackageDescription.Package.Dependency] = [
    .package(name: "SPFKUtils", path: "../SPFKUtils"),
    .package(name: "SPFKTime", path: "../SPFKTime"),
    .package(name: "SPFKTesting", path: "../SPFKTesting"),
]

private let targets: [PackageDescription.Target] = [
    // Swift
    .target(
        name: name,
        dependencies: [
            .target(name: nameC),
            .byNameItem(name: "SPFKUtils", condition: nil),
            .byNameItem(name: "SPFKTime", condition: nil),
        ],
    ),
    
    // C
    .target(
        name: nameC,
        dependencies: [
            .target(name: "XMPCore"),
            .target(name: "XMPFiles"),
        ],
        publicHeadersPath: "include",
        cSettings: [
            .headerSearchPath("include_private"),
        ],
        cxxSettings: [
            // Xcode resolves relative to the target root
            .headerSearchPath("include_private"),
            .headerSearchPath("Adobe"),
            .headerSearchPath("Adobe/client-glue"),
            .headerSearchPath("Adobe/XMPCommon"),
            .headerSearchPath("Adobe/XMPCore"),
            .headerSearchPath("Adobe/XMPCommon/Interfaces"),
            .headerSearchPath("Adobe/XMPCommon/Utilities"),
            .headerSearchPath("Adobe/XMPCommon/Interfaces/BaseInterfaces"),
            .headerSearchPath("Adobe/XMPCore/Interfaces")
        ],
    ),
    
    .binaryTarget(
        name: "XMPCore",
        path: "Frameworks/XMPCore.xcframework" // relative to the package root
    ),

    .binaryTarget(
        name: "XMPFiles",
        path: "Frameworks/XMPFiles.xcframework" // relative to the package root
    ),

    .testTarget(
        name: "\(name)Tests",
        dependencies: [
            .byNameItem(name: name, condition: nil),
            .byNameItem(name: nameC, condition: nil),
            .byNameItem(name: "SPFKTesting", condition: nil)
        ],
        resources: [
            .process("Resources")
        ],
    )
]

let package = Package(
    name: name,
    defaultLocalization: "en",
    platforms: platforms,
    products: products,
    dependencies: dependencies,
    targets: targets,
    cxxLanguageStandard: .cxx20,
)
