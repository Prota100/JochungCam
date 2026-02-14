import Foundation
import CoreGraphics
import ImageIO
import AVFoundation

enum FrameOps {
    // MARK: - Delete
    static func deleteFrame(at i: Int, from frames: inout [GIFFrame]) {
        guard frames.count > 1, frames.indices.contains(i) else { return }
        frames.remove(at: i)
    }

    static func deleteRange(_ range: Range<Int>, from frames: inout [GIFFrame]) {
        let safe = max(0, range.lowerBound)..<min(frames.count, range.upperBound)
        guard frames.count - safe.count >= 1 else { return }
        frames.removeSubrange(safe)
    }

    // MARK: - Speed
    static func adjustSpeed(_ multiplier: Double, frames: inout [GIFFrame]) {
        for i in frames.indices { frames[i].duration = max(0.01, frames[i].duration / multiplier) }
    }

    static func setAllDuration(_ dur: TimeInterval, frames: inout [GIFFrame]) {
        for i in frames.indices { frames[i].duration = max(0.01, dur) }
    }

    // MARK: - Order
    static func reverse(_ frames: inout [GIFFrame]) { frames.reverse() }

    static func yoyo(_ frames: inout [GIFFrame]) {
        let reversed = frames.reversed().dropFirst() // skip last (=first of reversed) to avoid dupe
        frames.append(contentsOf: reversed)
    }

    // MARK: - Reduce
    static func removeEvenFrames(_ frames: inout [GIFFrame]) {
        frames = frames.enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
    }

    static func removeOddFrames(_ frames: inout [GIFFrame]) {
        frames = frames.enumerated().compactMap { $0.offset % 2 != 0 ? $0.element : nil }
    }

    static func removeEveryNth(_ n: Int, frames: inout [GIFFrame]) {
        guard n > 1 else { return }
        frames = frames.enumerated().compactMap { ($0.offset + 1) % n != 0 ? $0.element : nil }
    }

    static func removeSimilar(threshold: Int = 5, frames: inout [GIFFrame]) {
        guard frames.count > 2 else { return }
        var kept: [GIFFrame] = [frames[0]]
        for i in 1..<frames.count {
            if !framesAreSimilar(frames[i-1].image, frames[i].image, threshold: threshold) {
                kept.append(frames[i])
            } else {
                // Add duration to previous
                kept[kept.count - 1].duration += frames[i].duration
            }
        }
        frames = kept
    }

    // 🚀 NEW: QuickTime 변환에 최적화된 공격적 압축
    static func aggressiveOptimize(frames: inout [GIFFrame], targetSizeKB: Int = 500) {
        guard frames.count > 5 else { return }
        let originalCount = frames.count

        // 1단계: 매우 유사한 프레임 제거 (더 낮은 threshold)
        removeSimilar(threshold: 2, frames: &frames)

        // 2단계: 정적인 구간 감지하여 추가 프레임 드롭
        removeStaticSequences(frames: &frames)

        // 3단계: 너무 짧은 프레임 병합 (깜빡이는 느낌 제거)
        mergeShortFrames(minDuration: 0.05, frames: &frames)

        // 4단계: 여전히 크다면 FPS 줄이기
        let estimatedSizeKB = estimateGIFSize(frames)
        if estimatedSizeKB > targetSizeKB && estimatedSizeKB > 0 {
            let ratio = max(0.05, min(0.95, Double(targetSizeKB) / Double(estimatedSizeKB)))
            reduceFrameRate(targetRatio: ratio, frames: &frames)
        }

        // 5단계: strict target인데 변화가 없으면 최소 1회 강제 샘플링
        if frames.count == originalCount && targetSizeKB <= 100 {
            reduceFrameRate(targetRatio: 0.5, frames: &frames)
        }
    }

    // 🚀 정적인 구간에서 중간 프레임들 제거 - 🔧 수정됨
    static func removeStaticSequences(frames: inout [GIFFrame]) {
        guard frames.count > 1 else { return }

        var optimized: [GIFFrame] = [frames[0]]
        for i in 1..<frames.count {
            if framesAreSimilar(optimized.last!.image, frames[i].image, threshold: 3) {
                optimized[optimized.count - 1].duration += frames[i].duration
            } else {
                optimized.append(frames[i])
            }
        }

        frames = optimized
    }

    // 🚀 너무 짧은 프레임들 병합 (깜빡임 방지) - 🔧 수정됨
    static func mergeShortFrames(minDuration: TimeInterval, frames: inout [GIFFrame]) {
        guard frames.count > 1 else { return }

        var merged: [GIFFrame] = []
        var shortBatchDuration: TimeInterval = 0
        var shortBatchImage: CGImage?

        for frame in frames {
            if frame.duration < minDuration {
                if shortBatchImage == nil { shortBatchImage = frame.image }
                shortBatchDuration += frame.duration
            } else {
                if shortBatchDuration > 0, let img = shortBatchImage {
                    merged.append(GIFFrame(image: img, duration: shortBatchDuration))
                    shortBatchDuration = 0
                    shortBatchImage = nil
                }
                merged.append(frame)
            }
        }

        if shortBatchDuration > 0, let img = shortBatchImage {
            merged.append(GIFFrame(image: img, duration: shortBatchDuration))
        }

        frames = merged
    }

