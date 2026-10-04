// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "BridgeCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "BridgeCore", targets: ["BridgeCore"])],
    targets: [
        .target(name: "BridgeCore", path: "ios/Bridge/Core"),
        .testTarget(name: "BridgeCoreTests", dependencies: ["BridgeCore"], path: "Tests/BridgeCoreTests")
    ]
)
