import SwiftUI
import UniformTypeIdentifiers

/// 🚀 간소화된 에디터 - 트림 중심의 UX
struct SimpleEditorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recorder: ScreenRecorder
    @State private var isPlaying = false
    @State private var playTimer: Timer?
    @State private var trimStart: Int = 0
    @State private var trimEnd: Int = 0
    @State private var showCropSheet = false
    @State private var showExportSheet = false
    @State private var cropRect: CGRect = .zero

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            trimSlider
            
            Divider()
            
            bottomToolbar
        }
        .frame(minWidth: 500, minHeight: 420)  // 더 작게!
        .onAppear {
            trimStart = 0
            trimEnd = max(0, appState.frames.count - 1)
        }
        .sheet(isPresented: $showCropSheet) {
            cropSheet
        }
        .sheet(isPresented: $showExportSheet) {
            SmartExportView(isPresented: $showExportSheet, frames: trimmedFrames) { url in
                performSave(to: url)
            }.environmentObject(appState)
        }
    }

    // MARK: - 상단바 (통계만 간단히)
    var topBar: some View {
        HStack {
            Button(action: { appState.reset() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("새로")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "film")
                    Text("\(trimmedFrames.count)f")
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(String(format: "%.1fs", trimmedDuration))
                }
                HStack(spacing: 4) {
                    Image(systemName: "aspectratio") 
                    Text(frameSize)
                }
            }
            .font(HCTheme.captionMono)
            .foregroundColor(.secondary)
            
            Spacer()
            
            HCTag("~\(estimatedSize)")
        }
        .padding(.horizontal, HCTheme.padLg)
        .padding(.vertical, 8)
    }

    // MARK: - 프리뷰
    var preview: some View {
        ZStack {
            Color.black.opacity(0.1)
            
            if let frame = currentFrame {
                Image(nsImage: frame.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            }
            
            // 재생 컨트롤 오버레이
            VStack {
                Spacer()
                HStack {
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black.opacity(0.7))
                    .foregroundColor(.white)
                }
                .padding(.bottom, 20)
            }
        }
        .onTapGesture {
            togglePlayback()
        }
    }

    // MARK: - 트림 슬라이더 (핵심!)
    var trimSlider: some View {
        VStack(spacing: 8) {
            // 트림 구간 표시
            HStack {
                Text("시작: \(trimStart + 1)")
                Spacer()
                Text("길이: \(trimEnd - trimStart + 1)프레임")
                Spacer()
                Text("끝: \(trimEnd + 1)")
            }
            .font(HCTheme.caption)
            .foregroundColor(.secondary)
            
            // QuickTime 스타일 트림 슬라이더
            GeometryReader { geo in
                let totalWidth = geo.size.width - 32
                let frameCount = appState.frames.count
                
                ZStack(alignment: .leading) {
                    // 배경 (전체 구간)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    
                    // 선택된 구간
                    let startPos = CGFloat(trimStart) / CGFloat(frameCount - 1) * totalWidth
                    let endPos = CGFloat(trimEnd) / CGFloat(frameCount - 1) * totalWidth
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(HCTheme.accent)
                        .frame(width: endPos - startPos + 8, height: 8)
                        .offset(x: startPos)
                    
                    // 시작 핸들
                    Circle()
                        .fill(HCTheme.accent)
                        .frame(width: 16, height: 16)
                        .offset(x: startPos - 8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPos = max(0, min(totalWidth, value.location.x))
                                    let newFrame = Int(newPos / totalWidth * CGFloat(frameCount - 1))
                                    trimStart = max(0, min(trimEnd - 1, newFrame))
                                    updateCurrentFrame()
                                }
                        )
                    
                    // 끝 핸들  
                    Circle()
                        .fill(HCTheme.accent)
                        .frame(width: 16, height: 16)
                        .offset(x: endPos - 8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPos = max(0, min(totalWidth, value.location.x))
                                    let newFrame = Int(newPos / totalWidth * CGFloat(frameCount - 1))
                                    trimEnd = max(trimStart + 1, min(frameCount - 1, newFrame))
                                    updateCurrentFrame()
                                }
                        )
                }
                .frame(height: 16)
            }
            .frame(height: 16)
            .padding(.horizontal, 16)
        }
        .padding(HCTheme.pad)
    }

    // MARK: - 하단 툴바 (최소한의 기능만)
    var bottomToolbar: some View {
        HStack(spacing: 12) {
            // 🎯 리리의 완전무결한 Undo/Redo
            Button(action: { appState.undo() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!appState.undoSystem.canUndo)
            .help("실행 취소 (\(appState.undoSystem.undoDescription))")
            
            Button(action: { appState.redo() }) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!appState.undoSystem.canRedo)
            .help("다시 실행 (\(appState.undoSystem.redoDescription))")
            
            Divider()
            
            Button("트림 적용") {
                applyTrim()
            }
            .buttonStyle(.borderedProminent)
            .tint(HCTheme.accent)
            .disabled(trimStart == 0 && trimEnd == appState.frames.count - 1)
            
            Button("크롭") {
                showCropSheet = true
            }
            
            // 🎬 리리의 혁신적인 속도 조절 (컴팩트)
            SpeedControlView()
                .environmentObject(appState)
            
            Spacer()
            
            Button("저장") {
                showExportSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(HCTheme.pad)
    }

    // MARK: - 계산된 속성들
    var trimmedFrames: [GIFFrame] {
        Array(appState.frames[trimStart...trimEnd])
    }
    
    var trimmedDuration: TimeInterval {
        trimmedFrames.reduce(0) { $0 + $1.duration }
    }
    
    var frameSize: String {
        guard let frame = appState.frames.first else { return "" }
        return "\(frame.image.width)×\(frame.image.height)"
    }
    
    var estimatedSize: String {
        guard let frame = trimmedFrames.first else { return "" }
        let px = frame.image.width * frame.image.height
        let bpf = Double(px) * 0.4 // 대략적 추정
        let total = bpf * Double(trimmedFrames.count)
        return total > 1_048_576 ? 
            String(format: "%.1fMB", total/1_048_576) : 
            String(format: "%.0fKB", total/1024)
    }
    
    var currentFrame: GIFFrame? {
        let index = isPlaying ? 
            (trimStart + Int(Date().timeIntervalSince1970 * 15) % (trimEnd - trimStart + 1)) :
            trimStart
        return appState.frames[safe: index]
    }

    // MARK: - 액션들
    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            playTimer = Timer.scheduledTimer(withTimeInterval: 0.066, repeats: true) { _ in
                // 자동으로 currentFrame이 업데이트됨 (computed property)
            }
        } else {
            playTimer?.invalidate()
            playTimer = nil
        }
    }
    
    func updateCurrentFrame() {
        // 트림 핸들 드래그 시 해당 프레임으로 이동
        appState.selectedFrameIndex = isPlaying ? trimStart : trimStart
    }
    
    func applyTrim() {
        let range = Range(uncheckedBounds: (trimStart, trimEnd + 1))
        appState.trimFrames(to: range)
        
        // 트림 적용 후 슬라이더 리셋
        trimStart = 0
        trimEnd = max(0, appState.frames.count - 1)
    }

    // MARK: - 크롭 시트
    var cropSheet: some View {
        VStack {
            Text("크롭")
                .font(HCTheme.title)
                .padding()
            
            // 간단한 크롭 UI (기존 CropOverlay 사용)
            if let frame = currentFrame {
                Image(nsImage: frame.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .overlay(
                        CropOverlayView(
                            cropRect: $cropRect,
                            imageSize: CGSize(width: frame.image.width, height: frame.image.height)
                        )
                    )
            }
            
            HStack {
                Button("취소") {
                    showCropSheet = false
                }
                
                Spacer()
                
                Button("적용") {
                    applyCrop()
                    showCropSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }
    
    func applyCrop() {
        guard let frame = currentFrame else { return }
        
        let imageWidth = CGFloat(frame.image.width)
        let imageHeight = CGFloat(frame.image.height)
        
        let cropPixelRect = CGRect(
            x: cropRect.origin.x * imageWidth,
            y: cropRect.origin.y * imageHeight,
            width: cropRect.width * imageWidth,
            height: cropRect.height * imageHeight
        )
        
        appState.cropFrames(to: cropPixelRect)
        showCropSheet = false
    }

    func performSave(to url: URL) {
        // 기존 저장 로직 사용
        appState.mode = .saving
        let frames = trimmedFrames
        let format = appState.outputFormat
        let opts = GIFEncoder.Options(
            maxColors: appState.gifQuality.maxColors,
            dither: appState.useDither,
            ditherLevel: appState.ditherLevel,
            speed: appState.liqSpeed,
            quality: appState.liqQuality,
            loopCount: appState.loopCount,
            maxWidth: appState.maxWidth,
            maxFileSizeKB: appState.maxFileSizeKB
        )
        
        // 🔧 @MainActor 프로퍼티들을 미리 캡처 (스레드 안전성)
        let useGifski = appState.useGifski
        let mp4Quality = appState.mp4Quality
        
        Task.detached {
            do {
                switch format {
                case .gif:
                    let gifskiAvailable = GifskiEncoder.isAvailable
                    
                    if useGifski && gifskiAvailable {
                        let gopts = GifskiEncoder.Options(
                            fps: Int(1.0 / (frames.first?.duration ?? 0.066)),
                            quality: opts.quality,
                            maxWidth: opts.maxWidth,
                            loopCount: opts.loopCount
                        )
                        try GifskiEncoder.encode(frames: frames, to: url, options: gopts) { p in
                            Task { @MainActor in appState.saveProgress = p }
                        }
                    } else {
                        try await GIFEncoder.encode(frames: frames, to: url, options: opts) { p in
                            Task { @MainActor in appState.saveProgress = p }
                        }
                    }
                case .mp4:
                    try await MP4Encoder.encode(frames: frames, to: url, quality: Float(mp4Quality)) { p in
                        Task { @MainActor in appState.saveProgress = p }
                    }
                default:
                    try await GIFEncoder.encode(frames: frames, to: url, options: opts) { p in
                        Task { @MainActor in appState.saveProgress = p }
                    }
                }
                
                Task { @MainActor in
                    appState.mode = .editing
                    appState.statusText = "저장 완료 ✓"
                }
            } catch {
                Task { @MainActor in
                    appState.errorText = error.localizedDescription
                    appState.mode = .editing
                }
            }
        }
    }
}

// MARK: - 안전한 배열 접근 (EditorView에서 이미 정의됨)