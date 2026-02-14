import Foundation
import CoreGraphics
import ImageIO
import SwiftUI

// 🎬 리리의 혁신적인 실시간 미리보기 시스템

struct PreviewFrame {
    let originalFrame: GIFFrame
    let processedImage: CGImage
    let frameIndex: Int
    let sizeKB: Int
    let quality: Double
}

struct PreviewResult {
    let frames: [PreviewFrame]
    let totalSizeKB: Int
    let averageQuality: Double
    let processingTime: TimeInterval
    let representativeFrames: [Int] // 선택된 프레임 인덱스들
}

@MainActor
class PreviewGenerator: ObservableObject {
    
    @Published var isGenerating = false
    @Published var progress: Double = 0.0
    
    private var currentTask: Task<PreviewResult?, Error>?
    
    /// 스마트 미리보기 생성 (대표 프레임 3-5개)
    func generatePreview(
        frames: [GIFFrame],
        options: GIFEncoder.Options,
        outputFormat: OutputFormat = .gif
    ) async throws -> PreviewResult? {
        
        // 기존 작업 취소
        currentTask?.cancel()
        
        currentTask = Task {
            await generatePreviewInternal(frames: frames, options: options, outputFormat: outputFormat)
        }
        
        return try await currentTask?.value
    }
    
