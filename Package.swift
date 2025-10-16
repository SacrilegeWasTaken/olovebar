// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "OLoveBar",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        // 👇 Макросы теперь доступны как отдельный API-модуль
        .library(name: "MacroAPI", targets: ["MacroAPI"]),
        .executable(name: "olovebar", targets: ["OLoveBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0")
    ],
    targets: [
        // MARK: - Macro Plugin (реализация)
        .macro(
            name: "MacroPlugin",
            dependencies: [
                "Utilities",
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),

        // MARK: - Macro API (интерфейс)
        .target(
            name: "MacroAPI",
            dependencies: [
                "Utilities",
                "MacroPlugin"
            ]
        ),

        // MARK: - Utilities
        .target(
            name: "Utilities",
            dependencies: []
        ),



        // MARK: - Исполняемый таргет
        .executableTarget(
            name: "OLoveBar",
            dependencies: ["Utilities", "MacroAPI", "TOMLKit"]
        )
    ]
)
