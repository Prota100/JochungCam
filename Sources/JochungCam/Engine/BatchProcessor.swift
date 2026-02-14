import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

// 🚀 리리의 프로페셔널 배치 처리 시스템

@MainActor
class BatchProcessor: ObservableObject {
    
    // MARK: - 배치 작업 상태
    
    @Published var isProcessing: Bool = false
    @Published var totalJobs: Int = 0
    @Published var completedJobs: Int = 0
    @Published var currentJob: BatchJob?
    @Published var overallProgress: Double = 0.0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var processingSpeed: Double = 0.0 // jobs per minute
    
    @Published var jobs: [BatchJob] = []
    private var startTime: Date?
    private let maxConcurrentJobs = ProcessInfo.processInfo.processorCount
    
    // MARK: - 배치 작업 설정
    
    struct BatchSettings {
        var outputFormat: String = "gif" // gif, mp4, webp
        var outputDirectory: URL
        var fileNaming: FileNaming = .keepOriginal
        var qualitySettings: QualitySettings = .balanced
        var processingOptions: ProcessingOptions = .default
        var shouldOverwrite: Bool = false
        
        enum FileNaming: Hashable {
            case keepOriginal
            case addSuffix(String)
            case sequential(String) // prefix
            case timestamp
            case custom((URL) -> String)
            
            func hash(into hasher: inout Hasher) {
                switch self {
                case .keepOriginal:
                    hasher.combine("keepOriginal")
                case .addSuffix(let string):
                    hasher.combine("addSuffix")
                    hasher.combine(string)
                case .sequential(let string):
                    hasher.combine("sequential")
                    hasher.combine(string)
                case .timestamp:
                    hasher.combine("timestamp")
                case .custom(_):
                    hasher.combine("custom")
                }
            }
            
            static func == (lhs: FileNaming, rhs: FileNaming) -> Bool {
                switch (lhs, rhs) {
                case (.keepOriginal, .keepOriginal),
                     (.timestamp, .timestamp):
                    return true
                case (.addSuffix(let lhsString), .addSuffix(let rhsString)),
                     (.sequential(let lhsString), .sequential(let rhsString)):
                    return lhsString == rhsString
                case (.custom(_), .custom(_)):
                    return false // 클로저는 비교 불가
                default:
                    return false
                }
            }
        }
        
        enum QualitySettings: Hashable {
            case balanced      // 균형
            case highQuality   // 고품질  
            case lossless      // 무손실
            case custom(GIFEncoder.Options)
            
            func hash(into hasher: inout Hasher) {
                switch self {
                case .balanced:
                    hasher.combine("balanced")
                case .highQuality:
                    hasher.combine("highQuality")
                case .lossless:
                    hasher.combine("lossless")
                case .custom(_):
                    hasher.combine("custom")
                }
            }
            
            static func == (lhs: QualitySettings, rhs: QualitySettings) -> Bool {
                switch (lhs, rhs) {
                case (.balanced, .balanced),
                     (.highQuality, .highQuality),
                     (.lossless, .lossless):
                    return true
                case (.custom(_), .custom(_)):
                    return true
                default:
                    return false
                }
            }
        }
        
        enum ProcessingOptions {
            case `default`
            case fastPreview
            case highQuality
            case custom([ImageOperation])
        }
    }
    
    // MARK: - 배치 작업 정의
    
    class BatchJob: ObservableObject, Identifiable {
        let id = UUID()
        let inputFile: URL
        let outputFile: URL
        let settings: BatchSettings
        
        @Published var status: JobStatus = .pending
        @Published var progress: Double = 0.0
        @Published var error: Error?
        @Published var startTime: Date?
        @Published var endTime: Date?
        @Published var inputSize: Int64 = 0
        @Published var outputSize: Int64 = 0
        
        enum JobStatus {
            case pending
            case processing
            case completed
            case failed
            case cancelled
            
            var displayName: String {
                switch self {
                case .pending: return "대기 중"
                case .processing: return "처리 중"
                case .completed: return "완료"
                case .failed: return "실패"
                case .cancelled: return "취소됨"
                }
            }
            
            var color: Color {
                switch self {
                case .pending: return .gray
                case .processing: return .blue
                case .completed: return .green
                case .failed: return .red
                case .cancelled: return .orange
                }
            }
        }
        
