import Foundation
import CoreGraphics

// 🎯 리리의 완전무결한 Undo/Redo 시스템

/// 모든 편집 작업을 추상화하는 Command 프로토콜
protocol EditCommand {
    /// 명령 실행
    func execute(frames: inout [GIFFrame])
    /// 명령 취소 (역방향 실행)
    func undo(frames: inout [GIFFrame]) 
    /// 명령 설명 (디버깅용)
    var description: String { get }
    /// 메모리 사용량 추정 (KB)
    var estimatedMemoryKB: Int { get }
}

/// 효율적인 Undo/Redo 관리자
@MainActor
class UndoSystem: ObservableObject {
    
    private var undoStack: [EditCommand] = []
    private var redoStack: [EditCommand] = []
    
    /// 히스토리 최대 크기 (메모리 보호)
    private let maxHistorySize: Int
    /// 최대 메모리 사용량 (MB)
    private let maxMemoryMB: Int
    
    /// 현재 상태
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published var undoDescription: String = ""
    @Published var redoDescription: String = ""
    
    init(maxHistorySize: Int = 50, maxMemoryMB: Int = 500) {
        self.maxHistorySize = maxHistorySize
        self.maxMemoryMB = maxMemoryMB
    }
    
    /// 새 명령어 실행 및 히스토리 추가
    func execute(_ command: EditCommand, frames: inout [GIFFrame]) {
        // 메모리 사용량 체크
        let totalMemoryKB = undoStack.reduce(0) { $0 + $1.estimatedMemoryKB } + command.estimatedMemoryKB
        
        // 메모리 초과시 오래된 명령어 제거
        while totalMemoryKB > maxMemoryMB * 1024 && !undoStack.isEmpty {
            undoStack.removeFirst()
        }
        
        // 명령어 실행
        command.execute(frames: &frames)
        
        // Undo 스택에 추가
        undoStack.append(command)
        
        // 히스토리 크기 제한
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
        
        // Redo 스택 초기화 (새 작업 시)
        redoStack.removeAll()
        
        updateState()
    }
    
    /// Undo 실행
    func undo(frames: inout [GIFFrame]) -> Bool {
        guard let command = undoStack.popLast() else { return false }
        
        // Undo 실행
        command.undo(frames: &frames)
        
        // Redo 스택에 추가
        redoStack.append(command)
        
        updateState()
        return true
    }
    
    /// Redo 실행  
    func redo(frames: inout [GIFFrame]) -> Bool {
        guard let command = redoStack.popLast() else { return false }
        
        // Redo 실행 (원래 명령어 재실행)
        command.execute(frames: &frames)
        
        // Undo 스택에 다시 추가
        undoStack.append(command)
        
        updateState()
        return true
    }
    
    /// 히스토리 완전 초기화
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }
    
    /// 상태 업데이트
    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoDescription = undoStack.last?.description ?? ""
        redoDescription = redoStack.last?.description ?? ""
    }
    
    /// 현재 히스토리 정보
    var historyInfo: (undoCount: Int, redoCount: Int, memoryKB: Int) {
        let memoryKB = undoStack.reduce(0) { $0 + $1.estimatedMemoryKB }
        return (undoStack.count, redoStack.count, memoryKB)
    }
    
    // MARK: - Public API for UI
    
    /// 되돌리기 스택 개수
    var undoStackCount: Int { undoStack.count }
    
    /// 다시 실행 스택 개수  
    var redoStackCount: Int { redoStack.count }
    
    /// 마지막 실행된 명령어 (되돌리기 가능)
    var lastUndoCommand: EditCommand? { undoStack.last }
    
    /// 마지막 되돌린 명령어 (다시 실행 가능)
    var lastRedoCommand: EditCommand? { redoStack.last }
    
    /// 최근 N개 명령어 가져오기
    func getRecentCommands(count: Int = 5) -> [EditCommand] {
        Array(undoStack.suffix(count)).reversed()
    }
    
    /// 전체 히스토리 개수
    var totalHistoryCount: Int { undoStack.count + redoStack.count }
    
    /// 현재 사용 중인 총 메모리 (KB 단위)
    var totalMemoryUsageKB: Int { 
        undoStack.reduce(0) { $0 + $1.estimatedMemoryKB } + 
        redoStack.reduce(0) { $0 + $1.estimatedMemoryKB }
    }
    
    /// 최대 명령어 개수
    var maxCommands: Int { maxHistorySize }
}

// MARK: - 구체적인 Command 구현들

/// 프레임 삭제 명령어
struct DeleteFrameCommand: EditCommand {
    let frameIndex: Int
    let deletedFrame: GIFFrame  // 복원용
    
    var description: String { "프레임 삭제" }
    var estimatedMemoryKB: Int { 
        // 이미지 크기 기반 추정
        deletedFrame.image.width * deletedFrame.image.height * 4 / 1024  // RGBA
    }
    
    func execute(frames: inout [GIFFrame]) {
        guard frames.indices.contains(frameIndex), frames.count > 1 else { return }
        frames.remove(at: frameIndex)
    }
    
    func undo(frames: inout [GIFFrame]) {
        let safeIndex = min(frameIndex, frames.count)
        frames.insert(deletedFrame, at: safeIndex)
    }
}

