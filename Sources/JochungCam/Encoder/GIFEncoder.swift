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

    static func encode(frames: [GIFFrame], to url: URL, options: Options, progress: @Sendable @escaping (Double) -> Void) async throws {
        guard !frames.isEmpty else { throw EncodeError.noFrames }
        
        // 🚀 Step 1: 리사이즈 (비동기적으로)
        progress(0.05)
        let processed = options.maxWidth > 0 ? await resizeFramesAsync(frames, maxWidth: options.maxWidth, progress: { p in
            progress(0.05 + p * 0.1)  // 5% ~ 15%
        }) : frames

        // 🚀 Step 2: 스마트 프레임 최적화 (비동기적으로)
        var finalFrames = processed
        progress(0.15)
        await Task.yield()
        
        if options.removeSimilarPixels {
            // 기본 유사 프레임 제거
            FrameOps.removeSimilar(threshold: 3, frames: &finalFrames)
        }
        
        // 🚀 NEW: 파일 크기 제한이 있으면 공격적 최적화
        if options.maxFileSizeKB > 0 {
            FrameOps.aggressiveOptimize(frames: &finalFrames, targetSizeKB: options.maxFileSizeKB)
        }
        
        progress(0.25)

        // 🚀 Step 3: GIF 작성 (비동기적으로)
        try await writeGIFAsync(finalFrames, to: url, options: options) { p in
            progress(0.2 + p * 0.7)  // 20% ~ 90%
        }

        // 🚀 Step 4: 파일 크기 제한 처리 (비동기적으로)
        if options.maxFileSizeKB > 0 {
            progress(0.9)
            await Task.yield()
            
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            if size / 1024 > options.maxFileSizeKB {
                var reduced = options
                reduced.maxColors = max(16, options.maxColors / 2)
                reduced.maxFileSizeKB = 0
                try await writeGIFAsync(finalFrames, to: url, options: reduced) { p in
                    progress(0.9 + p * 0.1)  // 90% ~ 100%
                }
            }
        }
        
        progress(1.0)  // 완료!
    }

    static func encodeToData(frames: [GIFFrame], options: Options) async throws -> Data {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("jc_\(UUID().uuidString).gif")
        try await encode(frames: frames, to: tmp, options: options) { _ in }
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try Data(contentsOf: tmp)
    }

    // 🚀 비동기 GIF 작성 (기존 함수 유지)
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

    // 🚀 NEW: 비동기 GIF 작성 (양자화를 배치 단위로!)
    private static func writeGIFAsync(_ frames: [GIFFrame], to url: URL, options: Options, progress: @Sendable @escaping (Double) -> Void) async throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { throw EncodeError.createFailed }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: options.loopCount]] as CFDictionary)

        let batchSize = 10  // 10프레임씩 배치 처리
        
        for batchStart in stride(from: 0, to: frames.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, frames.count)
            let batch = Array(frames[batchStart..<batchEnd])
            
            // 🔥 배치 양자화 (CPU 집약적 작업)
            for (localIndex, frame) in batch.enumerated() {
                let globalIndex = batchStart + localIndex
                
                // 🚀 양자화 작업을 별도 Task에서 실행
                let quantizedImage = await Task.detached {
                    return quantize(frame.image, options: options)
                }.value
                
                CGImageDestinationAddImage(dest, quantizedImage, [
                    kCGImagePropertyGIFDictionary: [
                        kCGImagePropertyGIFDelayTime: frame.duration,
                        kCGImagePropertyGIFUnclampedDelayTime: frame.duration
                    ]
                ] as CFDictionary)
                
                // 🚀 진행률 업데이트 & UI 업데이트 허용
                progress(Double(globalIndex + 1) / Double(frames.count))
            }
            
            // 🚀 배치마다 다른 작업들이 끼어들 수 있게 양보
            await Task.yield()
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

    // 🚀 기존 동기 리사이즈 (호환성 유지)
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

    // 🚀 NEW: 비동기 리사이즈 (배치 처리 + 진행률)
    private static func resizeFramesAsync(_ frames: [GIFFrame], maxWidth: Int, progress: @Sendable @escaping (Double) -> Void) async -> [GIFFrame] {
        guard let first = frames.first, first.image.width > maxWidth else { 
            progress(1.0)
            return frames 
        }
        
        let scale = CGFloat(maxWidth) / CGFloat(first.image.width)
        let batchSize = 20  // 20프레임씩 배치 처리
        var result: [GIFFrame] = []
        result.reserveCapacity(frames.count)
        
        for batchStart in stride(from: 0, to: frames.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, frames.count)
            let batch = Array(frames[batchStart..<batchEnd])
            
            // 🚀 배치 리사이즈 (Task.detached로 CPU 작업 분리)
            let resizedBatch = await Task.detached {
                return batch.compactMap { f in
                    let nw = Int(CGFloat(f.image.width) * scale)
                    let nh = Int(CGFloat(f.image.height) * scale)
                    guard let ctx = CGContext(
                        data: nil, width: nw, height: nh, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    ) else { return f }
                    ctx.interpolationQuality = .high
                    ctx.draw(f.image, in: CGRect(x: 0, y: 0, width: nw, height: nh))
                    guard let img = ctx.makeImage() else { return f }
                    return GIFFrame(image: img, duration: f.duration)
                }
            }.value
            
            result.append(contentsOf: resizedBatch)
            
            // 🚀 진행률 업데이트 & UI 허용
            progress(Double(batchEnd) / Double(frames.count))
            await Task.yield()
        }
        
        return result
    }
}

// MP4Encoder는 별도 파일에서 구현됨 (MP4Encoder.swift)

import AVFoundation

enum EncodeError: Error, LocalizedError {
    case noFrames, createFailed, finalizeFailed
    var errorDescription: String? {
        switch self { case .noFrames: "프레임 없음"; case .createFailed: "생성 실패"; case .finalizeFailed: "저장 실패" }
    }
}