    // 🚀 FPS 적응형 감소
    static func reduceFrameRate(targetRatio: Double, frames: inout [GIFFrame]) {
        guard targetRatio < 1.0, frames.count > 2 else { return }
        
        let keepEvery = Int(ceil(1.0 / targetRatio))
        var reduced: [GIFFrame] = []
        
        for (i, frame) in frames.enumerated() {
            if i % keepEvery == 0 {
                var newFrame = frame
                // 다음 몇 프레임의 duration 합산
                for j in 1..<keepEvery where i + j < frames.count {
                    newFrame.duration += frames[i + j].duration
                }
                reduced.append(newFrame)
            }
        }
        
        frames = reduced
    }

    // 🚀 GIF 크기 추정 (대략적)
    static func estimateGIFSize(_ frames: [GIFFrame]) -> Int {
        guard let first = frames.first else { return 0 }
        let pixels = first.image.width * first.image.height
        let bytesPerFrame = Double(pixels) * 0.3 // 대략적 추정
        let totalBytes = bytesPerFrame * Double(frames.count)
        return max(1, Int(totalBytes / 1024)) // KB
    }

    private static func framesAreSimilar(_ a: CGImage, _ b: CGImage, threshold: Int) -> Bool {
        guard a.width == b.width, a.height == b.height else { return false }
        guard let da = a.dataProvider?.data, let db = b.dataProvider?.data else { return false }
        guard let pa = CFDataGetBytePtr(da), let pb = CFDataGetBytePtr(db) else { return false }
        let len = min(CFDataGetLength(da), CFDataGetLength(db))
        let step = max(1, len / 1000) // sample ~1000 points
        var diff = 0
        var samples = 0
        var offset = 0
        while offset < len {
            let d = abs(Int(pa[offset]) - Int(pb[offset]))
            diff += d
            samples += 1
            offset += step
        }
        return samples > 0 && (diff / samples) < threshold
    }

    // MARK: - Crop
    static func crop(_ rect: CGRect, frames: inout [GIFFrame]) {
        guard rect.width > 0, rect.height > 0 else { return }
        frames = frames.compactMap { f in
            guard let img = f.image.cropping(to: rect) else { return nil }
            return GIFFrame(image: img, duration: f.duration)
        }
    }

    // MARK: - Resize
    static func resize(maxWidth: Int, frames: inout [GIFFrame]) {
        guard maxWidth > 0, let first = frames.first, first.image.width > maxWidth else { return }
        let scale = CGFloat(maxWidth) / CGFloat(first.image.width)
        frames = frames.compactMap { f in
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
    }

    // MARK: - Import GIF
    static func importGIF(from url: URL) -> [GIFFrame]? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let n = CGImageSourceGetCount(src)
        guard n > 0 else { return nil }
        var out: [GIFFrame] = []
        for i in 0..<n {
            guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            var dur: TimeInterval = 0.1
            if let p = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [String: Any],
               let g = p[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                dur = (g[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double) ??
                      (g[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0.1
                if dur < 0.01 { dur = 0.1 }
            }
            out.append(GIFFrame(image: img, duration: dur))
        }
        return out.isEmpty ? nil : out
    }

    // MARK: - Import Video
    static func importVideo(from url: URL, fps: Double = 60, progress: (@Sendable (Double, String) -> Void)? = nil) async -> [GIFFrame]? {
        progress?(0.0, "동영상 분석 중...")
        
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { 
            progress?(0.0, "동영상을 열 수 없습니다")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기
            return nil 
        }
        let totalSec = CMTimeGetSeconds(duration)
        
        guard totalSec > 0.1 else {
            progress?(0.0, "동영상이 너무 짧습니다")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return nil
        }
        
        // 30초 넘으면 fps 줄여서 메모리 보호
        let maxFrames = 900 // 30초 * 30fps 정도
        let interval = max(1.0 / fps, totalSec / Double(maxFrames))
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = CMTime.zero
        generator.requestedTimeToleranceAfter = CMTime.zero
        generator.appliesPreferredTrackTransform = true
        
        // 메모리 최적화
        generator.maximumSize = CGSize(width: 1920, height: 1080) // 풀HD 제한
        
        var frames: [GIFFrame] = []
        var times: [CMTime] = []
        
        // 시간 배열 미리 생성
        var t: Double = 0
        while t < totalSec && times.count < maxFrames {
            times.append(CMTime(seconds: t, preferredTimescale: 600))
            t += interval
        }
        
        // 배치로 처리 (메모리 관리)
        for (index, cmTime) in times.enumerated() {
            // 프로그레스 업데이트
            let progressPercent = Double(index) / Double(times.count)
            let currentTime = CMTimeGetSeconds(cmTime)
            progress?(progressPercent, String(format: "프레임 추출 중... %.1f/%.1fs (%d/%d)", currentTime, totalSec, frames.count, times.count))
            
            if let (img, _) = try? await generator.image(at: cmTime) {
                autoreleasepool {
                    frames.append(GIFFrame(image: img, duration: interval))
                }
            }
            
            // 100프레임마다 잠시 멈춰서 메모리 정리
            if frames.count % 100 == 0 {
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01초
            }
        }
        
        progress?(0.95, "프레임 정리 중...")
        
        guard !frames.isEmpty else {
            progress?(0.0, "추출된 프레임이 없습니다")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return nil
        }
        
        progress?(1.0, "완료!")
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3초 대기
        
        return frames.isEmpty ? nil : frames
    }
}
