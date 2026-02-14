import SwiftUI
import Combine

enum AppMode: Equatable {
    case home
    case selecting
    case recording
    case paused
    case editing
    case cropping
    case saving
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case gif = "GIF"
    case webp = "WebP"
    case apng = "APNG"
    case mp4 = "MP4"
    var id: String { rawValue }
    var ext: String { rawValue.lowercased() }
}

enum QuantMethod: String, CaseIterable, Identifiable {
    case liq = "LIQ"
    case neuquant = "NeuQuant"
    case octree = "Octree"
    var id: String { rawValue }
}

enum GIFQuality: String, CaseIterable, Identifiable {
    case high = "256색"
    case medium = "128색"
    case low = "64색"
    case tiny = "32색"
    var id: String { rawValue }
    var maxColors: Int {
        switch self { case .high: 256; case .medium: 128; case .low: 64; case .tiny: 32 }
    }
}

enum GIFSizePreset: String, CaseIterable, Identifiable {
    case light = "가벼움"           // 1MB, 적당한 해상도 + 30fps
    case normal = "표준"            // 3MB, 좋은 해상도 + 30fps
    case discord = "디스코드"       // 10MB 제한 + 30fps
    case high = "고화질"            // 큰 파일, 원본 해상도 + 60fps

    var id: String { rawValue }
    var label: String { rawValue }

    var maxWidth: Int {
        switch self {
        case .light: return 500         // 가벼움: 500px (웹 최적화!)
        case .normal: return 800        // 표준: 800px (데스크톱 최적화!)
        case .discord: return 720       // 디스코드: 720px (채팅 최적화!)
        case .high: return 0            // 고화질: 원본 해상도
        }
    }
    
    var quality: GIFQuality {
        switch self {
        case .light: return .low         // 가벼움: 64색 (웹 최적화!)
        case .normal: return .medium     // 표준: 128색 (균형잡힌 품질!)
        case .discord: return .high      // 디스코드: 256색 (채팅 품질!)
        case .high: return .high         // 고화질: 256색 (완벽 품질!)
        }
    }
    
    var maxFileSizeKB: Int {
        switch self {
        case .light: return 1000         // 가벼움: 1MB (웹 최적화!)
        case .normal: return 3000        // 표준: 3MB (데스크톱 최적화!)
        case .discord: return 8000       // 디스코드: 8MB (채팅 최적화!)
        case .high: return 0             // 고화질: 무제한
        }
    }
    
    var liqSpeed: Int {
        switch self {
        case .high: return 1             // 고화질: 최고 품질 (완벽한 압축!)
        case .light: return 4            // 가벼움: 균형잡힌 압축
        case .normal: return 2           // 표준: 고품질 압축
        case .discord: return 3          // 디스코드: 좋은 압축
        }
    }
    
    var fps: Int {
        switch self {
        case .light: return 30           // 가벼움: 30fps (모바일 최적화)
        case .normal: return 60          // 표준: 60fps (진짜 표준! ⚡)
        case .discord: return 60         // 디스코드: 60fps (부드러움!)
        case .high: return 120           // 고화질: 120fps (최고급 게임! 🚀)
        }
    }
    
    // 압축 공격성 (품질 vs 용량)
    var aggressiveCompression: Bool {
        switch self {
        case .light: return true         // 가벼움만 적극 압축
        default: return false            // 나머지는 품질 우선
        }
    }
}

struct SizePreset: Identifiable {
    let id = UUID()
    let label: String
    let width: Int
    let height: Int
    static let presets: [SizePreset] = [
        .init(label: "320×240", width: 320, height: 240),
        .init(label: "480×360", width: 480, height: 360),
        .init(label: "640×480", width: 640, height: 480),
        .init(label: "800×600", width: 800, height: 600),
        .init(label: "1024×768", width: 1024, height: 768),
        .init(label: "1280×720", width: 1280, height: 720),
        .init(label: "1920×1080", width: 1920, height: 1080),
    ]
}

@MainActor
final class AppState: ObservableObject {
    // Mode
    @Published var mode: AppMode = .home

    // 🎯 리리의 완전무결한 Undo/Redo 시스템
    let undoSystem = UndoSystem()

    // Recording settings
    @Published var fps: Int = 60             // 기본: 60fps (게임 품질, 매끄러움!)
    @Published var customFps: String = "60"
    @Published var cursorCapture: Bool = true
    @Published var countdown: Int = 0  // 0=off, 3, 5
    @Published var skipSameFrames: Bool = true
    @Published var maxRecordSeconds: Int = 60
    @Published var rememberRegion: Bool = false
    @Published var lastRegion: CGRect = .zero
    @Published var captureMode: CaptureMode = .region

    enum CaptureMode: String, CaseIterable { case region = "영역"; case fullscreen = "전체"; case halfscreen = "1/2"; case quarterscreen = "1/4" }

    // Recording state
    @Published var selectedRegion: CGRect = .zero
    @Published var recordingDuration: TimeInterval = 0
    @Published var frameCount: Int = 0

    // Frames
    @Published var frames: [GIFFrame] = []
    @Published var selectedFrameIndex: Int = 0
    @Published var selectedFrameRange: Range<Int>? = nil

