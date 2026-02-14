import Foundation
import CoreGraphics

// 🎯 리리의 혁신적인 스마트 압축 엔진

@MainActor
class SmartCompressor: ObservableObject {
    
    enum CompressionStrategy {
        case web        // 웹 최적화 (1MB 목표)
        case desktop    // 데스크톱 최적화 (3MB 목표) 
        case chat       // 채팅 최적화 (8MB 목표)
        case archive    // 아카이브 품질 (무제한)
        
        var targetSizeKB: Int {
            switch self {
            case .web: return 1000
            case .desktop: return 3000
            case .chat: return 8000
            case .archive: return 0
            }
        }
        
        var name: String {
            switch self {
            case .web: return "웹 최적화"
            case .desktop: return "데스크톱 최적화"
            case .chat: return "채팅 최적화"
            case .archive: return "아카이브 품질"
            }
        }
    }
    
    struct OptimizedSettings {
        let maxColors: Int
        let maxWidth: Int
        let liqSpeed: Int
        let ditherLevel: Float
        let fps: Int
        let removeFrameRatio: Double
        let strategy: CompressionStrategy
        
        var description: String {
            let sizeText = strategy.targetSizeKB > 0 ? "\(strategy.targetSizeKB/1000)MB" : "무제한"
            return "\(strategy.name): \(maxWidth)px, \(maxColors)색, \(fps)fps → ~\(sizeText)"
        }
    }
    
    @Published var currentStrategy: CompressionStrategy = .desktop
    @Published var isOptimizing: Bool = false
    @Published var optimizationProgress: Double = 0.0
    @Published var lastOptimizedSettings: OptimizedSettings?
    
    // 프레임 분석 기반 최적 설정 생성
    func generateOptimalSettings(
        for frames: [GIFFrame],
        strategy: CompressionStrategy = .desktop
    ) async -> OptimizedSettings {
        
        isOptimizing = true
        optimizationProgress = 0.0
        
        defer {
            isOptimizing = false
            optimizationProgress = 1.0
        }
        
        // 프레임 분석
        optimizationProgress = 0.2
        let analysis = analyzeFrames(frames)
        
        // 전략별 기본 설정
        optimizationProgress = 0.4
        var settings = getBaseSettings(for: strategy)
        
        // 분석 결과 기반 최적화
        optimizationProgress = 0.6
        settings = optimizeForContent(settings, analysis: analysis)
        
        // 예상 크기 검증 및 조정
        optimizationProgress = 0.8
        settings = adjustForTargetSize(settings, frames: frames, strategy: strategy)
        
        optimizationProgress = 1.0
        
        let optimized = OptimizedSettings(
            maxColors: settings.colors,
            maxWidth: settings.width,
            liqSpeed: settings.liqSpeed,
            ditherLevel: settings.ditherLevel,
            fps: settings.fps,
            removeFrameRatio: settings.frameReduction,
            strategy: strategy
        )
        
        lastOptimizedSettings = optimized
        return optimized
    }
    
    // 프레임 특성 분석
    private struct FrameAnalysis {
        let averageColors: Int
        let hasGradients: Bool
        let hasTransparency: Bool
        let motionIntensity: Double
        let frameVariation: Double
        let recommendedColors: Int
        let recommendedFPS: Int
    }
    
    private func analyzeFrames(_ frames: [GIFFrame]) -> FrameAnalysis {
        guard !frames.isEmpty else {
            return FrameAnalysis(
                averageColors: 64, hasGradients: false, hasTransparency: false,
                motionIntensity: 0.0, frameVariation: 0.0,
                recommendedColors: 64, recommendedFPS: 30
            )
        }
        
        // 색상 복잡도 분석 (간단 추정)
        let avgColors = min(256, max(32, frames.count * 8))
        
        // 그라데이션 감지 (프레임 수 기반 추정)
        let hasGradients = frames.count > 100
        
        // 움직임 강도 분석 (duration 기반)
        let avgDuration = frames.reduce(0.0) { $0 + $1.duration } / Double(frames.count)
        let motionIntensity = max(0.0, min(1.0, (0.1 - avgDuration) / 0.05))
        
        // 프레임 변화량 추정
        let frameVariation = min(1.0, Double(frames.count) / 600.0)
        
        // 권장 설정 계산
        let recommendedColors = hasGradients ? 256 : (avgColors > 128 ? 256 : 128)
        let recommendedFPS = motionIntensity > 0.7 ? 60 : (motionIntensity > 0.3 ? 30 : 24)
        
        return FrameAnalysis(
            averageColors: avgColors,
            hasGradients: hasGradients,
            hasTransparency: false,
            motionIntensity: motionIntensity,
            frameVariation: frameVariation,
            recommendedColors: recommendedColors,
            recommendedFPS: recommendedFPS
        )
    }
    