        var duration: TimeInterval? {
            guard let start = startTime, let end = endTime else { return nil }
            return end.timeIntervalSince(start)
        }
        
        var compressionRatio: Double? {
            guard inputSize > 0 && outputSize > 0 else { return nil }
            return Double(outputSize) / Double(inputSize)
        }
        
        init(inputFile: URL, outputFile: URL, settings: BatchSettings) {
            self.inputFile = inputFile
            self.outputFile = outputFile
            self.settings = settings
            
            // 입력 파일 크기 확인
            if let attributes = try? FileManager.default.attributesOfItem(atPath: inputFile.path),
               let size = attributes[.size] as? Int64 {
                inputSize = size
            }
        }
    }
    
    // MARK: - 배치 작업 관리
    
    func addFiles(_ urls: [URL], settings: BatchSettings) {
        for url in urls {
            let outputURL = generateOutputURL(for: url, settings: settings)
            let job = BatchJob(inputFile: url, outputFile: outputURL, settings: settings)
            jobs.append(job)
        }
        
        totalJobs = jobs.count
        updateProgress()
    }
    
    func addDirectory(_ directoryURL: URL, settings: BatchSettings, recursive: Bool = true) {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: directoryURL, 
                                                    includingPropertiesForKeys: [.isRegularFileKey],
                                                    options: recursive ? [] : [.skipsSubdirectoryDescendants]) else {
            return
        }
        
        let supportedTypes = [UTType.movie, UTType.quickTimeMovie, UTType.mpeg4Movie]
        var foundFiles: [URL] = []
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else { continue }
            
