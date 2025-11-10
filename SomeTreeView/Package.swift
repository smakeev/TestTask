// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SomeTreeView",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "SomeTreeView", targets: ["SomeTreeView"])
    ],
    targets: [
        .target(
            name: "SomeTreeView",
            path: "Sources"
        ),
        .executableTarget(
            name: "TreeViewDemo",
            dependencies: ["SomeTreeView"], 
            path: "Examples/TreeViewDemo"
        )
    ]
)
