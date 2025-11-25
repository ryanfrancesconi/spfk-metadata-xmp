// swift-tools-version: 6.2.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

private let name: String = "SPFKMetadataXMP" // Swift target
private let dependencyNames: [String] = ["SPFKBase", "SPFKTime", "SPFKUtils", "SPFKTesting"]
private let dependencyNamesC: [String] = []
private let dependencyBranch = "main"
private let useLocalDependencies: Bool = false
private let platforms: [PackageDescription.SupportedPlatform]? = [
    .macOS(.v12)
]

let remoteDependencies: [RemoteDependency] = []

// Special case for local binary targets
let binaryTargetNames = ["XMPCore", "XMPFiles"]

private var cTargetDependencies: [PackageDescription.Target.Dependency] {
    binaryTargetNames.map {
        .target(name: $0)
    }
}

private let binaryTargets: [PackageDescription.Target] =
    binaryTargetNames.map {
        PackageDescription.Target.binaryTarget(
            name: $0,
            path: "Frameworks/\($0).xcframework"
        )
    }

// MARK: - Reusable Code for a dual Swift + C package

struct RemoteDependency {
    let package: PackageDescription.Package.Dependency
    let product: PackageDescription.Target.Dependency
}

private let nameC: String = "\(name)C" // C/C++ target
private let nameTests: String = "\(name)Tests" // Test target
private let githubBase = "https://github.com/ryanfrancesconi"

private let products: [PackageDescription.Product] = [
    .library(name: name, targets: [name, nameC])
]

private var packageDependencies: [PackageDescription.Package.Dependency] {
    let local: [PackageDescription.Package.Dependency] =
        dependencyNames.map {
            .package(name: "\($0)", path: "../\($0)") // assumes the package garden is in one folder
        }

    let remote: [PackageDescription.Package.Dependency] =
        dependencyNames.map {
            .package(url: "\(githubBase)/\($0)", branch: dependencyBranch)
        }

    var value = useLocalDependencies ? local : remote

    if !remoteDependencies.isEmpty {
        value.append(contentsOf: remoteDependencies.map { $0.package })
    }

    return value
}

private var swiftTargetDependencies: [PackageDescription.Target.Dependency] {
    let names = dependencyNames.filter { $0 != "SPFKTesting" }

    var value: [PackageDescription.Target.Dependency] = names.map {
        .byNameItem(name: "\($0)", condition: nil)
    }

    value.append(.target(name: nameC))

    if !remoteDependencies.isEmpty {
        value.append(contentsOf: remoteDependencies.map { $0.product })
    }

    return value
}

private let swiftTarget: PackageDescription.Target = .target(
    name: name,
    dependencies: swiftTargetDependencies,
    resources: nil
)

private var testTargetDependencies: [PackageDescription.Target.Dependency] {
    var array: [PackageDescription.Target.Dependency] = [
        .byNameItem(name: name, condition: nil),
        .byNameItem(name: nameC, condition: nil)
    ]

    if dependencyNames.contains("SPFKTesting") {
        array.append(.byNameItem(name: "SPFKTesting", condition: nil))
    }

    return array
}

private let testTarget: PackageDescription.Target = .testTarget(
    name: nameTests,
    dependencies: testTargetDependencies,
    resources: [.process("Resources")]
)

private let cTarget: PackageDescription.Target = .target(
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

private let targets: [PackageDescription.Target] = [
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
