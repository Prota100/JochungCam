import SwiftUI

@main
struct JochungCamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var recorder = ScreenRecorder()

    @State private var showDepCheck = false

    var body: some Scene {
        Window("JochungCam", id: "main") {
            MainWindow()
                .environmentObject(appState)
                .environmentObject(recorder)
                .onAppear {
                    if !DependencyCheck.allInstalled {
                        showDepCheck = true
                    }
                }
                .sheet(isPresented: $showDepCheck) {
                    DependencySheet(isPresented: $showDepCheck)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openFile)) { notif in
                    guard let url = notif.object as? URL else { return }
                    handleFileOpen(url)
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 420, height: 320)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("새 캡처") { NotificationCenter.default.post(name: .startCapture, object: nil) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("파일 열기...") { openFile() }
                    .keyboardShortcut("o")
                Button("배치 변환...") { appState.showBatch = true }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                Divider()
                Button("설정 초기화") { appState.reset() }
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("녹화 중지") { Task { await recorder.stopRecording(appState: appState) } }
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!recorder.isActive)
            }
        }
    }

    private func handleFileOpen(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        if ["gif", "webp", "apng", "png"].contains(ext) {
            if let frames = FrameOps.importGIF(from: url) {
                appState.enterEditor(with: frames)
            }
        } else if ["mp4", "mov", "m4v", "webm"].contains(ext) {
            Task {
                let frames = await FrameOps.importVideo(from: url, fps: Double(appState.fps)) { progress, status in
                    Task { @MainActor in
                        appState.statusText = status
                        appState.saveProgress = progress
                    }
                }
                if let frames = frames {
                    appState.enterEditor(with: frames)
                }
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif, .mpeg4Movie, .quickTimeMovie, .png]
        panel.begin { r in
            guard r == .OK, let url = panel.url else { return }
            handleFileOpen(url)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var pendingURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 화면 녹화 권한 체크 + 요청
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }

        // 글로벌 핫키: ⌘⇧G (앱 비활성 상태에서도 동작)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "g" {
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .startCapture, object: nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppDelegate.pendingURL = urls.first
        NotificationCenter.default.post(name: .openFile, object: urls.first)
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let startCapture = Notification.Name("startCapture")
}

struct MainWindow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            switch appState.mode {
            case .home, .selecting:
                HomeView()
                    .transition(.opacity)
            case .recording, .paused:
                RecordingView()
                    .transition(.opacity)
            case .editing, .cropping:
                EditorView()
                    .transition(.opacity)
            case .saving:
                SavingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: appState.mode)
        .sheet(isPresented: $appState.showBatch) { BatchConvertView().environmentObject(appState) }
    }
}
