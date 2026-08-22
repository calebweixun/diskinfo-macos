// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "diskinfo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "diskinfo", targets: ["diskinfo"])
    ],
    targets: [
        .executableTarget(
            name: "diskinfo",
            path: "Sources/diskinfo"
        ),
        .testTarget(
            name: "diskinfoTests",
            dependencies: ["diskinfo"],
            path: "Tests/diskinfoTests"
        )
    ]
)
