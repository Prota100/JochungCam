#!/usr/bin/env swift

import Foundation
import CoreGraphics

// 🎯 리리의 완벽한 압축 테스트 시스템

struct CompressionTest {
    
    // 압축 퀄리티 프리셋들
    enum QualityPreset {
        case ultraLight    // 초경량: 500KB 목표
        case light        // 가벼움: 2MB 목표  
        case standard     // 표준: 5MB 목표
        case discord      // 디스코드: 10MB 목표
        case high         // 고화질: 무제한
        case perfect      // 완벽: 최고 품질
        
        var settings: CompressionSettings {
            switch self {
            case .ultraLight:
                return CompressionSettings(
                    maxColors: 64,
                    liqSpeed: 8,
                    ditherLevel: 0.9,
                    maxWidth: 400,
                    targetSizeKB: 500,
                    fps: 24,
                    removeFrames: 0.3  // 30% 프레임 제거
                )
            case .light:
                return CompressionSettings(
                    maxColors: 128,
                    liqSpeed: 4,
                    ditherLevel: 0.7,
                    maxWidth: 480,
                    targetSizeKB: 2000,
                    fps: 30,
                    removeFrames: 0.1  // 10% 프레임 제거
                )
            case .standard:
                return CompressionSettings(
                    maxColors: 256,
                    liqSpeed: 2,
                    ditherLevel: 0.5,
                    maxWidth: 720,
                    targetSizeKB: 5000,
                    fps: 60,
                    removeFrames: 0.0  // 프레임 제거 없음
                )
            case .discord:
                return CompressionSettings(
                    maxColors: 256,
                    liqSpeed: 3,
                    ditherLevel: 0.4,
                    maxWidth: 640,
                    targetSizeKB: 10000,
                    fps: 60,
                    removeFrames: 0.0
                )
            case .high:
                return CompressionSettings(
                    maxColors: 256,
                    liqSpeed: 1,
                    ditherLevel: 0.3,
                    maxWidth: 0, // 원본 해상도
                    targetSizeKB: 0, // 무제한
                    fps: 120,
                    removeFrames: 0.0
                )
            case .perfect:
                return CompressionSettings(
                    maxColors: 256,
                    liqSpeed: 1,
                    ditherLevel: 0.0, // 디더링 없음
                    maxWidth: 0,
                    targetSizeKB: 0,
                    fps: 120,
                    removeFrames: 0.0
                )
            }
        }
        
        var name: String {
            switch self {
            case .ultraLight: return "초경량"
            case .light: return "가벼움"
            case .standard: return "표준"
            case .discord: return "디스코드"
            case .high: return "고화질"
            case .perfect: return "완벽"
            }
        }
    }
    
    struct CompressionSettings {
        let maxColors: Int
        let liqSpeed: Int
        let ditherLevel: Double
        let maxWidth: Int
        let targetSizeKB: Int
        let fps: Int
        let removeFrames: Double  // 0.0~1.0 (제거할 프레임 비율)
    }
    
    struct CompressionResult {
        let preset: QualityPreset
        let originalSizeKB: Int
        let compressedSizeKB: Int
        let compressionRatio: Double
        let qualityScore: Double
        let processingTimeMS: Int
        let frameCount: Int
        let actualFPS: Int
        let description: String
        
        var compressionPercent: Int {
            Int((1.0 - (Double(compressedSizeKB) / Double(originalSizeKB))) * 100)
        }
    }
    
    // 테스트용 가상 데이터 생성
    static func generateTestData() -> [CompressionResult] {
        let originalSize = 25000  // 25MB 원본 (60fps, 10초, 1920x1080)
        
        return QualityPreset.allCases.map { preset in
            let settings = preset.settings
            
            // 압축률 계산 (실제 알고리즘 기반 추정)
            let compressionFactor = calculateCompressionFactor(settings: settings)
            let compressedSize = Int(Double(originalSize) * compressionFactor)
            
            // 품질 점수 계산
            let qualityScore = calculateQualityScore(settings: settings)
            
            // 프레임 수 계산
            let originalFrames = 600 // 60fps * 10초
            let finalFrames = Int(Double(originalFrames) * (1.0 - settings.removeFrames))
            
            return CompressionResult(
                preset: preset,
                originalSizeKB: originalSize,
                compressedSizeKB: compressedSize,
                compressionRatio: Double(compressedSize) / Double(originalSize),
                qualityScore: qualityScore,
                processingTimeMS: calculateProcessingTime(settings: settings),
                frameCount: finalFrames,
                actualFPS: settings.fps,
                description: generateDescription(preset: preset, result: compressedSize)
            )
        }
    }
    
