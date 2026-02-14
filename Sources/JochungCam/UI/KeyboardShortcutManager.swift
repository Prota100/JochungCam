import SwiftUI
import AppKit
import Carbon

// ⌨️ 리리의 완벽한 키보드 단축키 시스템

@MainActor
class KeyboardShortcutManager: ObservableObject {
    
    // MARK: - 단축키 정의
    
    struct Shortcut {
        let id: String
        let key: String
        let modifiers: NSEvent.ModifierFlags
        let description: String
        let action: () -> Void
        
        var displayString: String {
            var parts: [String] = []
            
            if modifiers.contains(.command) { parts.append("⌘") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            
            parts.append(key.uppercased())
            
            return parts.joined()
        }
    }
    
    // MARK: - 발행된 속성들
    
    @Published var isEnabled = true
    @Published var showShortcutOverlay = false
    @Published var shortcuts: [Shortcut] = []
    
    // MARK: - 내부 프로퍼티
    
    private var globalEventTap: CFMachPort?
    private var localEventMonitor: Any?
    private var appState: AppState?
    
    // MARK: - 단축키 액션 클로저들
    
    var onStartCapture: (() -> Void)?
    var onStopCapture: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onSpeedDecrease: (() -> Void)?
    var onSpeedIncrease: (() -> Void)?
    var onSpeedReset: (() -> Void)?
    var onShowPreview: (() -> Void)?
    var onExport: (() -> Void)?
    var onTrim: (() -> Void)?
    var onCrop: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowBatch: (() -> Void)?
    var onQuit: (() -> Void)?
    
    // MARK: - 초기화
    
    init() {
        setupShortcuts()
        setupEventMonitoring()
    }
    
    // MARK: - 단축키 설정
    
    private func setupShortcuts() {
        shortcuts = [
            // 캡처 관련
            Shortcut(id: "start_capture", key: "G", modifiers: [.command, .shift], description: "캡처 시작") {
                self.onStartCapture?()
            },
            
            Shortcut(id: "stop_capture", key: "Escape", modifiers: [], description: "캡처 중지") {
                self.onStopCapture?()
            },
            
            Shortcut(id: "toggle_pause", key: "Space", modifiers: [.command], description: "일시정지/재개") {
                self.onTogglePause?()
            },
            
            // 편집 관련
            Shortcut(id: "undo", key: "Z", modifiers: [.command], description: "실행 취소") {
                self.onUndo?()
            },
            
            Shortcut(id: "redo", key: "Z", modifiers: [.command, .shift], description: "다시 실행") {
                self.onRedo?()
            },
            
            // 속도 조절
            Shortcut(id: "speed_decrease", key: "ArrowLeft", modifiers: [.control], description: "속도 감소") {
                self.onSpeedDecrease?()
            },
            
            Shortcut(id: "speed_increase", key: "ArrowRight", modifiers: [.control], description: "속도 증가") {
                self.onSpeedIncrease?()
            },
            
            Shortcut(id: "speed_reset", key: "0", modifiers: [.control], description: "속도 초기화") {
                self.onSpeedReset?()
            },
            
            // 뷰 관련
            Shortcut(id: "show_preview", key: "P", modifiers: [.command], description: "미리보기 표시") {
                self.onShowPreview?()
            },
            
            // 파일 관련
            Shortcut(id: "export", key: "E", modifiers: [.command], description: "내보내기") {
                self.onExport?()
            },
            
            Shortcut(id: "open", key: "O", modifiers: [.command], description: "파일 열기") {
                self.openFile()
            },
            
            Shortcut(id: "save", key: "S", modifiers: [.command], description: "저장") {
                self.onExport?()
            },
            
            // 편집 도구
            Shortcut(id: "trim", key: "T", modifiers: [.command], description: "트림") {
                self.onTrim?()
            },
            
            Shortcut(id: "crop", key: "C", modifiers: [.command], description: "크롭") {
                self.onCrop?()
            },
            
            // 앱 관련
            Shortcut(id: "settings", key: "Comma", modifiers: [.command], description: "설정") {
                self.onShowSettings?()
            },
            
            Shortcut(id: "batch", key: "B", modifiers: [.command, .shift], description: "배치 처리") {
                self.onShowBatch?()
            },
            
            Shortcut(id: "help", key: "H", modifiers: [.command], description: "도움말") {
                self.showShortcutOverlay.toggle()
            },
            
            Shortcut(id: "quit", key: "Q", modifiers: [.command], description: "종료") {
                self.onQuit?()
            }
        ]
    }
    
    // MARK: - 이벤트 모니터링 설정
    
    private func setupEventMonitoring() {
        // 로컬 이벤트 모니터 (앱이 활성화된 상태)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil  // 이벤트 소비
            }
            return event
        }
        
