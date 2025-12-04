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

/*
 let name: String = "SPFKMetadataXMP" // Swift target
 var localDependencies: [RemoteDependency] { [
     .init(package: .package(url: "\(githubBase)/spfk-base", from: "0.0.1"),
           product: .product(name: "SPFKBase", package: "spfk-base")),
     .init(package: .package(url: "\(githubBase)/spfk-time", from: "0.0.1"),
           product: .product(name: "SPFKTime", package: "spfk-time")),
     .init(package: .package(url: "\(githubBase)/spfk-testing", from: "0.0.1"),
           product: .product(name: "SPFKTesting", package: "spfk-testing")),
     .init(package: .package(url: "\(githubBase)/spfk-utils", from: "0.0.1"),
           product: .product(name: "SPFKUtils", package: "spfk-utils")),
 ] }

 let remoteDependencies: [RemoteDependency] = []
 let resources: [PackageDescription.Resource]? = nil
 let testResources: [PackageDescription.Resource]? = [.process("Resources")]

 // C/C++ target, nil if no C target
 let nameC: String? = "\(name)C"
 let dependencyNamesC: [String] = []
 let remoteDependenciesC: [RemoteDependency] = [] // 3rd party
 var cSettings: [PackageDescription.CSetting]? { [
     .headerSearchPath("include_private")
 ] }
 var cxxSettings: [PackageDescription.CXXSetting]? { [
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
 ] }

 let platforms: [PackageDescription.SupportedPlatform]? = [
     .macOS(.v12)
 ]

 // MARK: - the binary targets create additional inclusion below that most packages don't have

 // Special case for local binary targets
 let binaryTargetNames = ["XMPCore", "XMPFiles"]

 var cTargetBinaryDependencies: [PackageDescription.Target.Dependency] {
     binaryTargetNames.map { .target(name: $0) }
 }

 let binaryTargets: [PackageDescription.Target] =
     binaryTargetNames.map {
         PackageDescription.Target.binaryTarget(
             name: $0,
             path: "Frameworks/\($0).xcframework"
         )
     }

 /
 */
