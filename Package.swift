// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NtkNetwork",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NtkNetwork",
            targets: ["NtkNetwork"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NtkNetwork",
            // 使用 path 参数来指定源代码的路径
            path: "Sources/NtkNetwork"
        ),
        .testTarget(
            name: "NtkNetworkTests",
            dependencies: ["NtkNetwork"]
        ),
    ]
)
