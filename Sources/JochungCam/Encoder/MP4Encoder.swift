import Foundation
import AVFoundation
import CoreImage
import VideoToolbox

// 🎬 리리의 완벽한 MP4 인코더

struct MP4Encoder {
    
    // MARK: - 인코딩 옵션
    
    struct Options {
        var quality: Float = 0.8  // 0.0-1.0
        var bitRate: Int = 2_000_000  // 2Mbps 기본
        var maxWidth: Int = 0  // 0 = 원본 크기
        var fps: Int = 30
        var preset: String = "AVAssetExportPresetMediumQuality"
        var profileLevel: String = AVVideoProfileLevelH264BaselineAutoLevel
        var enableHardwareAcceleration: Bool = true
        var audioEnabled: Bool = false
        
        // 고급 설정
        var keyFrameInterval: Int = 30
        var maxBitRate: Int = 0  // 0 = 제한 없음
        var averageBitRate: Int = 0  // 0 = 자동
        var allowFrameReordering: Bool = true
        var realTime: Bool = false
        
        static var ultraLowQuality: Options {
            var options = Options()
            options.quality = 0.3
            options.bitRate = 500_000
            options.preset = "AVAssetExportPresetLowQuality"
            options.profileLevel = AVVideoProfileLevelH264BaselineAutoLevel
            return options
        }
        
        static var lowQuality: Options {
            var options = Options()
            options.quality = 0.5
            options.bitRate = 1_000_000
            options.preset = "AVAssetExportPresetMediumQuality"
            return options
        }
        
        static var mediumQuality: Options {
            var options = Options()
            options.quality = 0.7
            options.bitRate = 2_000_000
            options.preset = "AVAssetExportPresetMediumQuality"
            return options
        }
        
        static var highQuality: Options {
            var options = Options()
            options.quality = 0.9
            options.bitRate = 5_000_000
            options.preset = "AVAssetExportPresetHighQuality"
            options.profileLevel = AVVideoProfileLevelH264HighAutoLevel
            return options
        }
        
        static var ultraHighQuality: Options {
            var options = Options()
            options.quality = 1.0
            options.bitRate = 10_000_000
            options.preset = "AVAssetExportPresetHighestQuality"
            options.profileLevel = AVVideoProfileLevelH264HighAutoLevel
            options.keyFrameInterval = 60
            return options
        }
    }
    
    // MARK: - 에러 정의
    
    enum MP4Error: LocalizedError {
        case invalidFrames
        case writerCreationFailed
        case writerInputFailed
        case pixelBufferCreationFailed
        case encodingFailed(Error)
        case exportFailed(Error?)
        case unsupportedFormat
        
        var errorDescription: String? {
            switch self {
            case .invalidFrames:
                return "유효하지 않은 프레임 데이터"
            case .writerCreationFailed:
                return "MP4 작성기 생성 실패"
            case .writerInputFailed:
                return "비디오 입력 설정 실패"
            case .pixelBufferCreationFailed:
                return "픽셀 버퍼 생성 실패"
            case .encodingFailed(let error):
                return "인코딩 실패: \(error.localizedDescription)"
            case .exportFailed(let error):
                return "내보내기 실패: \(error?.localizedDescription ?? "알 수 없는 오류")"
            case .unsupportedFormat:
                return "지원하지 않는 형식"
            }
        }
    }
    
    // MARK: - 메인 인코딩 함수
    
    static func encode(
        frames: [GIFFrame],
        to outputURL: URL,
        quality: Float = 80,
        maxWidth: Int = 0,
        fps: Int = 30,
        progressCallback: ((Double) -> Void)? = nil
    ) async throws {
        
        let options = Options(
            quality: quality / 100.0,
            maxWidth: maxWidth,
            fps: fps
        )
        
        try await encodeWithOptions(
            frames: frames,
            to: outputURL,
            options: options,
            progressCallback: progressCallback
        )
    }
    