            if let contentType = resourceValues.contentType,
               supportedTypes.contains(where: { contentType.conforms(to: $0) }) {
                foundFiles.append(fileURL)
            }
        }
        
        addFiles(foundFiles, settings: settings)
    }
    
    private func generateOutputURL(for inputURL: URL, settings: BatchSettings) -> URL {
        let inputName = inputURL.deletingPathExtension().lastPathComponent
        let outputExtension = settings.outputFormat
        
        let outputName: String
        
        switch settings.fileNaming {
        case .keepOriginal:
            outputName = inputName
            
        case .addSuffix(let suffix):
            outputName = "\(inputName)\(suffix)"
            
        case .sequential(let prefix):
            let jobIndex = jobs.count + 1
            outputName = "\(prefix)_\(String(format: "%03d", jobIndex))"
            
        case .timestamp:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            outputName = "\(inputName)_\(formatter.string(from: Date()))"
            
        case .custom(let generator):
            outputName = generator(inputURL)
        }
        
        return settings.outputDirectory
            .appendingPathComponent(outputName)
            .appendingPathExtension(outputExtension)
    }
    
    // MARK: - 배치 처리 실행
    
    func startProcessing() async {
        guard !isProcessing && !jobs.isEmpty else { return }
        
        isProcessing = true
        completedJobs = 0
        startTime = Date()
        
        // 동시 작업 수만큼 태스크 생성
        await withTaskGroup(of: Void.self) { group in
            let jobChunks = jobs.chunked(into: maxConcurrentJobs)
            
            for chunk in jobChunks {
                for job in chunk {
                    group.addTask {
                        await self.processJob(job)
                    }
                }
                
                // 현재 청크의 모든 작업이 완료될 때까지 대기
                await group.waitForAll()
            }
        }
        
        isProcessing = false
        
        // 완료 통지
        showCompletionNotification()
    }
    
    private func processJob(_ job: BatchJob) async {
        await MainActor.run {
            job.status = .processing
            job.startTime = Date()
            currentJob = job
        }
        
        do {
            // MOV 파일 임포트 (임시 구현)
            let frames = await FrameOps.importVideo(from: job.inputFile, fps: 60.0) { progress, _ in
                Task { @MainActor in
                    job.progress = progress * 0.3 // 30%까지는 임포트
                }
            } ?? []
            
            // 처리 옵션 적용
            let processedFrames = try await applyProcessingOptions(frames, options: job.settings.processingOptions) { progress in
                Task { @MainActor in
                    job.progress = 0.3 + (progress * 0.4) // 30%~70%는 처리
                }
            }
            
            // 품질 설정 적용
            let exportOptions = getExportOptions(for: job.settings.qualitySettings)
            
            // 내보내기
            switch job.settings.outputFormat {
            case "gif":
                try await GIFEncoder.encode(frames: processedFrames, to: job.outputFile, options: exportOptions) { progress in
                    Task { @MainActor in
                        job.progress = 0.7 + (progress * 0.3) // 70%~100%는 내보내기
                    }
                }
            case "mp4":
                try await MP4Encoder.encode(frames: processedFrames, to: job.outputFile, quality: 80) { progress in
                    Task { @MainActor in
                        job.progress = 0.7 + (progress * 0.3)
                    }
                }
            case "webp":
                let webpOptions = WebPEncoder.Options(quality: 90, lossless: false, fps: 60, loopCount: 0, maxWidth: 0)
                try WebPEncoder.encode(frames: processedFrames, to: job.outputFile, options: webpOptions) { progress in
                    Task { @MainActor in
                        job.progress = 0.7 + (progress * 0.3)
                    }
                }
            default:
                // 지원하지 않는 형식
                throw NSError(domain: "BatchProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "지원하지 않는 출력 형식: \(job.settings.outputFormat)"])
            }
            
            // 완료 처리
            await MainActor.run {
                job.status = .completed
                job.endTime = Date()
                job.progress = 1.0
                
                // 출력 파일 크기 확인
                if let attributes = try? FileManager.default.attributesOfItem(atPath: job.outputFile.path),
                   let size = attributes[.size] as? Int64 {
                    job.outputSize = size
                }
                
                completedJobs += 1
                updateProgress()
            }
            
        } catch {
            await MainActor.run {
                job.status = .failed
                job.error = error
                job.endTime = Date()
                completedJobs += 1
                updateProgress()
            }
        }
    }
    
    private func applyProcessingOptions(_ frames: [GIFFrame], options: BatchSettings.ProcessingOptions, progressCallback: @escaping (Double) -> Void) async throws -> [GIFFrame] {
        
        let operations: [ImageOperation]
        
        switch options {
        case .default:
            operations = []
            
        case .fastPreview:
            operations = [
                .resize(CGSize(width: 480, height: 360)),
                .colorAdjust(brightness: 0.0, contrast: 1.1, saturation: 1.1)
            ]
            
        case .highQuality:
            operations = [
                .noiseReduction(strength: 0.3),
                .sharpen(intensity: 0.2),
                .colorAdjust(brightness: 0.05, contrast: 1.05, saturation: 1.02)
            ]
            
        case .custom(let customOperations):
            operations = customOperations
        }
        
        if operations.isEmpty {
            progressCallback(1.0)
            return frames
        }
        
        // GPU 가속 처리 시도
        let gpuAccelerator = GPUAccelerator()
        return try await gpuAccelerator.processFramesGPU(
            frames: frames, 
            operations: operations, 
            progressCallback: progressCallback
        )
    }
    
    private func getExportOptions(for quality: BatchSettings.QualitySettings) -> GIFEncoder.Options {
        switch quality {
        case .balanced:
            return GIFEncoder.Options(
                maxColors: 128,
                dither: true,
                ditherLevel: 0.6,
                speed: 2,
                quality: 85,
                maxWidth: 640,
                maxFileSizeKB: 3000,
                removeSimilarPixels: true
            )
            
        case .highQuality:
            return GIFEncoder.Options(
                maxColors: 256,
                dither: false,
                ditherLevel: 0.4,
                speed: 3,
                quality: 95,
                maxWidth: 0,
                maxFileSizeKB: 0,
                removeSimilarPixels: false
            )
            
        case .lossless:
            return GIFEncoder.Options(
                maxColors: 256,
                dither: false,
                ditherLevel: 0.0,
                speed: 10,
                quality: 100,
                maxWidth: 0,
                maxFileSizeKB: 0,
                removeSimilarPixels: false
            )
            
        case .custom(let options):
            return options
        }
    }
    
    // MARK: - 진행률 및 통계
    
    private func updateProgress() {
        guard totalJobs > 0 else {
            overallProgress = 0.0
            return
        }
        
        let totalProgress = jobs.reduce(0.0) { $0 + $1.progress }
        overallProgress = totalProgress / Double(totalJobs)
        
        // 남은 시간 추정
        updateTimeEstimate()
        
        // 처리 속도 계산
        updateProcessingSpeed()
    }
    
    private func updateTimeEstimate() {
        guard let startTime = startTime,
              completedJobs > 0,
              completedJobs < totalJobs else {
            estimatedTimeRemaining = 0
            return
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let averageTimePerJob = elapsedTime / Double(completedJobs)
        let remainingJobs = totalJobs - completedJobs
        
        estimatedTimeRemaining = averageTimePerJob * Double(remainingJobs)
    }
    
    private func updateProcessingSpeed() {
        guard let startTime = startTime,
              completedJobs > 0 else {
            processingSpeed = 0.0
            return
        }
        
        let elapsedMinutes = Date().timeIntervalSince(startTime) / 60.0
        processingSpeed = Double(completedJobs) / elapsedMinutes
    }
    
    // MARK: - 작업 제어
    
    func pauseProcessing() {
        // 현재 작업들을 일시 정지 (구현 필요)
    }
    
    func cancelProcessing() {
        // 모든 작업 취소
        for job in jobs where job.status == .pending || job.status == .processing {
            job.status = .cancelled
        }
        
        isProcessing = false
    }
    
    func clearCompletedJobs() {
        jobs.removeAll { $0.status == .completed }
        totalJobs = jobs.count
        completedJobs = jobs.filter { $0.status == .completed }.count
        updateProgress()
    }
    
    func clearAllJobs() {
        jobs.removeAll()
        totalJobs = 0
        completedJobs = 0
        overallProgress = 0.0
        estimatedTimeRemaining = 0
        processingSpeed = 0.0
    }
    
    // MARK: - 완료 알림
    
    private func showCompletionNotification() {
        let successCount = jobs.filter { $0.status == .completed }.count
        let failureCount = jobs.filter { $0.status == .failed }.count

        let content = UNMutableNotificationContent()
        content.title = "배치 처리 완료"
        content.body = "성공: \(successCount)개, 실패: \(failureCount)개"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "jochungcam.batch.complete.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - 통계 정보
    
    var statistics: BatchStatistics {
        let completed = jobs.filter { $0.status == .completed }
        let failed = jobs.filter { $0.status == .failed }
        
        let totalInputSize = completed.reduce(0) { $0 + $1.inputSize }
        let totalOutputSize = completed.reduce(0) { $0 + $1.outputSize }
        let averageCompressionRatio = completed.compactMap { $0.compressionRatio }.reduce(0, +) / Double(completed.count)
        
        let totalProcessingTime = completed.compactMap { $0.duration }.reduce(0, +)
        let averageProcessingTime = totalProcessingTime / Double(completed.count)
        
        return BatchStatistics(
            totalJobs: totalJobs,
            completedJobs: completed.count,
            failedJobs: failed.count,
            totalInputSizeMB: Double(totalInputSize) / (1024 * 1024),
            totalOutputSizeMB: Double(totalOutputSize) / (1024 * 1024),
            averageCompressionRatio: averageCompressionRatio,
            totalProcessingTime: totalProcessingTime,
            averageProcessingTime: averageProcessingTime
        )
    }
}

// MARK: - 배치 통계

struct BatchStatistics {
    let totalJobs: Int
    let completedJobs: Int
    let failedJobs: Int
    let totalInputSizeMB: Double
    let totalOutputSizeMB: Double
    let averageCompressionRatio: Double
    let totalProcessingTime: TimeInterval
    let averageProcessingTime: TimeInterval
    
    var successRate: Double {
        guard totalJobs > 0 else { return 0.0 }
        return Double(completedJobs) / Double(totalJobs)
    }
    
    var spaceSavedMB: Double {
        return totalInputSizeMB - totalOutputSizeMB
    }
    
    var spaceSavedPercentage: Double {
        guard totalInputSizeMB > 0 else { return 0.0 }
        return (spaceSavedMB / totalInputSizeMB) * 100
    }
}

// MARK: - 배열 확장 (청크 분할) - 이미 다른 곳에 정의되어 있음