/// 프레임 트림 명령어 (구간 자르기)
struct TrimFramesCommand: EditCommand {
    let originalFrames: [GIFFrame]  // 원본 전체
    let trimRange: Range<Int>       // 유지할 범위
    
    var description: String { "트림 (\(trimRange.count)프레임)" }
    var estimatedMemoryKB: Int {
        // 원본 프레임들 메모리 추정
        originalFrames.reduce(0) { total, frame in
            total + (frame.image.width * frame.image.height * 4 / 1024)
        }
    }
    
    func execute(frames: inout [GIFFrame]) {
        guard trimRange.upperBound <= frames.count else { return }
        frames = Array(frames[trimRange])
    }
    
    func undo(frames: inout [GIFFrame]) {
        frames = originalFrames
    }
}

/// 크롭 명령어
struct CropCommand: EditCommand {
    let originalFrames: [GIFFrame]  // 원본 전체 (크롭 전)
    let cropRect: CGRect
    
    var description: String { "크롭 \(Int(cropRect.width))×\(Int(cropRect.height))" }
    var estimatedMemoryKB: Int {
        originalFrames.reduce(0) { total, frame in
            total + (frame.image.width * frame.image.height * 4 / 1024)
        }
    }
    
    func execute(frames: inout [GIFFrame]) {
        FrameOps.crop(cropRect, frames: &frames)
    }
    
    func undo(frames: inout [GIFFrame]) {
        frames = originalFrames
    }
}

/// 속도 조절 명령어
struct SpeedAdjustCommand: EditCommand {
    let speedMultiplier: Double
    let originalDurations: [TimeInterval]
    
    var description: String { 
        let percent = Int(speedMultiplier * 100)
        return "속도 \(percent)%"
    }
    var estimatedMemoryKB: Int { 1 }  // duration만 저장하므로 작음
    
    func execute(frames: inout [GIFFrame]) {
        FrameOps.adjustSpeed(speedMultiplier, frames: &frames)
    }
    
    func undo(frames: inout [GIFFrame]) {
        // 원래 duration들 복원
        for (i, duration) in originalDurations.enumerated() {
            if frames.indices.contains(i) {
                frames[i].duration = duration
            }
        }
    }
}

/// 프레임 순서 변경 명령어 (뒤집기, 요요 등)
struct ReorderFramesCommand: EditCommand {
    let originalOrder: [GIFFrame]
    let operationType: FrameReorderType
    
    enum FrameReorderType {
        case reverse, yoyo, removeEven, removeOdd, removeEveryNth(Int)
        
        var description: String {
            switch self {
            case .reverse: return "뒤집기"
            case .yoyo: return "요요"
            case .removeEven: return "짝수 제거"
            case .removeOdd: return "홀수 제거"
            case .removeEveryNth(let n): return "\(n)번째마다 제거"
            }
        }
    }
    
    var description: String { operationType.description }
    var estimatedMemoryKB: Int {
        originalOrder.reduce(0) { total, frame in
            total + (frame.image.width * frame.image.height * 4 / 1024)
        }
    }
    
    func execute(frames: inout [GIFFrame]) {
        switch operationType {
        case .reverse:
            FrameOps.reverse(&frames)
        case .yoyo:
            FrameOps.yoyo(&frames)
        case .removeEven:
            FrameOps.removeEvenFrames(&frames)
        case .removeOdd:
            FrameOps.removeOddFrames(&frames)
        case .removeEveryNth(let n):
            FrameOps.removeEveryNth(n, frames: &frames)
        }
    }
    
    func undo(frames: inout [GIFFrame]) {
        frames = originalOrder
    }
}

/// 유사 프레임 제거 명령어
struct RemoveSimilarCommand: EditCommand {
    let originalFrames: [GIFFrame]
    let threshold: Int
    
    var description: String { "유사 프레임 제거" }
    var estimatedMemoryKB: Int {
        originalFrames.reduce(0) { total, frame in
            total + (frame.image.width * frame.image.height * 4 / 1024)
        }
    }
    
    func execute(frames: inout [GIFFrame]) {
        FrameOps.removeSimilar(threshold: threshold, frames: &frames)
    }
    
    func undo(frames: inout [GIFFrame]) {
        frames = originalFrames
    }
}

/// 프레임 duration 변경 명령어
struct SetFrameDurationCommand: EditCommand {
    let frameIndex: Int?  // nil이면 전체
    let newDuration: TimeInterval
    let originalDurations: [TimeInterval]
    
    var description: String { 
        if let index = frameIndex {
            return "프레임 \(index + 1) 시간 설정"
        } else {
            return "전체 프레임 시간 설정"
        }
    }
    var estimatedMemoryKB: Int { 1 }  // duration만 저장
    
    func execute(frames: inout [GIFFrame]) {
        if let index = frameIndex {
            guard frames.indices.contains(index) else { return }
            frames[index].duration = newDuration
        } else {
            FrameOps.setAllDuration(newDuration, frames: &frames)
        }
    }
    
    func undo(frames: inout [GIFFrame]) {
        // 원래 duration들 복원
        for (i, duration) in originalDurations.enumerated() {
            if frames.indices.contains(i) {
                frames[i].duration = duration
            }
        }
    }
}