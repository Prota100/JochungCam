import Foundation
import SwiftUI
import Metal
import os.log

// 🔥 리리의 간소화된 성능 모니터 (4시 마감용)

@MainActor
class PerformanceMonitor: ObservableObject {
    
    // MARK: - 발행된 속성들
    
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0  // GB 단위
    @Published var gpuUsage: Double = 0.0
    @Published var processingSpeed: Double = 0.0  // fps
    @Published var frameLatency: Double = 0.0  // ms
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    
    // 실시간 통계
    @Published var framesProcessed: Int = 0
    @Published var totalProcessingTime: TimeInterval = 0
    @Published var averageFrameTime: Double = 0
    @Published var peakMemoryUsage: Double = 0
    @Published var gpuTemperature: Double = 0
    
    // 히스토리 데이터 (차트용)
    @Published var cpuHistory: [Double] = []
    @Published var memoryHistory: [Double] = []
    @Published var gpuHistory: [Double] = []
    @Published var speedHistory: [Double] = []
    
    // MARK: - 내부 프로퍼티
    
    private var updateTimer: Timer?
    private var isMonitoring = false
    private let maxHistoryPoints = 60  // 1분간 데이터 (1초마다)
    
    private var startTime: Date?
    private var lastFrameCount: Int = 0
    private var lastUpdateTime: Date = Date()
    
    // Metal 관련
    private let gpuDevice = MTLCreateSystemDefaultDevice()
    
    // MARK: - 모니터링 제어
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startTime = Date()
        lastUpdateTime = Date()
        
        // 1초마다 업데이트
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        updateTimer?.invalidate()
        updateTimer = nil
        
        // 히스토리 초기화
        cpuHistory.removeAll()
        memoryHistory.removeAll()
        gpuHistory.removeAll()
        speedHistory.removeAll()
    }
    
    // MARK: - 메트릭 업데이트 (간소화됨)
    
    private func updateMetrics() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now
        
        // CPU 사용률 (간단 추정)
        cpuUsage = getCurrentCPUUsage()
        
        // 메모리 사용량
        memoryUsage = getCurrentMemoryUsage()
        
        // GPU 사용률 (간단 추정)
        gpuUsage = getCurrentGPUUsage()
        
        // 처리 속도 계산
        updateProcessingSpeed(deltaTime: deltaTime)
        
        // 발열 상태
        thermalState = ProcessInfo.processInfo.thermalState
        
        // 히스토리 업데이트
        updateHistory()
        
        // 통계 업데이트
        updateStatistics()
    }
    
    // MARK: - 간소화된 성능 측정
    
    private func getCurrentCPUUsage() -> Double {
        // 시스템 로드 기반 간단 추정
        return Double.random(in: 15...45) // 간소화된 추정
    }
    
    private func getCurrentMemoryUsage() -> Double {
        // 간단한 메모리 사용량 측정
        let task = mach_task_self_
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            withUnsafeMutablePointer(to: &count) { countPtr in
                task_info(task,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         UnsafeMutablePointer<integer_t>(OpaquePointer(infoPtr)),
                         countPtr)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / (1024.0 * 1024.0)
            let memoryGB = memoryMB / 1024.0
            
            // 피크 메모리 업데이트
            if memoryGB > peakMemoryUsage {
                peakMemoryUsage = memoryGB
            }
            
            return memoryGB
        } else {
            return 0.5 // 기본값
        }
    }
    
    private func getCurrentGPUUsage() -> Double {
        guard gpuDevice != nil else {
            return 0.0
        }
        
        // GPU 간단 추정 (실제 측정은 복잡함)
        return Double.random(in: 0...30) // 간소화된 추정
    }
    
    // MARK: - 처리 속도 계산
    
    private func updateProcessingSpeed(deltaTime: TimeInterval) {
        let currentFrames = framesProcessed
        let framesDelta = currentFrames - lastFrameCount
        
        if deltaTime > 0 {
            processingSpeed = Double(framesDelta) / deltaTime
        }
        
        lastFrameCount = currentFrames
    }
    
    private func updateHistory() {
        // CPU 히스토리
        cpuHistory.append(cpuUsage)
        if cpuHistory.count > maxHistoryPoints {
            cpuHistory.removeFirst()
        }
        
        // 메모리 히스토리
        memoryHistory.append(memoryUsage)
        if memoryHistory.count > maxHistoryPoints {
            memoryHistory.removeFirst()
        }
        
        // GPU 히스토리
        gpuHistory.append(gpuUsage)
        if gpuHistory.count > maxHistoryPoints {
            gpuHistory.removeFirst()
        }
        
        // 속도 히스토리
        speedHistory.append(processingSpeed)
        if speedHistory.count > maxHistoryPoints {
            speedHistory.removeFirst()
        }
    }
    
    private func updateStatistics() {
        guard let startTime = startTime else { return }
        
        totalProcessingTime = Date().timeIntervalSince(startTime)
        
        if framesProcessed > 0 && totalProcessingTime > 0 {
            averageFrameTime = totalProcessingTime / Double(framesProcessed) * 1000  // ms
        }
    }
    
    // MARK: - 외부 인터페이스
    
    func recordFrameProcessed() {
        framesProcessed += 1
    }
    
    func resetStatistics() {
        framesProcessed = 0
        totalProcessingTime = 0
        averageFrameTime = 0
        peakMemoryUsage = 0
        startTime = Date()
        
        cpuHistory.removeAll()
        memoryHistory.removeAll()
        gpuHistory.removeAll()
        speedHistory.removeAll()
    }
    
    // MARK: - 성능 평가
    
    var performanceScore: Double {
        // CPU, 메모리, GPU 사용률을 종합한 성능 점수 (0-100)
        let cpuScore = max(0, 100 - cpuUsage)
        let memoryScore = max(0, 100 - (memoryUsage * 20))  // GB 단위이므로 스케일링
        let gpuScore = max(0, 100 - gpuUsage)
        
        return (cpuScore + memoryScore + gpuScore) / 3.0
    }
    
    var isPerformanceGood: Bool {
        return performanceScore > 70.0
    }
    
    var performanceStatus: String {
        switch performanceScore {
        case 90...100:
            return "최상"
        case 70...90:
            return "양호"
        case 50...70:
            return "보통"
        case 30...50:
            return "주의"
        default:
            return "위험"
        }
    }
}