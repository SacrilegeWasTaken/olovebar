// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "OLoveBar",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "olovebar",
            targets: ["OLoveBar"]
        ),
        .library(
            name: "Macro", 
            targets: ["Macro"]
        )
    ],
    dependencies: [
        // SwiftSyntax 
        .package(url: "https://github.com/apple/swift-syntax.git", from: "602.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "OLoveBar",
            dependencies: ["Widgets", "Utilities"],
            path: "Sources/OLoveBar"
        ),
        .macro(
            name: "Macro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"), 
            ],
            path: "Sources/Macro"
        ),
        .target(
            name: "Widgets",
            dependencies: ["Utilities", "Macro"],
            path: "Sources/Widgets"
        ),
        .target(
            name: "Utilities",
            dependencies: ["Macro"],
            path: "Sources/Utilities"
        )
    ]

)