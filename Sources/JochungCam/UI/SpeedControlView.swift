import SwiftUI

// 🎬 리리의 혁신적인 속도 조절 UI

struct SpeedControlView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var currentSpeedMultiplier: Double = 1.0
    @State private var showSpeedSheet = false
    @State private var isPlaying = false
    @State private var previewTimer: Timer?
    
    // 속도 프리셋들
    private let speedPresets: [(Double, String, String)] = [
        (0.25, "0.25×", "매우 느리게"),
        (0.5, "0.5×", "반속도"),
        (0.75, "0.75×", "조금 느리게"),
        (1.0, "1×", "원속도"),
        (1.25, "1.25×", "조금 빠르게"),
        (1.5, "1.5×", "1.5배속"),
        (2.0, "2×", "2배속"),
        (3.0, "3×", "3배속")
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            // 현재 속도 표시 버튼
            Button(action: { showSpeedSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: speedIcon)
                        .font(.system(size: 12))
                        .foregroundColor(speedColor)
                    
                    Text(speedText)
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                    
                    // Undo 가능 표시
                    if appState.undoSystem.canUndo {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(hasRecentSpeedChange ? Color.blue.opacity(0.1) : Color(.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(hasRecentSpeedChange ? Color.blue : Color.clear, lineWidth: 1)
                )
            }
            .help(speedButtonHelp)
            
            // 빠른 속도 조절 버튼들
            quickSpeedButtons
            
            // Undo/Redo 버튼들
            undoRedoButtons
        }
        .sheet(isPresented: $showSpeedSheet) {
            speedControlSheet
        }
        .onAppear {
            updateCurrentSpeed()
        }
    }
    
    // MARK: - Undo/Redo 버튼들
    var undoRedoButtons: some View {
        HStack(spacing: 4) {
            // Undo 버튼
            Button(action: { 
                _ = appState.undoSystem.undo(frames: &appState.frames)
                updateCurrentSpeed()
            }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("\(undoButtonHelp) (⌘Z)")
            .disabled(!appState.undoSystem.canUndo)
            
            // Redo 버튼
            Button(action: { 
                _ = appState.undoSystem.redo(frames: &appState.frames)
                updateCurrentSpeed()
            }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("\(redoButtonHelp) (⌘⇧Z)")
            .disabled(!appState.undoSystem.canRedo)
        }
    }

    // MARK: - 빠른 속도 버튼들
    var quickSpeedButtons: some View {
        HStack(spacing: 4) {
            // 더 느리게
            Button(action: { adjustSpeedQuick(0.9) }) {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("10% 느리게 (⌃ ←)")
            .keyboardShortcut(.leftArrow, modifiers: .control)
            
            // 더 빠르게  
            Button(action: { adjustSpeedQuick(1.1) }) {
                Image(systemName: "hare.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("10% 빠르게 (⌃ →)")
            .keyboardShortcut(.rightArrow, modifiers: .control)
            
            // 원속도 복원
            Button(action: { resetSpeed() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("원속도로 복원 (⌃ 0)")
            .keyboardShortcut("0", modifiers: .control)
            .disabled(abs(currentSpeedMultiplier - 1.0) < 0.01)
        }
    }
    
    // MARK: - 속도 조절 시트
    var speedControlSheet: some View {
        VStack(spacing: 20) {
            // 헤더
            VStack(spacing: 8) {
                Text("속도 조절")
                    .font(.title2.bold())
                
                Text("\(appState.frames.count)프레임 · \(String(format: "%.1f", totalDuration))초")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 현재 속도 정보
            currentSpeedInfo
            
            // 메인 속도 슬라이더
            speedSliderSection
            
            // 속도 프리셋
            speedPresetsSection
            
            // 실시간 미리보기
            if !appState.frames.isEmpty {
                previewSection
            }
            
            // Undo/Redo 상태 표시
            undoRedoStatusSection
            
            Spacer()
            
            Divider()
            
            // 실시간 상태 요약
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("⌘Z: 되돌리기")
                        .font(.caption2)
                        .foregroundColor(appState.undoSystem.canUndo ? .primary : .secondary)
                    
                    Text("⌘⇧Z: 다시 실행")
                        .font(.caption2)
                        .foregroundColor(appState.undoSystem.canRedo ? .primary : .secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("⌃←→: 빠른 조절")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("⌃0: 원속도")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
            
            // 하단 버튼
            HStack {
                Button("취소") {
                    showSpeedSheet = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("히스토리 보기 (\(appState.undoSystem.undoStackCount))") {
                    showUndoRedoHistory()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button("적용") {
                    showSpeedSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 500, height: 600)
        .onDisappear {
            stopPreview()
        }
    }
    
    // MARK: - 현재 속도 정보
    var currentSpeedInfo: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.blue)
                Text("현재 속도")
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(speedText)
                        .font(.title2.bold())
                        .foregroundColor(speedColor)
                    
                    Text(speedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 속도 효과 정보
            HStack {
                InfoItem(title: "원본 시간", value: String(format: "%.1f초", totalDuration / currentSpeedMultiplier))
                Spacer()
                InfoItem(title: "변경 후", value: String(format: "%.1f초", totalDuration))
                Spacer()
                InfoItem(title: "차이", value: speedDifferenceText)
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 속도 슬라이더 섹션
    var speedSliderSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.orange)
                Text("정밀 속도 조절")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 메인 슬라이더 (0.25x ~ 4x)
                HStack {
                    Text("0.25×")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $currentSpeedMultiplier, in: 0.25...4.0) { editing in
                        if !editing {
                            applySpeedChange()
                        }
                    }
                    .accentColor(speedColor)
                    
                    Text("4×")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 현재 값 표시
                Text("정확한 배속: \(String(format: "%.2f", currentSpeedMultiplier))×")
                    .font(.caption)
                    .foregroundColor(speedColor)
            }
        }
    }
    
    // MARK: - 속도 프리셋 섹션
    var speedPresetsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "dial.max")
                    .foregroundColor(.purple)
                Text("빠른 선택")
                    .font(.headline)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(speedPresets.indices, id: \.self) { index in
                    let (multiplier, label, description) = speedPresets[index]
                    
                    Button(action: {
                        currentSpeedMultiplier = multiplier
                        applySpeedChange()
                    }) {
                        VStack(spacing: 4) {
                            Text(label)
                                .font(.caption.bold())
                            
                            Text(description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(abs(currentSpeedMultiplier - multiplier) < 0.01 ? 
                                     Color.blue.opacity(0.2) : 
                                     Color(.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(abs(currentSpeedMultiplier - multiplier) < 0.01 ? 
                                        Color.blue : 
                                        Color(.separatorColor), 
                                       lineWidth: abs(currentSpeedMultiplier - multiplier) < 0.01 ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Undo/Redo 상태 섹션
    var undoRedoStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.uturn.backward.circle")
                    .foregroundColor(.blue)
                Text("실행 취소 / 다시 실행")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 8) {
                    // 즉시 되돌리기 버튼
                    Button(action: { 
                        _ = appState.undoSystem.undo(frames: &appState.frames)
                        updateCurrentSpeed()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("되돌리기")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!appState.undoSystem.canUndo)
                    .keyboardShortcut("z", modifiers: .command)
                    
                    // 다시 실행 버튼
                    Button(action: { 
                        _ = appState.undoSystem.redo(frames: &appState.frames)
                        updateCurrentSpeed()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.forward")
                            Text("다시 실행")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!appState.undoSystem.canRedo)
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                }
            }
            
            // 상태 정보
            HStack {
                InfoItem(
                    title: "되돌리기 가능", 
                    value: "\(appState.undoSystem.undoStackCount)개"
                )
                
                Spacer()
                
                InfoItem(
                    title: "다시 실행 가능", 
                    value: "\(appState.undoSystem.redoStackCount)개"
                )
                
                Spacer()
                
                InfoItem(
                    title: "메모리", 
                    value: String(format: "%.1fMB", Double(appState.undoSystem.totalMemoryUsageKB) / 1024.0)
                )
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // 최근 명령어 표시
            if let lastCommand = appState.undoSystem.lastUndoCommand {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("마지막 작업: \(lastCommand.description)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }

    // MARK: - 실시간 미리보기
    var previewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "play.rectangle")
                    .foregroundColor(.green)
                Text("실시간 미리보기")
                    .font(.headline)
                
                Spacer()
                
                Button(isPlaying ? "정지" : "재생") {
                    togglePreview()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if let currentFrame = getCurrentPreviewFrame() {
                Image(nsImage: currentFrame.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            }
            
            Text("속도 변경을 실시간으로 확인하세요")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 헬퍼 뷰

struct InfoItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 로직 구현

extension SpeedControlView {
    
    // MARK: - Undo/Redo 헬퍼들
    
    var undoButtonHelp: String {
        if let lastCommand = appState.undoSystem.lastUndoCommand {
            return "되돌리기: \(lastCommand.description)"
        } else {
            return "되돌릴 작업 없음"
        }
    }
    
    var redoButtonHelp: String {
        if let nextCommand = appState.undoSystem.lastRedoCommand {
            return "다시 실행: \(nextCommand.description)"
        } else {
            return "다시 실행할 작업 없음"
        }
    }
    
    func showUndoRedoHistory() {
        let historyCount = appState.undoSystem.totalHistoryCount
        let undoCount = appState.undoSystem.undoStackCount
        let redoCount = appState.undoSystem.redoStackCount
        
        let message = """
        🔄 Undo/Redo 히스토리
        
        📝 총 \(historyCount)개 작업 기록
        ↩️  되돌리기 가능: \(undoCount)개
        ↪️  다시 실행 가능: \(redoCount)개
        
        💾 메모리 사용량: \(String(format: "%.1f", Double(appState.undoSystem.totalMemoryUsageKB) / 1024.0))MB
        📚 최대 기록: \(appState.undoSystem.maxCommands)개
        
        마지막 5개 작업:
        \(getRecentCommandsText())
        """
        
        // macOS 알림 표시
        let alert = NSAlert()
        alert.messageText = "Undo/Redo 히스토리"
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    func getRecentCommandsText() -> String {
        let recentCommands = appState.undoSystem.getRecentCommands(count: 5)
        
        if recentCommands.isEmpty {
            return "• (작업 기록 없음)"
        }
        
        return recentCommands.enumerated().map { index, command in
            "• \(index + 1). \(command.description)"
        }.joined(separator: "\n")
    }
    
    // MARK: - 속도 관련 헬퍼들
    
    var totalDuration: Double {
        appState.frames.reduce(0) { $0 + $1.duration }
    }
    
    var speedIcon: String {
        switch currentSpeedMultiplier {
        case 0..<0.8: return "tortoise.fill"
        case 0.8..<1.2: return "figure.walk"  
        case 1.2..<2.0: return "hare.fill"
        default: return "bolt.fill"
        }
    }
    
    var speedColor: Color {
        switch currentSpeedMultiplier {
        case 0..<0.8: return .blue
        case 0.8..<1.2: return .green
        case 1.2..<2.0: return .orange
        default: return .red
        }
    }
    
    var speedText: String {
        if abs(currentSpeedMultiplier - 1.0) < 0.01 {
            return "1×"
        } else {
            return String(format: "%.2f×", currentSpeedMultiplier)
        }
    }
    
    var hasRecentSpeedChange: Bool {
        // 최근에 속도 조절 명령이 있었는지 확인
        return appState.undoSystem.lastUndoCommand?.description.contains("속도") == true
    }
    
    var speedButtonHelp: String {
        var help = "속도 조절 (\(speedDescription))"
        
        if hasRecentSpeedChange {
            help += " • 최근 변경됨"
        }
        
        if appState.undoSystem.canUndo {
            help += " • ⌘Z로 되돌리기"
        }
        
        return help
    }
    
    var speedDescription: String {
        switch currentSpeedMultiplier {
        case 0..<0.5: return "매우 느리게"
        case 0.5..<0.8: return "느리게"  
        case 0.8..<1.2: return "원속도"
        case 1.2..<1.8: return "빠르게"
        case 1.8..<3.0: return "매우 빠르게"
        default: return "초고속"
        }
    }
    
    var speedDifferenceText: String {
        let difference = totalDuration - (totalDuration / currentSpeedMultiplier)
        let sign = difference >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", difference))초"
    }
    
    func updateCurrentSpeed() {
        currentSpeedMultiplier = SpeedControlCore.currentSpeedMultiplier(
            durations: appState.frames.map(\.duration)
        )
    }
    
    func adjustSpeedQuick(_ multiplier: Double) {
        guard let newMultiplier = SpeedControlCore.quickAdjustedMultiplier(
            current: currentSpeedMultiplier,
            step: multiplier
        ) else { return }

        appState.adjustSpeed(multiplier: multiplier)
        currentSpeedMultiplier = newMultiplier
    }
    
    func resetSpeed() {
        let resetMultiplier = SpeedControlCore.resetMultiplier(
            durations: appState.frames.map(\.duration)
        )

        appState.adjustSpeed(multiplier: resetMultiplier)
        currentSpeedMultiplier = 1.0
    }
    
    func applySpeedChange() {
        // 현재 설정된 배속으로 변경
        appState.adjustSpeed(multiplier: 1.0 / currentSpeedMultiplier)
    }
    
    // MARK: - 미리보기 관련
    
    func togglePreview() {
        if isPlaying {
            stopPreview()
        } else {
            startPreview()
        }
    }
    
    func startPreview() {
        guard !appState.frames.isEmpty else { return }

        isPlaying = true

        let interval = SpeedControlCore.previewInterval(
            durations: appState.frames.map(\.duration),
            multiplier: currentSpeedMultiplier
        )

        previewTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            // 미리보기 프레임 순환 (자동으로 currentFrame 업데이트됨)
        }
    }
    
    func stopPreview() {
        isPlaying = false
        previewTimer?.invalidate()
        previewTimer = nil
    }
    
    func getCurrentPreviewFrame() -> GIFFrame? {
        guard !appState.frames.isEmpty else { return nil }
        
        if isPlaying {
            // 시간 기반으로 현재 프레임 선택
            let elapsed = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: totalDuration / currentSpeedMultiplier)
            var accumulatedTime: TimeInterval = 0
            
            for frame in appState.frames {
                accumulatedTime += frame.duration / currentSpeedMultiplier
                if elapsed <= accumulatedTime {
                    return frame
                }
            }
            
            return appState.frames.first
        } else {
            // 정지 상태에서는 선택된 프레임 또는 첫 번째 프레임
            return appState.frames[safe: appState.selectedFrameIndex] ?? appState.frames.first
        }
    }
}

// MARK: - 배열 안전 접근 (EditorView에 이미 정의되어 있으므로 제거)