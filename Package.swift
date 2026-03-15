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
        .library(name: "HGSSExtractSupport", targets: ["HGSSExtractSupport"]),
        .executable(name: "HGSSExtractCLI", targets: ["HGSSExtractCLI"])
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
            name: "HGSSExtractSupport",
            dependencies: ["HGSSContent", "HGSSDataModel"],
            path: "Sources/HGSSExtractSupport"
        ),
        .executableTarget(
            name: "HGSSExtractCLI",
            dependencies: ["HGSSDataModel", "HGSSExtractSupport"],
            path: "Sources/HGSSExtractCLI"
        ),
        .testTarget(
            name: "HGSSContentTests",
            dependencies: ["HGSSContent", "HGSSDataModel"],
            path: "Tests/HGSSContentTests"
        ),
        .testTarget(
            name: "HGSSCoreTests",
            dependencies: ["HGSSCore"],
            path: "Tests/HGSSCoreTests"
        ),
        .testTarget(
            name: "HGSSExtractCLITests",
            dependencies: ["HGSSExtractSupport", "HGSSDataModel"],
            path: "Tests/HGSSExtractCLITests"
        )
    ]
)
