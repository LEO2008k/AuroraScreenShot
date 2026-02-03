// swift-tools-version:5.5
// This program was developed by Levko Kravchuk with the help of Vibe Coding
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
