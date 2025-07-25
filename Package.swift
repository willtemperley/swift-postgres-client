// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftPostgresClient",
    platforms: [
        .macOS(.v11), .iOS(.v14), .tvOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftPostgresClient",
            targets: ["SwiftPostgresClient"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftPostgresClient"),
        .testTarget(
            name: "SwiftPostgresClientTests",
            dependencies: ["SwiftPostgresClient"]
        ),
    ]
)
