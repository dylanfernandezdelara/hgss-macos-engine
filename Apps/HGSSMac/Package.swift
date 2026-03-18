// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HGSSMac",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(name: "HGSSEngine", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "HGSSMac",
            dependencies: [
                .product(name: "HGSSCore", package: "HGSSEngine"),
                .product(name: "HGSSRender", package: "HGSSEngine"),
                .product(name: "HGSSOpeningIR", package: "HGSSEngine")
            ],
            path: "Sources/HGSSMacApp"
        )
    ]
)
