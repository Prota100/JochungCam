// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JocungCam",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "JocungCam", targets: ["JocungCam"])
    ],
    targets: [
        .systemLibrary(
            name: "CImageQuant",
            pkgConfig: "imagequant",
            providers: [.brew(["libimagequant"])]
        ),
        .executableTarget(
            name: "JocungCam",
            dependencies: ["CImageQuant"],
            path: "Sources/JocungCam",
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
