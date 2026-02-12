import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
import AppKit
import CImageQuant

enum GIFEncoder {
    struct Options {
        var maxColors: Int = 256
        var dither: Bool = true
        var ditherLevel: Float = 1.0
        var speed: Int = 4            // liq_set_speed 1-10 (꿀캠 기본 4)
        var quality: Int = 90         // liq_set_quality min-max (꿀캠 IDC_EDIT_GIF_QUANT_QUALITY)
        var loopCount: Int = 0
        var maxWidth: Int = 0
        var maxFileSizeKB: Int = 0
        var removeSimilarPixels: Bool = false
        var centerFocusedDither: Bool = false
        var skipQuantizeWhenQ100: Bool = true
    }

    static func encode(frames: [GIFFrame], to url: URL, options: Options, progress: @Sendable @escaping (Double) -> Void) throws {
        guard !frames.isEmpty else { throw EncodeError.noFrames }
        var processed = options.maxWidth > 0 ? resizeFrames(frames, maxWidth: options.maxWidth) : frames

        if options.removeSimilarPixels {
            FrameOps.removeSimilar(threshold: 3, frames: &processed)
        }

        try writeGIF(processed, to: url, options: options, progress: progress)

        // File size limit: iteratively reduce quality
        if options.maxFileSizeKB > 0 {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            if size / 1024 > options.maxFileSizeKB {
                var reduced = options
                reduced.maxColors = max(16, options.maxColors / 2)
                reduced.maxFileSizeKB = 0
                try writeGIF(processed, to: url, options: reduced, progress: progress)
            }
        }
    }

    static func encodeToData(frames: [GIFFrame], options: Options) throws -> Data {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("jc_\(UUID().uuidString).gif")
        try encode(frames: frames, to: tmp, options: options) { _ in }
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try Data(contentsOf: tmp)
    }

