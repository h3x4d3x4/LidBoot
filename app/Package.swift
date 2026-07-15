// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LidBoot",
    platforms: [
        // BootPreference does not exist before macOS 15 (Sequoia).
        // String form: the `.v15` enum case needs swift-tools-version 6.0.
        .macOS("15.0")
    ],
    products: [
        .library(name: "LidBootCore", targets: ["LidBootCore"])
    ],
    targets: [
        .target(name: "LidBootCore"),
        .testTarget(name: "LidBootCoreTests", dependencies: ["LidBootCore"])
    ]
)