    // Export settings  
    @Published var outputFormat: OutputFormat = .gif
    @Published var gifQuality: GIFQuality = .low     // 🚀 기본을 low로 (QuickTime 변환에 최적화)
    @Published var quantMethod: QuantMethod = .liq
    @Published var useDither: Bool = true
    @Published var ditherLevel: Float = 1.0
    @Published var centerFocusedDither: Bool = false  // 중심색 포커스 디더링 (꿀캠 IDC_CHK_CENTER_FOCUSED_COLOR_DITHER)
    @Published var skipQuantizeWhenQ100: Bool = true   // Q100이면 양자화 스킵 (꿀캠 IDC_CHK_SKIP_QUANTIZE_WHEN_Q_100)
    @Published var removeSimilarPixels: Bool = true    // 🚀 기본 켜기! (가장 효과적)
    @Published var liqSpeed: Int = 2       // 🚀 더 느리게 해서 품질 향상 (4→2)
    @Published var liqQuality: Int = 95    // 🚀 더 높은 품질 (90→95)
    @Published var maxWidth: Int = 480     // 🚀 더 작게 (640→480, QuickTime 최적화)
    @Published var maxFileSizeKB: Int = 1000  // 🚀 더 공격적 (3MB→1MB)
    @Published var loopCount: Int = 0      // 0=infinite
    @Published var webpQuality: Int = 85
    @Published var webpLossless: Bool = false
    @Published var mp4Quality: Int = 80
    @Published var useGifski: Bool = true  // gifski 사용 (크로스프레임 최적화)
    
    // Cursor effects (꿀캠 IDC_CHK_CAPTURE_CURSOR_*)
    @Published var cursorEffect: Bool = false
    @Published var cursorHighlight: Bool = false
    @Published var cursorHighlightColor: NSColor = .yellow.withAlphaComponent(0.3)
    @Published var cursorLeftClickColor: NSColor = .red.withAlphaComponent(0.5)
    @Published var cursorRightClickColor: NSColor = .blue.withAlphaComponent(0.5)
    
    // Direct save (꿀캠 IDC_CHK_DO_NOT_KEEP_FRAME_WHILE_DIRECT_SAVE)
    @Published var directSave: Bool = false
    @Published var directSavePath: String = ""
    @Published var directSaveQuality: Int = 80
    @Published var openEditAfterRecording: Bool = true  // 꿀캠 IDC_CHK_OPEN_EDIT_DIRECTLY_AFTER_RECORDING

    // Status
    @Published var saveProgress: Double = 0
    @Published var statusText: String = ""
    @Published var errorText: String?

    // Crop
    @Published var cropRect: CGRect = .zero
    
    // UI
    @Published var showBatch: Bool = false
    
    // Speed control
    @Published var speedMultiplier: Double = 1.0
    
    // Advanced compression settings
    @Published var smartCompression: Bool = true     // 스마트 압축 활성화
    @Published var adaptiveQuality: Bool = true      // 적응형 품질 조정
    @Published var frameOptimization: Bool = true    // 프레임 최적화

    let fpsPresets = [60, 30, 120, 24]      // 의미있는 FPS: 게임(기본), 웹, 초고품질, 영화
    static let maxFrames = 3000
    static let maxSeconds: TimeInterval = 300

    func reset() {
        mode = .home
        frames = []
        selectedFrameIndex = 0
        selectedFrameRange = nil
        recordingDuration = 0
        frameCount = 0
        saveProgress = 0
        statusText = ""
        errorText = nil
        cropRect = .zero
    }

    func enterEditor(with capturedFrames: [GIFFrame]) {
        // 메모리 보호: 예상 메모리 계산
        if let first = capturedFrames.first {
            let bytesPerFrame = first.image.width * first.image.height * 4
            let totalMB = bytesPerFrame * capturedFrames.count / 1_048_576
            if totalMB > 4096 {
                // 4GB 초과 시 자동 리사이즈
                frames = capturedFrames.map { f in
                    var out = f
                    out.image = downscale(f.image, factor: 2) ?? f.image
                    return out
                }
                statusText = "⚠️ 메모리 보호: 자동 축소됨 (\(totalMB)MB → ~\(totalMB/4)MB)"
            } else {
                frames = capturedFrames.map { f in
                    var out = f
                    if f.image.width > 2560 {
                        out.image = downscale(f.image, factor: 2) ?? f.image
                    }
                    return out
                }
            }
        } else {
            frames = capturedFrames
        }
        selectedFrameIndex = 0
        mode = .editing
    }

