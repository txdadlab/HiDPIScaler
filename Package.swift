// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HiDPIScaler",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "CGVirtualDisplayBridge",
            dependencies: [],
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-fno-objc-arc"]),
            ],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation"),
            ]
        ),
        .executableTarget(
            name: "HiDPIScaler",
            dependencies: [
                "CGVirtualDisplayBridge",
            ],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
