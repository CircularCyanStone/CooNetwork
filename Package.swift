// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CooNetwork",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "CooNetwork",
            type: .dynamic,
            targets: ["CooNetwork"]
        ),
        .library(name: "AlamofireClient", targets: ["AlamofireClient"])
    ],
    dependencies: [
        // 1. 在这里添加 Alamofire 的远程仓库地址
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.10.0"))
    ],
    targets: [
        .target(
            name: "CooNetwork"
        ),
        .target(
            name: "AlamofireClient",
            dependencies: [
                .target(name: "CooNetwork"),
                // 2. 在这里将 Alamofire 库绑定到你的 target 上
                .product(name: "Alamofire", package: "Alamofire")
            ]
        ),
        .testTarget(
            name: "CooNetworkTests",
            dependencies: ["CooNetwork"]
        ),
    ]
)
