// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AuroraScreenshot",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "AuroraScreenshot", targets: ["AuroraScreenshot"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AuroraScreenshot",
            dependencies: [],
            path: "Sources"
        )
    ]
)