    private func generatePreviewInternal(
        frames: [GIFFrame],
        options: GIFEncoder.Options,
        outputFormat: OutputFormat
    ) async -> PreviewResult? {
        
        guard !frames.isEmpty else { return nil }
        
        isGenerating = true
        progress = 0.0
        
        defer {
            isGenerating = false
            progress = 0.0
        }
        
        let startTime = Date()
        
        // 1단계: 대표 프레임 선택 (스마트 샘플링)
        let representativeIndices = selectRepresentativeFrames(frames)
        
        progress = 0.2
        await Task.yield()
        
        // 2단계: 각 프레임 처리
        var processedFrames: [PreviewFrame] = []
        var totalSize = 0
        var totalQuality = 0.0
        
        for (i, frameIndex) in representativeIndices.enumerated() {
            if Task.isCancelled { return nil }
            
            let frame = frames[frameIndex]
            
            // 프레임 처리
            if let processedResult = await processFrame(frame, options: options, outputFormat: outputFormat) {
                processedFrames.append(PreviewFrame(
                    originalFrame: frame,
                    processedImage: processedResult.image,
                    frameIndex: frameIndex,
                    sizeKB: processedResult.sizeKB,
                    quality: processedResult.quality
                ))
                
                totalSize += processedResult.sizeKB
                totalQuality += processedResult.quality
            }
            
            progress = 0.2 + (Double(i + 1) / Double(representativeIndices.count)) * 0.8
            await Task.yield()
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // 전체 사이즈 추정 (대표 프레임 기준)
        let averageFrameSize = totalSize / max(1, processedFrames.count)
        let estimatedTotalSize = averageFrameSize * frames.count
        
        let averageQuality = totalQuality / Double(max(1, processedFrames.count))
        
        return PreviewResult(
            frames: processedFrames,
            totalSizeKB: estimatedTotalSize,
            averageQuality: averageQuality,
            processingTime: processingTime,
            representativeFrames: representativeIndices
        )
    }
    
    /// 대표 프레임 스마트 선택 (3-5개)
    private func selectRepresentativeFrames(_ frames: [GIFFrame]) -> [Int] {
        let frameCount = frames.count
        
        if frameCount <= 3 {
            return Array(0..<frameCount)
        }
        
        var selectedIndices: [Int] = []
        
        // 첫 번째 프레임 (항상 포함)
        selectedIndices.append(0)
        
        // 마지막 프레임 (항상 포함)
        if frameCount > 1 {
            selectedIndices.append(frameCount - 1)
        }
        
        // 중간 프레임들 (복잡도 기반 선택)
        if frameCount > 2 {
            if frameCount <= 10 {
                // 작은 애니메이션: 중간 프레임 1-2개
                let middleIndex = frameCount / 2
                selectedIndices.append(middleIndex)
                
                if frameCount > 5 {
                    let quarterIndex = frameCount / 4
                    let threeQuarterIndex = (frameCount * 3) / 4
                    selectedIndices.append(quarterIndex)
                    selectedIndices.append(threeQuarterIndex)
                }
            } else {
                // 큰 애니메이션: 균등 분포로 3개 추가 (총 5개)
                let step = frameCount / 4
                selectedIndices.append(step)
                selectedIndices.append(step * 2)
                selectedIndices.append(step * 3)
            }
        }
        
        // 중복 제거 및 정렬
        let uniqueIndices = Array(Set(selectedIndices)).sorted()
        
        // 최대 5개로 제한
        return Array(uniqueIndices.prefix(5))
    }
    
    /// 단일 프레임 처리
    private func processFrame(
        _ frame: GIFFrame,
        options: GIFEncoder.Options,
        outputFormat: OutputFormat
    ) async -> (image: CGImage, sizeKB: Int, quality: Double)? {
        
        await Task.yield()
        
        switch outputFormat {
        case .gif:
            return await processGIFFrame(frame, options: options)
        case .webp:
            return await processWebPFrame(frame)
        case .mp4:
            return await processMP4Frame(frame)
        case .apng:
            return await processAPNGFrame(frame)
        }
    }
    
    /// GIF 프레임 처리 (실제 압축 적용)
    private func processGIFFrame(_ frame: GIFFrame, options: GIFEncoder.Options) async -> (image: CGImage, sizeKB: Int, quality: Double)? {
        
        let originalImage = frame.image
        
        // 1. 리사이즈 (필요시)
        let resizedImage: CGImage
        if options.maxWidth > 0 && originalImage.width > options.maxWidth {
            let scale = CGFloat(options.maxWidth) / CGFloat(originalImage.width)
            let newWidth = options.maxWidth
            let newHeight = Int(CGFloat(originalImage.height) * scale)
            
            guard let context = CGContext(
                data: nil, width: newWidth, height: newHeight,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            
            context.interpolationQuality = .high
            context.draw(originalImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
            
            guard let resized = context.makeImage() else { return nil }
            resizedImage = resized
        } else {
            resizedImage = originalImage
        }
        
        // 2. 색상 양자화 (LIQ 시뮬레이션)
        let quantizedImage = await simulateColorQuantization(
            resizedImage,
            maxColors: options.maxColors,
            quality: options.quality
        )
        
        // 3. 사이즈 추정
        let pixelCount = quantizedImage.width * quantizedImage.height
        let bitsPerPixel = log2(Double(options.maxColors))
        let estimatedBytes = Double(pixelCount) * bitsPerPixel / 8.0 * 0.8 // GIF 압축 효율
        let sizeKB = max(1, Int(estimatedBytes / 1024))
        
        // 4. 품질 추정
        let quality = Double(options.quality) * 0.8 // 양자화로 인한 품질 손실
        
        return (quantizedImage, sizeKB, quality)
    }
    
    /// 색상 양자화 시뮬레이션 (빠른 근사)
    private func simulateColorQuantization(
        _ image: CGImage,
        maxColors: Int,
        quality: Int
    ) async -> CGImage {
        
        await Task.yield()
        
        // 간단한 양자화 시뮬레이션 (실제 LIQ 대신)
        let quantizationLevel = max(1, 256 / maxColors)
        
        let width = image.width
        let height = image.height
        
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        
        context.interpolationQuality = .none // 픽셀화 효과
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 간단한 색상 감소 효과 (시각적 시뮬레이션)
        if quantizationLevel > 1 {
            // Core Image 필터 없이 간단한 양자화 효과
            guard let imageData = context.data?.bindMemory(to: UInt8.self, capacity: width * height * 4) else {
                return context.makeImage() ?? image
            }
            
            for i in stride(from: 0, to: width * height * 4, by: 4) {
                // RGB 각 채널을 양자화
                imageData[i] = UInt8((imageData[i] / UInt8(quantizationLevel)) * UInt8(quantizationLevel))     // R
                imageData[i+1] = UInt8((imageData[i+1] / UInt8(quantizationLevel)) * UInt8(quantizationLevel)) // G
                imageData[i+2] = UInt8((imageData[i+2] / UInt8(quantizationLevel)) * UInt8(quantizationLevel)) // B
                // Alpha는 그대로
            }
        }
        
        return context.makeImage() ?? image
    }
    
    /// WebP 프레임 처리
    private func processWebPFrame(_ frame: GIFFrame) async -> (image: CGImage, sizeKB: Int, quality: Double)? {
        await Task.yield()
        
        let pixelCount = frame.image.width * frame.image.height
        let estimatedBytes = Double(pixelCount) * 0.15 // WebP 효율
        let sizeKB = max(1, Int(estimatedBytes / 1024))
        
        return (frame.image, sizeKB, 85.0)
    }
    
    /// MP4 프레임 처리
    private func processMP4Frame(_ frame: GIFFrame) async -> (image: CGImage, sizeKB: Int, quality: Double)? {
        await Task.yield()
        
        // MP4는 비디오이므로 프레임당 사이즈가 아닌 전체 비트레이트 기반
        let pixelCount = frame.image.width * frame.image.height
        let estimatedBytes = Double(pixelCount) * 0.05 // 높은 압축
        let sizeKB = max(1, Int(estimatedBytes / 1024))
        
        return (frame.image, sizeKB, 90.0)
    }
    
    /// APNG 프레임 처리
    private func processAPNGFrame(_ frame: GIFFrame) async -> (image: CGImage, sizeKB: Int, quality: Double)? {
        await Task.yield()
        
        let pixelCount = frame.image.width * frame.image.height
        let estimatedBytes = Double(pixelCount) * 0.8 // PNG 기반, 높은 품질
        let sizeKB = max(1, Int(estimatedBytes / 1024))
        
        return (frame.image, sizeKB, 100.0)
    }
    
    /// 미리보기 생성 취소
    func cancelPreview() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
        progress = 0.0
    }
}

// MARK: - 유틸리티 확장

extension PreviewResult {
    /// 전체 사이즈의 사용자 친화적 표시
    var humanReadableSize: String {
        if totalSizeKB >= 1024 {
            let mb = Double(totalSizeKB) / 1024.0
            return String(format: "%.1fMB", mb)
        } else {
            return "\(totalSizeKB)KB"
        }
    }
    
    /// 품질 등급
    var qualityGrade: String {
        switch averageQuality {
        case 90...: return "최고"
        case 80..<90: return "고화질"
        case 70..<80: return "양호"
        case 60..<70: return "보통"
        default: return "압축"
        }
    }
    
    /// 처리 시간 표시
    var humanReadableTime: String {
        if processingTime < 1.0 {
            return String(format: "%.1f초", processingTime)
        } else {
            return String(format: "%.0f초", processingTime)
        }
    }
}