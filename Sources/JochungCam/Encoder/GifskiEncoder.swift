import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// High-quality GIF encoder using gifski CLI (cross-frame palette optimization)
enum GifskiEncoder {
    struct Options {
        var fps: Int = 60
        var quality: Int = 90       // 1-100
        var maxWidth: Int = 0       // 0 = keep
        var maxHeight: Int = 0
        var loopCount: Int = 0      // 0 = infinite
        var fast: Bool = false      // fast mode (lower quality, faster)
    }

    static let gifskiPath: String? = {
        let candidates = [
            Bundle.main.resourcePath.map { $0 + "/bin/gifski" },
            "/opt/homebrew/bin/gifski",
            "/usr/local/bin/gifski",
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    static var isAvailable: Bool { gifskiPath != nil }

    /// Encode frames using gifski CLI for maximum quality
    static func encode(
        frames: [GIFFrame],
        to outputURL: URL,
        options: Options,
        progress: @Sendable @escaping (Double) -> Void
    ) throws {
        guard let gifski = gifskiPath else { throw GifskiError.notInstalled }
        guard !frames.isEmpty else { throw GifskiError.noFrames }

        // Create temp directory for PNG frames
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("jc_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Write frames as PNGs
        for (i, frame) in frames.enumerated() {
            let url = tmpDir.appendingPathComponent(String(format: "frame_%05d.png", i))
            try writePNG(frame.image, to: url)
            progress(Double(i + 1) / Double(frames.count) * 0.5) // First 50% = writing PNGs
        }

        // Build gifski command
        var args = [
            "--fps", "\(options.fps)",
            "--quality", "\(options.quality)",
            "-o", outputURL.path
        ]

        if options.maxWidth > 0 { args += ["--width", "\(options.maxWidth)"] }
        if options.maxHeight > 0 { args += ["--height", "\(options.maxHeight)"] }
        if options.loopCount != 0 { args += ["--repeat", "\(options.loopCount)"] }
        if options.fast { args += ["--fast"] }

        // Add frame PNGs
        let framePaths = try FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { $0.path }
        args += framePaths

        // Run gifski
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gifski)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        // Monitor progress (gifski outputs progress to stderr)
        progress(0.5) // Start of encoding phase

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw GifskiError.encodeFailed(output)
        }

        progress(1.0)
    }

    /// Encode to Data
    static func encodeToData(frames: [GIFFrame], options: Options) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("jc_\(UUID().uuidString).gif")
        try encode(frames: frames, to: tmp, options: options) { _ in }
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try Data(contentsOf: tmp)
    }

    // MARK: - PNG Writer

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { throw GifskiError.pngWriteFailed }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw GifskiError.pngWriteFailed }
    }
}

enum GifskiError: Error, LocalizedError {
    case notInstalled
    case noFrames
    case encodeFailed(String)
    case pngWriteFailed

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "gifski가 설치되어 있지 않습니다 (brew install gifski)"
        case .noFrames: return "프레임 없음"
        case .encodeFailed(let msg): return "gifski 인코딩 실패: \(msg)"
        case .pngWriteFailed: return "PNG 쓰기 실패"
        }
    }
}
