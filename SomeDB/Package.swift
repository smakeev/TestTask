// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SomeDB",
    platforms: [
        .iOS(.v15), .macOS(.v12)
    ],
    products: [
        .library(name: "SomeDB", targets: ["SomeDB"])
    ],
    targets: [
        .target(
            name: "SomeDB",
            path: "Sources"
        )
    ]
)