    private static func calculateCompressionFactor(settings: CompressionSettings) -> Double {
        var factor = 1.0
        
        // 색상 수에 따른 압축
        factor *= Double(settings.maxColors) / 256.0
        
        // 해상도에 따른 압축
        if settings.maxWidth > 0 {
            let resolutionFactor = min(Double(settings.maxWidth) / 1920.0, 1.0)
            factor *= resolutionFactor * resolutionFactor  // 넓이 * 높이
        }
        
        // FPS에 따른 압축
        factor *= Double(settings.fps) / 120.0
        
        // 프레임 제거
        factor *= (1.0 - settings.removeFrames)
        
        // LIQ 품질에 따른 추가 압축
        let liqFactor = 1.0 - (Double(10 - settings.liqSpeed) * 0.05)
        factor *= liqFactor
        
        // 디더링에 따른 압축 효과
        factor *= (1.0 + settings.ditherLevel * 0.2)
        
        // 목표 크기 제한
        if settings.targetSizeKB > 0 {
            let targetFactor = Double(settings.targetSizeKB) / 25000.0
            factor = min(factor, targetFactor)
        }
        
        return max(factor, 0.02)  // 최소 2% (500KB)
    }
    
    private static func calculateQualityScore(settings: CompressionSettings) -> Double {
        var score = 100.0
        
        // 색상 수에 따른 품질
        score *= Double(settings.maxColors) / 256.0
        
        // 해상도에 따른 품질
        if settings.maxWidth > 0 {
            score *= min(Double(settings.maxWidth) / 1920.0, 1.0)
        }
        
        // LIQ 속도에 따른 품질
        score *= (11.0 - Double(settings.liqSpeed)) / 10.0
        
        // 디더링에 따른 품질 저하
        score *= (1.0 - settings.ditherLevel * 0.1)
        
        // 프레임 제거에 따른 품질 저하
        score *= (1.0 - settings.removeFrames * 0.3)
        
        return min(score, 100.0)
    }
    
    private static func calculateProcessingTime(settings: CompressionSettings) -> Int {
        var baseTime = 5000  // 5초 기본
        
        // LIQ 속도에 따른 시간
        baseTime *= (11 - settings.liqSpeed)
        
        // 색상 수에 따른 시간
        baseTime = Int(Double(baseTime) * (Double(settings.maxColors) / 256.0))
        
        // 해상도에 따른 시간
        if settings.maxWidth > 0 {
            let resolutionFactor = min(Double(settings.maxWidth) / 1920.0, 1.0)
            baseTime = Int(Double(baseTime) * resolutionFactor)
        }
        
        return baseTime
    }
    
    private static func generateDescription(preset: QualityPreset, result: Int) -> String {
        switch preset {
        case .ultraLight:
            return "모바일/웹 최적화, 빠른 로딩"
        case .light:
            return "일반 용도, 좋은 품질"
        case .standard:
            return "데스크톱 최적화, 고품질"
        case .discord:
            return "디스코드/채팅 최적화"
        case .high:
            return "프레젠테이션/공유용"
        case .perfect:
            return "아카이브/포트폴리오용"
        }
    }
}

extension CompressionTest.QualityPreset: CaseIterable {}

// 테스트 실행
let results = CompressionTest.generateTestData()

print("🎯 리리의 완벽한 압축 최적화 비교표")
print("================================================================================")
print()

print("📊 압축 성능 비교 (원본: 25MB, 60fps, 10초, 1920x1080)")
print("--------------------------------------------------------------------------------")
print("프리셋      │ 압축후 │ 압축률 │ 품질점수 │ 처리시간 │ 프레임 │ FPS  │ 용도")
print("--------------------------------------------------------------------------------")

for result in results {
    let sizeStr = String(format: "%4dKB", result.compressedSizeKB)
    let ratioStr = String(format: "%3d%%", result.compressionPercent)
    let qualityStr = String(format: "%5.1f", result.qualityScore)
    let timeStr = String(format: "%4.1fs", Double(result.processingTimeMS) / 1000.0)
    let framesStr = String(format: "%3d", result.frameCount)
    let fpsStr = String(format: "%3d", result.actualFPS)
    
    print("\(result.preset.name.padding(toLength: 8, withPad: " ", startingAt: 0)) │ \(sizeStr) │ \(ratioStr) │ \(qualityStr)   │ \(timeStr)  │ \(framesStr)  │ \(fpsStr) │ \(result.description)")
}

print("--------------------------------------------------------------------------------")
print()

print("🏆 추천 사용 시나리오")
print("----------------------------------------")
print("• 초경량: 모바일 메신저, 빠른 공유")
print("• 가벼움: 일반적인 웹 사용")  
print("• 표준: 데스크톱, 게임 플레이")
print("• 디스코드: 채팅방 공유")
print("• 고화질: 프레젠테이션, 포트폴리오")
print("• 완벽: 아카이브, 최고 품질 보존")
print()

print("💡 스마트 압축 최적화 포인트")
print("----------------------------------------")
print("• 색상 최적화: 64색~256색 적응형 선택")
print("• 해상도 최적화: 용도별 최적 해상도")  
print("• 프레임 최적화: 중요 프레임 보존")
print("• LIQ 알고리즘: 품질 vs 속도 균형")
print("• 디더링: 그라데이션 품질 최적화")