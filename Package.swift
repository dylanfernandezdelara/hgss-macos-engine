// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HGSSEngine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "HGSSDataModel", targets: ["HGSSDataModel"]),
        .library(name: "HGSSContent", targets: ["HGSSContent"]),
        .library(name: "HGSSTelemetry", targets: ["HGSSTelemetry"]),
        .library(name: "HGSSCore", targets: ["HGSSCore"]),
        .library(name: "HGSSRender", targets: ["HGSSRender"]),
        .executable(name: "HGSSExtractCLI", targets: ["HGSSExtractCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "HGSSDataModel",
            path: "Sources/HGSSDataModel"
        ),
        .target(
            name: "HGSSContent",
            dependencies: ["HGSSDataModel"],
            path: "Sources/HGSSContent",
            sources: ["StubContentLoader.swift", "StubWorldContent.swift", "PretNewBarkNormalization.swift"]
        ),
        .target(
            name: "HGSSTelemetry",
            path: "Sources/HGSSTelemetry"
        ),
        .target(
            name: "HGSSCore",
            dependencies: ["HGSSContent", "HGSSDataModel", "HGSSTelemetry"],
            path: "Sources/HGSSCore"
        ),
        .target(
            name: "HGSSRender",
            dependencies: ["HGSSCore", "HGSSDataModel"],
            path: "Sources/HGSSRender"
        ),
        .executableTarget(
            name: "HGSSExtractCLI",
            dependencies: ["HGSSContent", "HGSSDataModel"],
            path: "Sources/HGSSExtractCLI"
        ),
        .testTarget(
            name: "HGSSContentTests",
            dependencies: [
                "HGSSContent",
                "HGSSDataModel",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/HGSSContentTests"
        ),
        .testTarget(
            name: "HGSSCoreTests",
            dependencies: [
                "HGSSCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/HGSSCoreTests"
        ),
        .testTarget(
            name: "HGSSRenderTests",
            dependencies: [
                "HGSSRender",
                "HGSSDataModel",
                "HGSSCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/HGSSRenderTests"
        )
    ]
)
