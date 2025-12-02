// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let name: String = "SPFKMetadataXMP" // Swift target
let dependencyNames: [String] = ["SPFKBase", "SPFKTime", "SPFKUtils", "SPFKTesting"]
let dependencyNamesC: [String] = []
let dependencyBranch: String = "development"

let platforms: [PackageDescription.SupportedPlatform]? = [
    .macOS(.v12)
]

let remoteDependencies: [RemoteDependency] = []

// Special case for local binary targets
let binaryTargetNames = ["XMPCore", "XMPFiles"]

var cTargetDependencies: [PackageDescription.Target.Dependency] {
    binaryTargetNames.map {
        .target(name: $0)
    }
}

let binaryTargets: [PackageDescription.Target] =
    binaryTargetNames.map {
        PackageDescription.Target.binaryTarget(
            name: $0,
            path: "Frameworks/\($0).xcframework"
        )
    }

// MARK: - Reusable Code for a dual Swift + C package

let spfkVersion: Version = .init(0, 0, 1)

struct RemoteDependency {
    let package: PackageDescription.Package.Dependency
    let product: PackageDescription.Target.Dependency
}

let nameC: String = "\(name)C" // C/C++ target
let nameTests: String = "\(name)Tests" // Test target
let githubBase = "https://github.com/ryanfrancesconi"

let products: [PackageDescription.Product] = [
    .library(name: name, targets: [name, nameC])
]

let packageDependencies: [PackageDescription.Package.Dependency] = {
    let value: [PackageDescription.Package.Dependency] =
        dependencyNames.map {
            .package(url: "\(githubBase)/\($0)", from: spfkVersion)
        }

    return value + remoteDependencies.map(\.package)
}()

var swiftTargetDependencies: [PackageDescription.Target.Dependency] {
    let names = dependencyNames.filter { $0 != "SPFKTesting" }

    var value: [PackageDescription.Target.Dependency] = names.map {
        .byNameItem(name: "\($0)", condition: nil)
    }

    value.append(.target(name: nameC))
    value.append(contentsOf: remoteDependencies.map(\.product))

    return value
}

let swiftTarget: PackageDescription.Target = .target(
    name: name,
    dependencies: swiftTargetDependencies,
    resources: nil
)

var testTargetDependencies: [PackageDescription.Target.Dependency] {
    var array: [PackageDescription.Target.Dependency] = [
        .byNameItem(name: name, condition: nil),
        .byNameItem(name: nameC, condition: nil)
    ]

    if dependencyNames.contains("SPFKTesting") {
        array.append(.byNameItem(name: "SPFKTesting", condition: nil))
    }

    return array
}

let testTarget: PackageDescription.Target = .testTarget(
    name: nameTests,
    dependencies: testTargetDependencies,
    resources: [.process("Resources")]
)

let cTarget: PackageDescription.Target = .target(
    name: nameC,
    dependencies: cTargetDependencies,
    publicHeadersPath: "include",
    cSettings: [
        .headerSearchPath("include_private")
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
    ]
)

let targets: [PackageDescription.Target] = [
    swiftTarget, cTarget, testTarget
]

let package = Package(
    name: name,
    defaultLocalization: "en",
    platforms: platforms,
    products: products,
    dependencies: packageDependencies,
    targets: targets + binaryTargets,
    cxxLanguageStandard: .cxx20
)
