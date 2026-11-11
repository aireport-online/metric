// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MetricCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MetricCore", targets: ["MetricCore"]),
    ],
    targets: [
        .target(name: "MetricCore"),
        .testTarget(name: "MetricCoreTests", dependencies: ["MetricCore"]),
    ]
)
