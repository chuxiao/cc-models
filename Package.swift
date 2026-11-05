// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ccmodel",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ccmodel",
            path: "Sources/ccmodel"
        ),
        .testTarget(
            name: "ccmodelTests",
            dependencies: ["ccmodel"],
            path: "Tests/ccmodelTests"
        )
    ]
)
