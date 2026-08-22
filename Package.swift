// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "diskinfo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "diskinfo", targets: ["diskinfo"]),
        .executable(name: "DiskInfo", targets: ["DiskInfo"])
    ],
    targets: [
        .executableTarget(
            name: "diskinfo",
            path: "Sources/diskinfo"
        ),
        .executableTarget(
            name: "DiskInfo",
            path: "Sources/DiskInfo"
        )
    ]
)
