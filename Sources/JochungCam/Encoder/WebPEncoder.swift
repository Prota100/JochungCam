import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Animated WebP encoder using cwebp + webpmux CLI (same approach as JochungCam's XLibWebP/XWebpMux)
enum WebPEncoder {
    struct Options {
        var quality: Int = 85       // 0-100
        var lossless: Bool = false
        var fps: Int = 60
        var loopCount: Int = 0      // 0 = infinite
        var maxWidth: Int = 0
    }

    static let cwebpPath: String? = {
        let candidates = [Bundle.main.resourcePath.map { $0 + "/bin/cwebp" }, "/opt/homebrew/bin/cwebp", "/usr/local/bin/cwebp"].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()
    static let webpmuxPath: String? = {
        let candidates = [Bundle.main.resourcePath.map { $0 + "/bin/webpmux" }, "/opt/homebrew/bin/webpmux", "/usr/local/bin/webpmux"].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()
    static var isAvailable: Bool { cwebpPath != nil && webpmuxPath != nil }

    static func encode(frames: [GIFFrame], to outputURL: URL, options: Options, progress: @Sendable @escaping (Double) -> Void) throws {
        guard let cwebp = cwebpPath, let webpmux = webpmuxPath else { throw WebPError.notInstalled }
        guard !frames.isEmpty else { throw WebPError.noFrames }

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("jc_webp_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Step 1: Write each frame as PNG, encode to individual WebP
        var webpFiles: [(path: String, durationMs: Int)] = []
        for (i, frame) in frames.enumerated() {
            let pngURL = tmpDir.appendingPathComponent("f_\(String(format: "%05d", i)).png")
            try writePNG(frame.image, to: pngURL)

            let webpURL = tmpDir.appendingPathComponent("f_\(String(format: "%05d", i)).webp")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: cwebp)
            var args = ["-q", "\(options.quality)"]
            if options.lossless { args += ["-lossless"] }
            if options.maxWidth > 0 { args += ["-resize", "\(options.maxWidth)", "0"] }
            args += [pngURL.path, "-o", webpURL.path]
            proc.arguments = args
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try proc.run(); proc.waitUntilExit()

            let ms = max(1, Int(frame.duration * 1000))
            webpFiles.append((webpURL.path, ms))
            progress(Double(i + 1) / Double(frames.count) * 0.8)
        }

        // Step 2: Mux into animated WebP
        var muxArgs: [String] = []
        for (path, ms) in webpFiles {
            muxArgs += ["-frame", path, "+\(ms)+0+0+0"]
        }
        muxArgs += ["-loop", "\(options.loopCount)", "-o", outputURL.path]

        let mux = Process()
        mux.executableURL = URL(fileURLWithPath: webpmux)
        mux.arguments = muxArgs
        mux.standardOutput = FileHandle.nullDevice
        mux.standardError = FileHandle.nullDevice
        try mux.run(); mux.waitUntilExit()

        if mux.terminationStatus != 0 {
            throw WebPError.muxFailed
        }
        progress(1.0)
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw WebPError.pngFailed }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw WebPError.pngFailed }
    }
}

enum WebPError: Error, LocalizedError {
    case notInstalled, noFrames, muxFailed, pngFailed
    var errorDescription: String? {
        switch self {
        case .notInstalled: "WebP 도구가 없습니다 (brew install webp)"
        case .noFrames: "프레임 없음"
        case .muxFailed: "WebP 합성 실패"
        case .pngFailed: "PNG 쓰기 실패"
        }
    }
}