    private struct BaseSettings {
        var colors: Int
        var width: Int
        var liqSpeed: Int
        var ditherLevel: Float
        var fps: Int
        var frameReduction: Double
    }
    
    private func getBaseSettings(for strategy: CompressionStrategy) -> BaseSettings {
        switch strategy {
        case .web:
            return BaseSettings(
                colors: 64, width: 500, liqSpeed: 6,
                ditherLevel: 0.8, fps: 30, frameReduction: 0.1
            )
        case .desktop:
            return BaseSettings(
                colors: 128, width: 800, liqSpeed: 3,
                ditherLevel: 0.5, fps: 60, frameReduction: 0.0
            )
        case .chat:
            return BaseSettings(
                colors: 256, width: 720, liqSpeed: 3,
                ditherLevel: 0.4, fps: 60, frameReduction: 0.0
            )
        case .archive:
            return BaseSettings(
                colors: 256, width: 0, liqSpeed: 1,
                ditherLevel: 0.2, fps: 120, frameReduction: 0.0
            )
        }
    }
    
    private func optimizeForContent(_ settings: BaseSettings, analysis: FrameAnalysis) -> BaseSettings {
        var optimized = settings
        
        // 색상 수 최적화
        if analysis.hasGradients {
            optimized.colors = min(256, max(optimized.colors, analysis.recommendedColors))
            optimized.ditherLevel = max(optimized.ditherLevel, 0.3)
        } else {
            optimized.colors = min(optimized.colors, analysis.averageColors)
            optimized.ditherLevel = min(optimized.ditherLevel, 0.6)
        }
        
        // FPS 최적화
        if analysis.motionIntensity > 0.7 {
            optimized.fps = max(optimized.fps, 60)
        } else if analysis.motionIntensity < 0.3 {
            optimized.fps = min(optimized.fps, 30)
        }
        
        // 프레임 감소 최적화
        if analysis.frameVariation < 0.3 {
            optimized.frameReduction = min(optimized.frameReduction + 0.05, 0.15)
        }
        
        return optimized
    }
    
    private func adjustForTargetSize(_ settings: BaseSettings, frames: [GIFFrame], strategy: CompressionStrategy) -> BaseSettings {
        guard strategy.targetSizeKB > 0 else { return settings }
        
        // 예상 크기 계산 (간단한 추정)
        let estimatedSizeKB = estimateSize(settings: settings, frames: frames)
        let targetKB = strategy.targetSizeKB
        
        guard estimatedSizeKB > targetKB else { return settings }
        
        var adjusted = settings
        let reductionNeeded = Double(estimatedSizeKB) / Double(targetKB)
        
        // 단계별 압축 강화
        if reductionNeeded > 2.0 {
            // 해상도 감소
            adjusted.width = Int(Double(adjusted.width) / sqrt(reductionNeeded))
        }
        
        if reductionNeeded > 1.5 {
            // 색상 수 감소
            adjusted.colors = max(32, Int(Double(adjusted.colors) / 1.5))
        }
        
        if reductionNeeded > 1.2 {
            // FPS 감소
            adjusted.fps = max(24, Int(Double(adjusted.fps) / 1.2))
        }
        
        return adjusted
    }
    
    private func estimateSize(settings: BaseSettings, frames: [GIFFrame]) -> Int {
        // 매우 간단한 크기 추정 알고리즘
        let baseSize = 25000 // 25MB 기준
        var factor = 1.0
        
        // 색상 수에 따른 압축
        factor *= Double(settings.colors) / 256.0
        
        // 해상도에 따른 압축
        if settings.width > 0 {
            let resolutionFactor = min(Double(settings.width) / 1920.0, 1.0)
            factor *= resolutionFactor * resolutionFactor
        }
        
        // FPS에 따른 압축
        factor *= Double(settings.fps) / 120.0
        
        // 프레임 감소
        factor *= (1.0 - settings.frameReduction)
        
        // LIQ 품질
        let liqFactor = 1.0 - (Double(10 - settings.liqSpeed) * 0.05)
        factor *= liqFactor
        
        return Int(Double(baseSize) * factor)
    }
    
    // 압축 결과 시뮬레이션
    func simulateCompression(settings: OptimizedSettings, originalSizeKB: Int) -> (compressedKB: Int, qualityScore: Double, compressionRatio: Double) {
        let compressed = estimateSize(
            settings: BaseSettings(
                colors: settings.maxColors,
                width: settings.maxWidth,
                liqSpeed: settings.liqSpeed,
                ditherLevel: Float(settings.ditherLevel),
                fps: settings.fps,
                frameReduction: settings.removeFrameRatio
            ),
            frames: []
        )
        
        let ratio = Double(compressed) / Double(originalSizeKB)
        let quality = min(100.0, 100.0 * (Double(settings.maxColors) / 256.0) * (1.0 - settings.removeFrameRatio))
        
        return (compressed, quality, ratio)
    }
}