    private func downscale(_ img: CGImage, factor: Int) -> CGImage? {
        let nw = img.width / factor, nh = img.height / factor
        guard let ctx = CGContext(
            data: nil, width: nw, height: nh, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        return ctx.makeImage()
    }

    var totalDuration: TimeInterval { frames.reduce(0) { $0 + $1.duration } }
    var frameSize: String { guard let f = frames.first else { return "" }; return "\(f.image.width)×\(f.image.height)" }
    var estimatedSize: String {
        guard let f = frames.first else { return "" }
        let px = f.image.width * f.image.height
        let bpf = Double(px) * Double(gifQuality.maxColors) / 256.0 * 0.4
        let total = bpf * Double(frames.count)
        return total > 1_048_576 ? String(format: "~%.1fMB", total/1_048_576) : String(format: "~%.0fKB", total/1024)
    }

    func parseFps() {
        if let v = Int(customFps), v >= 1, v <= 120 { fps = v }
    }
    
    // MARK: - 🎯 리리의 완전무결한 편집 메서드들
    
    /// 프레임 삭제 (Undo 지원)
    func deleteFrame(at index: Int) {
        guard frames.indices.contains(index), frames.count > 1 else { return }
        
        let command = DeleteFrameCommand(
            frameIndex: index,
            deletedFrame: frames[index]
        )
        
        undoSystem.execute(command, frames: &frames)
        
        // 선택 인덱스 조정
        selectedFrameIndex = min(selectedFrameIndex, frames.count - 1)
        statusText = "프레임 삭제됨"
    }
    
    /// 트림 (구간 자르기) - Undo 지원
    func trimFrames(to range: Range<Int>) {
        guard range.upperBound <= frames.count, !range.isEmpty else { return }
        
        let command = TrimFramesCommand(
            originalFrames: frames,  // 전체 원본 저장
            trimRange: range
        )
        
        undoSystem.execute(command, frames: &frames)
        
        selectedFrameIndex = 0
        statusText = "트림 → \(range.count)프레임"
    }
    
    /// 크롭 (이미지 자르기) - Undo 지원
    func cropFrames(to rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        
        let command = CropCommand(
            originalFrames: frames,  // 크롭 전 원본
            cropRect: rect
        )
        
        undoSystem.execute(command, frames: &frames)
        
        let w = Int(rect.width), h = Int(rect.height)
        statusText = "크롭 → \(w)×\(h)"
    }
    
    /// 속도 조절 - Undo 지원
    func adjustSpeed(multiplier: Double) {
        let originalDurations = frames.map { $0.duration }
        
        let command = SpeedAdjustCommand(
            speedMultiplier: multiplier,
            originalDurations: originalDurations
        )
        
        undoSystem.execute(command, frames: &frames)
        
        let percent = Int(multiplier * 100)
        statusText = "속도 \(percent)% 적용"
    }
    
    /// 프레임 순서/개수 조작 - Undo 지원  
    func reorderFrames(operation: ReorderFramesCommand.FrameReorderType) {
        let command = ReorderFramesCommand(
            originalOrder: frames,
            operationType: operation
        )
        
        undoSystem.execute(command, frames: &frames)
        
        // 선택 인덱스 조정
        selectedFrameIndex = min(selectedFrameIndex, frames.count - 1)
        statusText = "\(operation.description) 적용"
    }
    
    /// 유사 프레임 제거 - Undo 지원
    func removeSimilarFrames(threshold: Int = 5) {
        let command = RemoveSimilarCommand(
            originalFrames: frames,
            threshold: threshold
        )
        
        let beforeCount = frames.count
        undoSystem.execute(command, frames: &frames)
        
        let removedCount = beforeCount - frames.count
        statusText = "유사 프레임 \(removedCount)개 제거"
        
        // 선택 인덱스 조정
        selectedFrameIndex = min(selectedFrameIndex, frames.count - 1)
    }
    
    /// 프레임 duration 설정 - Undo 지원
    func setFrameDuration(index: Int?, duration: TimeInterval) {
        let originalDurations = frames.map { $0.duration }
        
        let command = SetFrameDurationCommand(
            frameIndex: index,
            newDuration: duration,
            originalDurations: originalDurations
        )
        
        undoSystem.execute(command, frames: &frames)
        
        if let idx = index {
            statusText = "프레임 \(idx + 1) 시간 설정"
        } else {
            statusText = "전체 프레임 시간 설정"
        }
    }
    
    /// Undo 실행
    func undo() {
        if undoSystem.undo(frames: &frames) {
            // 선택 인덱스 조정
            selectedFrameIndex = min(selectedFrameIndex, frames.count - 1)
            statusText = "실행 취소: \(undoSystem.redoDescription)"
        }
    }
    
    /// Redo 실행  
    func redo() {
        if undoSystem.redo(frames: &frames) {
            // 선택 인덱스 조정
            selectedFrameIndex = min(selectedFrameIndex, frames.count - 1) 
            statusText = "다시 실행: \(undoSystem.undoDescription)"
        }
    }
    
    /// Undo/Redo 히스토리 초기화
    func clearEditHistory() {
        undoSystem.clear()
        statusText = "편집 히스토리 초기화"
    }
    
    /// 현재 편집 상태 정보
    var editHistoryInfo: String {
        let (undoCount, redoCount, memoryKB) = undoSystem.historyInfo
        let memoryMB = memoryKB / 1024
        return "Undo: \(undoCount), Redo: \(redoCount), 메모리: \(memoryMB)MB"
    }
}

struct GIFFrame: Identifiable {
    let id = UUID()
    var image: CGImage
    var duration: TimeInterval
    var nsImage: NSImage { NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)) }
}
