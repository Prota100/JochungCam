import Foundation
import Testing
@testable import JochungCam

struct MOVExportE2ETests {

    struct Preset {
        let name: String
        let fps: Int
        let options: GIFEncoder.Options
    }

    @Test("heavy MOV import -> preset GIF exports produce artifacts")
    func heavyMOVToGIFPresets() async throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let movURL = cwd.appendingPathComponent("test_heavy.mov")
        #expect(FileManager.default.fileExists(atPath: movURL.path))

        let outDir = cwd.appendingPathComponent("release/mov-e2e", isDirectory: true)
        try? FileManager.default.removeItem(at: outDir)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let presets: [Preset] = [
            .init(name: "light", fps: 30, options: GIFEncoder.Options(maxColors: 64, dither: true, ditherLevel: 1.0, speed: 4, quality: 90, loopCount: 0, maxWidth: 500, maxFileSizeKB: 1000, removeSimilarPixels: true, centerFocusedDither: false, skipQuantizeWhenQ100: true)),
            .init(name: "normal", fps: 60, options: GIFEncoder.Options(maxColors: 128, dither: true, ditherLevel: 1.0, speed: 2, quality: 95, loopCount: 0, maxWidth: 800, maxFileSizeKB: 3000, removeSimilarPixels: true, centerFocusedDither: false, skipQuantizeWhenQ100: true)),
            .init(name: "discord", fps: 60, options: GIFEncoder.Options(maxColors: 256, dither: true, ditherLevel: 1.0, speed: 3, quality: 95, loopCount: 0, maxWidth: 720, maxFileSizeKB: 8000, removeSimilarPixels: true, centerFocusedDither: false, skipQuantizeWhenQ100: true)),
        ]

        var lines: [String] = []
        lines.append("preset,frames,sizeKB,elapsedSec")

        for preset in presets {
            let importStart = Date()
            let frames = await FrameOps.importVideo(from: movURL, fps: Double(preset.fps), progress: nil)
            let importedFrames = frames ?? []
            #expect(importedFrames.isEmpty == false)

            let out = outDir.appendingPathComponent("heavy_\(preset.name).gif")
            let encodeStart = Date()
            try await GIFEncoder.encode(frames: importedFrames, to: out, options: preset.options) { _ in }
            let elapsed = Date().timeIntervalSince(encodeStart)

            let attrs = try FileManager.default.attributesOfItem(atPath: out.path)
            let bytes = (attrs[.size] as? NSNumber)?.intValue ?? 0
            let sizeKB = bytes / 1024

            #expect(bytes > 0)
            let elapsedText = String(format: "%.2f", elapsed)
            lines.append("\(preset.name),\(importedFrames.count),\(sizeKB),\(elapsedText)")

            let importElapsed = Date().timeIntervalSince(importStart)
            let importElapsedText = String(format: "%.2f", importElapsed)
            print("[MOV E2E] \(preset.name): frames=\(importedFrames.count), sizeKB=\(sizeKB), totalSec=\(importElapsedText)")
        }

        let report = outDir.appendingPathComponent("report.csv")
        try lines.joined(separator: "\n").write(to: report, atomically: true, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: report.path))
    }
}