    private static func writeGIF(_ frames: [GIFFrame], to url: URL, options: Options, progress: @Sendable @escaping (Double) -> Void) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { throw EncodeError.createFailed }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: options.loopCount]] as CFDictionary)

        for (i, frame) in frames.enumerated() {
            let q = quantize(frame.image, options: options)
            CGImageDestinationAddImage(dest, q, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frame.duration, kCGImagePropertyGIFUnclampedDelayTime: frame.duration]] as CFDictionary)
            progress(Double(i+1) / Double(frames.count))
        }
        guard CGImageDestinationFinalize(dest) else { throw EncodeError.finalizeFailed }
    }

    // MARK: - libimagequant
    static func quantize(_ image: CGImage, options: Options) -> CGImage {
        return quantize(image, maxColors: options.maxColors, dither: options.dither, ditherLevel: options.ditherLevel, speed: options.speed, quality: options.quality, skipQ100: options.skipQuantizeWhenQ100)
    }

    private static func quantize(_ image: CGImage, maxColors: Int, dither: Bool, ditherLevel: Float, speed: Int, quality: Int = 90, skipQ100: Bool = true) -> CGImage {
        // 꿀캠 IDC_CHK_SKIP_QUANTIZE_WHEN_Q_100: quality 100이고 256색이면 양자화 스킵
        if skipQ100 && quality >= 100 && maxColors >= 256 { return image }

        let w = image.width, h = image.height
        guard let pixels = extractRGBA(image, w: w, h: h) else { return image }
        defer { pixels.deallocate() }

        guard let attr = liq_attr_create() else { return image }
        defer { liq_attr_destroy(attr) }
        liq_set_max_colors(attr, Int32(maxColors))
        liq_set_speed(attr, Int32(max(1, min(10, speed))))
        liq_set_quality(attr, 0, Int32(max(1, min(100, quality))))

        guard let liqImg = liq_image_create_rgba(attr, pixels, Int32(w), Int32(h), 0) else { return image }
        defer { liq_image_destroy(liqImg) }

        var resPtr: OpaquePointer?
        guard liq_image_quantize(liqImg, attr, &resPtr) == LIQ_OK, let res = resPtr else { return image }
        defer { liq_result_destroy(res) }

        liq_set_dithering_level(res, dither ? ditherLevel : 0.0)

        let count = w * h
        var indexed = [UInt8](repeating: 0, count: count)
        liq_write_remapped_image(res, liqImg, &indexed, count)

        guard let pal = liq_get_palette(res) else { return image }

        var rgba = [UInt8](repeating: 0, count: count * 4)
        for i in 0..<count {
            let c = getColor(from: pal.pointee, at: Int(indexed[i]))
            rgba[i*4] = c.r; rgba[i*4+1] = c.g; rgba[i*4+2] = c.b; rgba[i*4+3] = c.a
        }

        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let out = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return image }
        return out
    }

    private static func getColor(from palette: liq_palette, at index: Int) -> liq_color {
        withUnsafePointer(to: palette.entries) { ptr in
            UnsafeBufferPointer(start: UnsafeRawPointer(ptr).assumingMemoryBound(to: liq_color.self), count: Int(palette.count))[min(index, Int(palette.count)-1)]
        }
    }

    private static func extractRGBA(_ img: CGImage, w: Int, h: Int) -> UnsafeMutableRawPointer? {
        let bpr = w * 4
        let data = UnsafeMutableRawPointer.allocate(byteCount: bpr * h, alignment: 1)
        guard let ctx = CGContext(data: data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { data.deallocate(); return nil }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }

    private static func resizeFrames(_ frames: [GIFFrame], maxWidth: Int) -> [GIFFrame] {
        guard let first = frames.first, first.image.width > maxWidth else { return frames }
        let scale = CGFloat(maxWidth) / CGFloat(first.image.width)
        return frames.compactMap { f in
            let nw = Int(CGFloat(f.image.width) * scale), nh = Int(CGFloat(f.image.height) * scale)
            guard let ctx = CGContext(data: nil, width: nw, height: nh, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return f }
            ctx.interpolationQuality = .high
            ctx.draw(f.image, in: CGRect(x: 0, y: 0, width: nw, height: nh))
            guard let img = ctx.makeImage() else { return f }
            return GIFFrame(image: img, duration: f.duration)
        }
    }
}

// MARK: - MP4 Encoder
enum MP4Encoder {
    static func encode(frames: [GIFFrame], to url: URL, quality: Int, progress: @Sendable @escaping (Double) -> Void) async throws {
        guard let first = frames.first else { throw EncodeError.noFrames }
        let w = first.image.width, h = first.image.height
        let ew = w % 2 == 0 ? w : w - 1, eh = h % 2 == 0 ? h : h - 1

        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(url: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: ew, AVVideoHeightKey: eh,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: quality * 50000]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: ew, kCVPixelBufferHeightKey as String: eh
        ])
        writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)

        var time: CMTime = .zero
        for (i, frame) in frames.enumerated() {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
            if let pb = pixelBuffer(from: frame.image, w: ew, h: eh) {
                adaptor.append(pb, withPresentationTime: time)
            }
            time = CMTimeAdd(time, CMTime(seconds: frame.duration, preferredTimescale: 600))
            progress(Double(i+1) / Double(frames.count))
        }
        input.markAsFinished(); await writer.finishWriting()
        if writer.status == .failed { throw writer.error ?? EncodeError.finalizeFailed }
    }

    private static func pixelBuffer(from image: CGImage, w: Int, h: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA, [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &pb)
        guard let buf = pb else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return buf
    }
}

import AVFoundation

enum EncodeError: Error, LocalizedError {
    case noFrames, createFailed, finalizeFailed
    var errorDescription: String? {
        switch self { case .noFrames: "프레임 없음"; case .createFailed: "생성 실패"; case .finalizeFailed: "저장 실패" }
    }
}
