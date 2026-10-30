// swift-tools-version: 6.2
import Foundation
import PackageDescription

// The code shared with the s-family: the sibling checkout when there is one,
// else the published package.
let sibling = URL(fileURLWithPath: Context.packageDirectory)
    .deletingLastPathComponent()
    .appendingPathComponent("scommon/Package.swift")
let scommon: Package.Dependency = FileManager.default.fileExists(atPath: sibling.path)
    ? .package(path: "../scommon")
    : .package(
        url: "https://github.com/uSuite/scommon.git",
        from: "0.3.0"
    )

let package = Package(
    name: "sCapture",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "SCaptureCore",
            targets: ["SCaptureCore"]
        ),
        .executable(
            name: "sCapture",
            targets: ["sCapture"]
        ),
    ],
    dependencies: [
        scommon
    ],
    targets: [
        .target(
            name: "SCaptureCore",
            dependencies: [
                .product(
                    name: "SCommon",
                    package: "scommon"
                )
            ]
        ),
        .executableTarget(
            name: "sCapture",
            dependencies: ["SCaptureCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "SCaptureCoreTests",
            dependencies: ["SCaptureCore"]
        ),
    ]
)