        // 글로벌 이벤트 모니터 (앱이 비활성화된 상태에서도 작동)
        setupGlobalEventTap()
    }
    
    private func setupGlobalEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                if let manager = Unmanaged<KeyboardShortcutManager>.fromOpaque(refcon!).takeUnretainedValue() as KeyboardShortcutManager? {
                    if manager.handleGlobalKeyEvent(event) {
                        return nil  // 이벤트 소비
                    }
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passRetained(self).toOpaque()
        ) else {
            print("글로벌 키보드 이벤트 탭 생성 실패")
            return
        }
        
        globalEventTap = eventTap
        
        // 이벤트 탭을 런루프에 추가
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // 이벤트 탭 활성화
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    // MARK: - 키 이벤트 처리
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isEnabled else { return false }
        
        let key = event.charactersIgnoringModifiers ?? ""
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        
        // 특수 키 처리
        let keyCode = event.keyCode
        let specialKey = getSpecialKeyName(keyCode: keyCode)
        let finalKey = specialKey ?? key
        
        // 매칭되는 단축키 찾기
        for shortcut in shortcuts {
            if shortcut.key == finalKey && shortcut.modifiers == modifiers {
                shortcut.action()
                return true
            }
        }
        
        return false
    }
    
    private func handleGlobalKeyEvent(_ event: CGEvent) -> Bool {
        guard isEnabled else { return false }
        
        // 글로벌 단축키만 처리 (캡처 시작 등)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let modifiers = CGEventFlags(rawValue: event.flags.rawValue)
        
        // ⌘⇧G (캡처 시작) 감지
        if keyCode == 5 && modifiers.contains(.maskCommand) && modifiers.contains(.maskShift) { // G key
            onStartCapture?()
            return true
        }
        
        return false
    }
    
    private func getSpecialKeyName(keyCode: UInt16) -> String? {
        switch keyCode {
        case 53: return "Escape"
        case 49: return "Space"
        case 123: return "ArrowLeft"
        case 124: return "ArrowRight"
        case 125: return "ArrowDown"
        case 126: return "ArrowUp"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 43: return "Comma"
        case 29: return "0"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return nil
        }
    }
    
    // MARK: - 액션 구현
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif, .mpeg4Movie, .quickTimeMovie, .png]
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            NotificationCenter.default.post(name: .openFile, object: url)
        }
    }
    
    // MARK: - AppState 연결
    
    func connect(to appState: AppState) {
        self.appState = appState
        
        // 액션 연결
        onStartCapture = {
            NotificationCenter.default.post(name: .startCapture, object: nil)
        }
        
        onStopCapture = {
            if appState.mode == .recording || appState.mode == .paused {
                // 녹화 중지 로직
            }
        }
        
        onTogglePause = {
            if appState.mode == .recording {
                // 일시정지 로직
            } else if appState.mode == .paused {
                // 재개 로직
            }
        }
        
        onUndo = {
            _ = appState.undoSystem.undo(frames: &appState.frames)
        }
        
        onRedo = {
            _ = appState.undoSystem.redo(frames: &appState.frames)
        }
        
        onSpeedDecrease = {
            appState.adjustSpeed(-0.1)
        }
        
        onSpeedIncrease = {
            appState.adjustSpeed(0.1)
        }
        
        onSpeedReset = {
            appState.speedMultiplier = 1.0
        }
        
        onShowSettings = {
            // 설정 창 표시 로직
        }
        
        onShowBatch = {
            appState.showBatch = true
        }
        
        onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }
    
    // MARK: - 단축키 커스터마이징
    
    func updateShortcut(id: String, key: String, modifiers: NSEvent.ModifierFlags) {
        if let index = shortcuts.firstIndex(where: { $0.id == id }) {
            let oldShortcut = shortcuts[index]
            shortcuts[index] = Shortcut(
                id: oldShortcut.id,
                key: key,
                modifiers: modifiers,
                description: oldShortcut.description,
                action: oldShortcut.action
            )
        }
    }
    
    func resetToDefaults() {
        setupShortcuts()
    }
    
    // MARK: - 활성화/비활성화
    
    func enableShortcuts() {
        isEnabled = true
        
        if let eventTap = globalEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
    
    func disableShortcuts() {
        isEnabled = false
        
        if let eventTap = globalEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }
    
    // MARK: - 정리
    
    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        if let eventTap = globalEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
    }
}

// MARK: - AppState 확장

extension AppState {
    func adjustSpeed(_ delta: Double) {
        speedMultiplier = max(0.25, min(4.0, speedMultiplier + delta))
        
        // UndoSystem에 기록
        let originalDurations = frames.map { $0.duration }
        let command = SpeedAdjustCommand(
            speedMultiplier: speedMultiplier,
            originalDurations: originalDurations
        )
        undoSystem.execute(command, frames: &frames)
    }
}

// MARK: - 단축키 오버레이 뷰

struct ShortcutOverlayView: View {
    @ObservedObject var shortcutManager: KeyboardShortcutManager
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // 반투명 배경
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // 단축키 목록
            VStack(spacing: 20) {
                Text("키보드 단축키")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(shortcutManager.shortcuts, id: \.id) { shortcut in
                            ShortcutItemView(shortcut: shortcut)
                        }
                    }
                }
                .frame(maxHeight: 400)
                
                Button("닫기") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                .themedButton(.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .frame(maxWidth: 600)
            .padding()
        }
    }
}

struct ShortcutItemView: View {
    let shortcut: KeyboardShortcutManager.Shortcut
    
    var body: some View {
        HStack {
            Text(shortcut.description)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(shortcut.displayString)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Notification 확장

extension Notification.Name {
    static let shortcutPressed = Notification.Name("shortcutPressed")
}