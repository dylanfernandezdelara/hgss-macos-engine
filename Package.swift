// swift-tools-version: 5.10
import Foundation
import PackageDescription

let llvmPrefix = resolvedLLVMPrefix()
let llvmIncludePath = "\(llvmPrefix)/include"
let llvmLibraryPath = "\(llvmPrefix)/lib"
let libclangLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-L", llvmLibraryPath]),
    .linkedLibrary("clang"),
]
let libclangSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-Xcc", "-I\(llvmIncludePath)"]),
]

let package = Package(
    name: "HGSSEngine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "HGSSDataModel", targets: ["HGSSDataModel"]),
        .library(name: "HGSSOpeningIR", targets: ["HGSSOpeningIR"]),
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
            name: "CClangC",
            path: "Sources/CClangC",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-I", llvmIncludePath]),
            ]
        ),
        .target(
            name: "HGSSDataModel",
            path: "Sources/HGSSDataModel"
        ),
        .target(
            name: "HGSSOpeningIR",
            path: "Sources/HGSSOpeningIR"
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
            dependencies: ["HGSSCore", "HGSSDataModel", "HGSSOpeningIR"],
            path: "Sources/HGSSRender"
        ),
        .executableTarget(
            name: "HGSSExtractCLI",
            dependencies: ["CClangC", "HGSSContent", "HGSSDataModel", "HGSSOpeningIR"],
            path: "Sources/HGSSExtractCLI",
            swiftSettings: libclangSwiftSettings,
            linkerSettings: libclangLinkerSettings
        ),
        .testTarget(
            name: "HGSSOpeningIRTests",
            dependencies: [
                "HGSSOpeningIR",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/HGSSOpeningIRTests"
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
                "HGSSOpeningIR",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/HGSSRenderTests"
        ),
        .testTarget(
            name: "HGSSExtractCLITests",
            dependencies: [
                "HGSSExtractCLI",
                "HGSSDataModel",
                "HGSSOpeningIR",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/HGSSExtractCLITests",
            swiftSettings: libclangSwiftSettings,
            linkerSettings: libclangLinkerSettings
        )
    ]
)

private func resolvedLLVMPrefix() -> String {
    if let environmentPrefix = ProcessInfo.processInfo.environment["LLVM_PREFIX"], !environmentPrefix.isEmpty {
        return environmentPrefix
    }

    let candidatePrefixes = [
        "/opt/homebrew/opt/llvm",
        "/usr/local/opt/llvm",
        "/opt/local/libexec/llvm-22",
        "/opt/local/libexec/llvm-21",
    ]
    let fileManager = FileManager.default

    for prefix in candidatePrefixes {
        let headerPath = "\(prefix)/include/clang-c/Index.h"
        if fileManager.fileExists(atPath: headerPath) {
            return prefix
        }
    }

    fatalError(
        """
        Unable to locate an LLVM install that provides clang-c/Index.h.
        Set LLVM_PREFIX to the LLVM/Homebrew prefix, for example:
          export LLVM_PREFIX=/opt/homebrew/opt/llvm
        """
    )
}