    static func encodeWithOptions(
        frames: [GIFFrame],
        to outputURL: URL,
        options: Options,
        progressCallback: ((Double) -> Void)? = nil
    ) async throws {
        
        guard !frames.isEmpty else {
            throw MP4Error.invalidFrames
        }
        
        // 출력 파일 삭제 (존재할 경우)
        try? FileManager.default.removeItem(at: outputURL)
        
        // 첫 번째 프레임에서 비디오 크기 결정
        let firstFrame = frames[0]
        let originalSize = CGSize(width: firstFrame.image.width, height: firstFrame.image.height)
        let videoSize = calculateVideoSize(originalSize: originalSize, maxWidth: options.maxWidth)
        
        // AVAssetWriter 설정
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // 비디오 설정
        let videoSettings = createVideoSettings(size: videoSize, options: options)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = options.realTime
        
        // 픽셀 버퍼 어댑터 설정
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(videoSize.width),
            kCVPixelBufferHeightKey as String: Int(videoSize.height)
        ]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        guard writer.canAdd(videoInput) else {
            throw MP4Error.writerInputFailed
        }
        
        writer.add(videoInput)
        
        // 인코딩 시작
        guard writer.startWriting() else {
            throw MP4Error.writerCreationFailed
        }
        
        writer.startSession(atSourceTime: .zero)
        
        // 프레임별 인코딩
        var currentTime = CMTime.zero
        
        for (index, frame) in frames.enumerated() {
            // 진행률 업데이트
            let progress = Double(index) / Double(frames.count)
            progressCallback?(progress)
            
            // 인코딩 준비 대기
            while !videoInput.isReadyForMoreMediaData {
                await Task.yield()
            }
            
            // 프레임을 픽셀 버퍼로 변환
            let pixelBuffer = try createPixelBuffer(
                from: frame.image,
                size: videoSize,
                pixelBufferPool: pixelBufferAdaptor.pixelBufferPool
            )
            
            // 프레임 추가
            if !pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: currentTime) {
                throw MP4Error.encodingFailed(NSError(domain: "MP4Encoder", code: -1, userInfo: [NSLocalizedDescriptionKey: "프레임 추가 실패"]))
            }
            
