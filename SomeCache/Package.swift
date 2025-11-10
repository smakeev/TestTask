// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SomeCache",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "SomeCache", targets: ["SomeCache"])
    ],
    targets: [
        .target(
            name: "SomeCache",
            path: "Sources"
        )
    ]
)
