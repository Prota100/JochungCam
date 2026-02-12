// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JochungCam",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "JochungCam", targets: ["JochungCam"])
    ],
    targets: [
        .systemLibrary(
            name: "CImageQuant",
            pkgConfig: "imagequant",
            providers: [.brew(["libimagequant"])]
        ),
        .executableTarget(
            name: "JochungCam",
            dependencies: ["CImageQuant"],
            path: "Sources/JochungCam",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreImage"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedLibrary("imagequant"),
                .unsafeFlags(["-L/opt/homebrew/lib"]),
            ]
        )
    ]
)