            // 다음 프레임 시간 계산 (프레임별 지속시간 고려)
            let frameTime = CMTimeMakeWithSeconds(frame.duration, preferredTimescale: 600)
            currentTime = CMTimeAdd(currentTime, frameTime)
        }
        
        // 인코딩 완료
        videoInput.markAsFinished()
        
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }
        
        if writer.status == .failed {
            throw MP4Error.exportFailed(writer.error)
        }
        
        progressCallback?(1.0)
    }
    
    // MARK: - 비디오 설정 생성
    
    private static func createVideoSettings(size: CGSize, options: Options) -> [String: Any] {
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: options.bitRate,
            AVVideoProfileLevelKey: options.profileLevel,
            AVVideoMaxKeyFrameIntervalKey: options.keyFrameInterval,
            AVVideoAllowFrameReorderingKey: options.allowFrameReordering
        ]
        
        // 최대 비트레이트 설정
        if options.maxBitRate > 0 {
            compressionProperties[AVVideoMaxKeyFrameIntervalDurationKey] = options.maxBitRate
        }
        
        // 평균 비트레이트 설정
        if options.averageBitRate > 0 {
            compressionProperties[AVVideoAverageBitRateKey] = options.averageBitRate
        }
        
        // 하드웨어 가속 설정
        if options.enableHardwareAcceleration {
            compressionProperties[AVVideoCodecKey] = AVVideoCodecType.h264
        }
        
        // 품질 설정
        compressionProperties[AVVideoQualityKey] = options.quality
        
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
    }
    
    // MARK: - 비디오 크기 계산
    
    private static func calculateVideoSize(originalSize: CGSize, maxWidth: Int) -> CGSize {
        guard maxWidth > 0 && originalSize.width > CGFloat(maxWidth) else {
            return originalSize
        }
        
        let aspectRatio = originalSize.height / originalSize.width
        let newWidth = CGFloat(maxWidth)
        let newHeight = newWidth * aspectRatio
        
        // 짝수로 만들기 (H.264 요구사항)
        return CGSize(
            width: floor(newWidth / 2) * 2,
            height: floor(newHeight / 2) * 2
        )
    }
    
    // MARK: - 픽셀 버퍼 생성
    
    private static func createPixelBuffer(
        from cgImage: CGImage,
        size: CGSize,
        pixelBufferPool: CVPixelBufferPool?
    ) throws -> CVPixelBuffer {
        
        var pixelBuffer: CVPixelBuffer?
        let status: CVReturn
        
        // 픽셀 버퍼 풀에서 생성 시도
        if let pool = pixelBufferPool {
            status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        } else {
            // 직접 생성
            let attributes: [String: Any] = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
            ]
            
            status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(size.width),
                Int(size.height),
                kCVPixelFormatType_32ARGB,
                attributes as CFDictionary,
                &pixelBuffer
            )
        }
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw MP4Error.pixelBufferCreationFailed
        }
        
        // 이미지를 픽셀 버퍼에 그리기
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let data = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: data,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            throw MP4Error.pixelBufferCreationFailed
        }
        
        // 이미지 크기 조정 및 그리기
        let rect = CGRect(origin: .zero, size: size)
        context.draw(cgImage, in: rect)
        
        return buffer
    }
    
    // MARK: - 유틸리티 함수
    
    static func estimateFileSize(frames: [GIFFrame], options: Options) -> Int64 {
        guard !frames.isEmpty else { return 0 }
        
        let duration = frames.reduce(0.0) { $0 + $1.duration }
        return Int64(Float(duration) * Float(options.bitRate) / 8.0)
    }
    
    static func getOptimalBitRate(for size: CGSize, fps: Int, quality: Float) -> Int {
        let pixelCount = size.width * size.height
        let baseRate = Int(pixelCount * CGFloat(fps) * 0.1)  // 기본 비트레이트
        
        return Int(Float(baseRate) * quality)
    }
    
    static func getSupportedResolutions() -> [(String, CGSize)] {
        return [
            ("4K UHD", CGSize(width: 3840, height: 2160)),
            ("1080p", CGSize(width: 1920, height: 1080)),
            ("720p", CGSize(width: 1280, height: 720)),
            ("480p", CGSize(width: 854, height: 480)),
            ("360p", CGSize(width: 640, height: 360)),
            ("240p", CGSize(width: 426, height: 240))
        ]
    }
}

// MARK: - MP4 품질 프리셋

extension MP4Encoder.Options {
    
    static func preset(for target: MP4Target) -> MP4Encoder.Options {
        switch target {
        case .web:
            return MP4Encoder.Options(
                quality: 0.7,
                bitRate: 1_500_000,
                maxWidth: 1280,
                fps: 30
            )
            
        case .mobile:
            return MP4Encoder.Options(
                quality: 0.6,
                bitRate: 800_000,
                maxWidth: 854,
                fps: 24
            )
            
        case .social:
            return MP4Encoder.Options(
                quality: 0.8,
                bitRate: 3_000_000,
                maxWidth: 1920,
                fps: 30
            )
            
        case .archival:
            return MP4Encoder.Options(
                quality: 1.0,
                bitRate: 10_000_000,
                maxWidth: 0,
                fps: 60,
                profileLevel: AVVideoProfileLevelH264HighAutoLevel
            )
            
        case .streaming:
            return MP4Encoder.Options(
                quality: 0.75,
                bitRate: 2_500_000,
                maxWidth: 1920,
                fps: 30,
                realTime: true
            )
        }
    }
}

enum MP4Target {
    case web       // 웹용 (적당한 품질, 작은 크기)
    case mobile    // 모바일용 (낮은 해상도, 작은 크기)
    case social    // 소셜 미디어용 (좋은 품질, 공유용)
    case archival  // 보관용 (최고 품질)
    case streaming // 스트리밍용 (실시간 최적화)
}