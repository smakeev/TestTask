// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "Persistence", targets: ["Persistence"])
    ],
        dependencies: [
        .package(path: "../SomeCache"),
            .package(path: "../SomeDB"),
],

targets: [
        .target(
            name: "Persistence",
            dependencies: [.product(name: "SomeDB", package: "SomeDB"), .product(name: "SomeCache", package: "SomeCache"), ]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence"],
            path: "Tests/PersistenceTests"
        )
    ]
)
