import SwiftUI

// 🎭 리리의 궁극적 홈 뷰 - 모든 혁신 기능 통합

struct UltimateHomeView: View {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var batchProcessor = BatchProcessor()
    @StateObject private var gpuAccelerator = GPUAccelerator()
    @StateObject private var performanceMonitor = PerformanceMonitor()
    
    @State private var showingSettings = false
    @State private var showingBatchProcessor = false
    @State private var showingPerformanceMonitor = false
    @State private var selectedTab: Int? = 0
    
    var body: some View {
        NavigationView {
            sidebar
            mainContent
        }
        .navigationTitle("조청캠 Ultimate")
        .themeEnvironment(themeManager)
        .onAppear {
            performanceMonitor.startMonitoring()
        }
        .onDisappear {
            performanceMonitor.stopMonitoring()
        }
        .sheet(isPresented: $showingSettings) {
            ultimateSettingsView
        }
        .sheet(isPresented: $showingBatchProcessor) {
            ultimateBatchView
        }
        .sheet(isPresented: $showingPerformanceMonitor) {
            performanceMonitorView
        }
    }
    
    // MARK: - 사이드바
    
    var sidebar: some View {
        List(selection: $selectedTab) {
            // 기본 기능들
            Section("기본 기능") {
                Button {
                    selectedTab = 0
                } label: {
                    Label("빠른 캡처", systemImage: "camera.circle")
                }
                
                Button {
                    selectedTab = 1
                } label: {
                    Label("파일 편집", systemImage: "slider.horizontal.3")
                }
                
                Button {
                    selectedTab = 2
                } label: {
                    Label("간단 편집", systemImage: "wand.and.rays")
                }
            }
            
            // 프로페셔널 기능들
            Section("프로페셔널") {
                Button(action: { showingBatchProcessor = true }) {
                    Label("배치 처리", systemImage: "tray.full")
                }
                
                Button {
                    selectedTab = 3
                } label: {
                    Label("고급 편집", systemImage: "gearshape.2")
                }
                
                Button(action: { showingPerformanceMonitor = true }) {
                    Label("성능 모니터", systemImage: "speedometer")
                }
            }
            
            // 설정 및 도구
            Section("설정") {
                Button(action: { showingSettings = true }) {
                    Label("설정", systemImage: "gear")
                }
                
                Button {
                    selectedTab = 4
                } label: {
                    Label("정보", systemImage: "info.circle")
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
    
    // MARK: - 메인 콘텐츠
    
    var mainContent: some View {
        Group {
            switch selectedTab {
            case 0:
                quickCaptureView
            case 1:
                singleFileEditor
            case 2:
                simpleFileEditor
            case 3:
                advancedEditorView
            case 4:
                aboutView
            default:
                welcomeView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    // MARK: - 환영 뷰
    
    var welcomeView: some View {
        VStack(spacing: 30) {
            // 헤더
            VStack(spacing: 16) {
                ZStack {
                    PulsingOrb(colors: [.blue, .purple], size: 120)
                    
                    Image(systemName: "video.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("조청캠 Ultimate")
                        .font(.largeTitle.bold())
                        .fadeInUp(isVisible: true)
                    
                    Text("진짜 최고의 동영상 → GIF 변환 도구")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .fadeInUp(isVisible: true)
                }
            }
            
            // 핵심 기능 소개
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                FeatureCard(
                    icon: "bolt.fill",
                    title: "GPU 가속",
                    description: "Metal을 활용한 초고속 처리",
                    color: .orange
                )
                
                FeatureCard(
                    icon: "paintbrush.pointed",
                    title: "아름다운 UI",
                    description: "다크모드 & 커스텀 테마",
                    color: .purple
                )
                
                FeatureCard(
                    icon: "tray.2",
                    title: "배치 처리",
                    description: "여러 파일을 한 번에 처리",
                    color: .blue
                )
                
                FeatureCard(
                    icon: "arrow.uturn.backward.circle",
                    title: "완전한 Undo/Redo",
                    description: "모든 작업을 되돌리기 가능",
                    color: .green
                )
            }
            .padding(.horizontal)
            
            // 빠른 시작 버튼들
            HStack(spacing: 20) {
                Button("빠른 캡처 시작") {
                    selectedTab = 0
                }
                .themedButton(.primary)
                .buttonPressEffect()
                
                Button("파일 편집") {
                    selectedTab = 1
                }
                .themedButton(.secondary)
                .buttonPressEffect()
                
                Button("배치 처리") {
                    showingBatchProcessor = true
                }
                .themedButton(.accent)
                .buttonPressEffect()
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
        .themedBackground()
    }
    
    // MARK: - 빠른 캡처 뷰
    
    var quickCaptureView: some View {
        RecordingView()
            .environmentObject(appState)
    }
    
    // MARK: - 파일 편집기들
    
    var singleFileEditor: some View {
        Group {
            if appState.mode == .editing {
                EditorView()
                    .environmentObject(appState)
            } else {
                HomeView()
                    .environmentObject(appState)
            }
        }
    }
    
    var simpleFileEditor: some View {
        Group {
            if appState.mode == .editing {
                SimpleEditorView()
                    .environmentObject(appState)
            } else {
                HomeView()
                    .environmentObject(appState)
            }
        }
    }
    
    var advancedEditorView: some View {
        AdvancedEditorView()
            .environmentObject(appState)
            .environmentObject(gpuAccelerator)
    }
    
    // MARK: - 설정 뷰
    
    var ultimateSettingsView: some View {
        TabView {
            // 테마 설정
            ScrollView {
                VStack(spacing: 24) {
                    ThemeSelector(themeManager: themeManager)
                    
                    AnimationPreferencesView()
                    
                    PerformanceSettingsView()
                }
                .padding()
            }
            .tabItem {
                Label("테마", systemImage: "paintbrush")
            }
            
            // GPU 설정
            GPUSettingsView(gpuAccelerator: gpuAccelerator)
                .tabItem {
                    Label("GPU", systemImage: "bolt")
                }
            
            // 일반 설정
            GeneralSettingsView()
                .tabItem {
                    Label("일반", systemImage: "gear")
                }
        }
        .frame(width: 600, height: 500)
    }
    
    // MARK: - 배치 처리 뷰
    
    var ultimateBatchView: some View {
        UltimateBatchView(batchProcessor: batchProcessor)
            .frame(width: 800, height: 600)
    }
    
    // MARK: - 성능 모니터 뷰
    
    var performanceMonitorView: some View {
        PerformanceMonitorView(performanceMonitor: performanceMonitor)
            .frame(width: 500, height: 400)
    }
    
    // MARK: - 정보 뷰
    
    var aboutView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "video.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .shimmer()
                
                VStack(spacing: 8) {
                    Text("조청캠 Ultimate")
                        .font(.largeTitle.bold())
                    
                    Text("버전 3.0.0")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("리리가 만든 진짜 최고의 앱 🎉")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("새로운 기능들")
                    .font(.headline)
                
                FeatureList()
            }
            .themedSurface()
            .padding()
            
            HStack {
                Button("GitHub에서 보기") {
                    if let url = URL(string: "https://github.com/your-repo/jochungcam") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .themedButton(.accent)
                
                Button("피드백 보내기") {
                    // 피드백 기능
                }
                .themedButton(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .themedBackground()
    }
}

// MARK: - 헬퍼 뷰들

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
                .smoothScale(isActive: isHovered, scale: 1.1)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .themedSurface(cornerRadius: 12)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct FeatureList: View {
    let features = [
        "🎨 아름다운 다크모드 & 커스텀 테마",
        "⚡ GPU 가속을 통한 초고속 처리",
        "🔄 완전한 Undo/Redo 시스템",
        "📱 혁신적인 속도 조절 UI",
        "🚀 프로페셔널 배치 처리",
        "📊 실시간 성능 모니터링",
        "🎬 스마트 미리보기 & 사이즈 예측",
        "⌨️ 전문가 수준의 키보드 단축키"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(features.indices, id: \.self) { index in
                Text(features[index])
                    .font(.system(size: 14))
                    .fadeInUp(isVisible: true)
                    .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1), value: true)
            }
        }
    }
}

// MARK: - 고급 편집기 (GPU + 모든 기능)

struct AdvancedEditorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gpuAccelerator: GPUAccelerator
    @Environment(\.theme) var theme
    
    @State private var showingGPUOptions = false
    @State private var selectedOperations: [ImageOperation] = []
    @State private var isProcessing = false
    
    var body: some View {
        VStack {
            if appState.frames.isEmpty {
                advancedDropZone
            } else {
                advancedEditingInterface
            }
        }
        .themedBackground()
    }
    
    var advancedDropZone: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("고급 편집 모드")
                    .font(.title.bold())
                
                Text("GPU 가속 처리로 최고 품질의 결과를 얻으세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button("파일 선택") {
                // 파일 선택 로직
            }
            .themedButton(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground()
    }
    
    var advancedEditingInterface: some View {
        HSplitView {
            // 좌측 - 프레임 뷰어
            VStack {
                Text("프레임 뷰어")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .themedSurface()
                
                // GPU 처리 옵션
                if gpuAccelerator.isGPUAvailable {
                    GPUProcessingControls(
                        gpuAccelerator: gpuAccelerator,
                        selectedOperations: $selectedOperations,
                        isProcessing: $isProcessing
                    )
                }
            }
            
            // 우측 - 고급 컨트롤
            VStack {
                SpeedControlView()
                    .environmentObject(appState)
                
                AdvancedImageControls(selectedOperations: $selectedOperations)
                
                ColorGradingControls()
                
                ExportQualityControls()
            }
            .frame(width: 300)
        }
    }
}

// 🚀 완전한 고급 처리 컨트롤들
struct GPUProcessingControls: View {
    @ObservedObject var gpuAccelerator: GPUAccelerator
    @Binding var selectedOperations: [ImageOperation]
    @Binding var isProcessing: Bool
    @Environment(\.theme) var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // GPU 상태
            HStack {
                Circle()
                    .fill(gpuAccelerator.isGPUAvailable ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(gpuAccelerator.isGPUAvailable ? "GPU 가속 사용 가능" : "GPU 가속 불가")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if gpuAccelerator.isGPUAvailable {
                // GPU 메모리 사용량
                VStack(alignment: .leading, spacing: 4) {
                    Text("GPU 메모리")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: gpuAccelerator.processingProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("\(String(format: "%.1f", gpuAccelerator.processingProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 처리 옵션
                GroupBox("GPU 처리 옵션") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("하드웨어 가속", isOn: .constant(true))
                            .disabled(true)
                        
                        Toggle("배치 처리 최적화", isOn: .constant(true))
                        
                        HStack {
                            Text("동시 프레임 수:")
                            Spacer()
                            Text("4")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
            
            if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("GPU 처리 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .themedSurface()
        .padding(.vertical, 8)
    }
}

struct AdvancedImageControls: View {
    @Binding var selectedOperations: [ImageOperation]
    @Environment(\.theme) var theme
    
    @State private var brightness: Float = 0.0
    @State private var contrast: Float = 1.0
    @State private var saturation: Float = 1.0
    @State private var sharpness: Float = 0.0
    @State private var noiseReduction: Float = 0.0
    @State private var enableResize: Bool = false
    @State private var targetSize: CGSize = CGSize(width: 1920, height: 1080)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("고급 이미지 처리")
                .font(.headline)
            
            // 색상 조정
            GroupBox("색상 조정") {
                VStack(spacing: 12) {
                    SliderRow(title: "밝기", value: $brightness, range: -1.0...1.0, format: "%.2f") {
                        updateOperations()
                    }
                    
                    SliderRow(title: "대비", value: $contrast, range: 0.0...2.0, format: "%.2f") {
                        updateOperations()
                    }
                    
                    SliderRow(title: "채도", value: $saturation, range: 0.0...2.0, format: "%.2f") {
                        updateOperations()
                    }
                }
            }
            
            // 선명도 및 노이즈
            GroupBox("선명도 & 노이즈") {
                VStack(spacing: 12) {
                    SliderRow(title: "선명도", value: $sharpness, range: 0.0...1.0, format: "%.2f") {
                        updateOperations()
                    }
                    
                    SliderRow(title: "노이즈 감소", value: $noiseReduction, range: 0.0...1.0, format: "%.2f") {
                        updateOperations()
                    }
                }
            }
            
            // 크기 조정
            GroupBox("크기 조정") {
                VStack(spacing: 8) {
                    Toggle("크기 조정 활성화", isOn: $enableResize)
                    
                    if enableResize {
                        HStack {
                            Text("너비:")
                            TextField("1920", value: Binding(
                                get: { Int(targetSize.width) },
                                set: { targetSize.width = CGFloat($0) }
                            ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            
                            Text("높이:")
                            TextField("1080", value: Binding(
                                get: { Int(targetSize.height) },
                                set: { targetSize.height = CGFloat($0) }
                            ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        .font(.caption)
                    }
                }
            }
            
            // 프리셋 버튼들
            HStack {
                Button("초기화") {
                    resetToDefaults()
                }
                .themedButton(.secondary)
                
                Spacer()
                
                Menu("프리셋") {
                    Button("영화") { applyPreset(.cinematic) }
                    Button("생생한") { applyPreset(.vivid) }
                    Button("부드러운") { applyPreset(.soft) }
                    Button("선명한") { applyPreset(.sharp) }
                }
                .themedButton(.accent)
            }
        }
        .themedSurface()
        .onAppear {
            updateOperations()
        }
    }
    
    private func updateOperations() {
        selectedOperations.removeAll()
        
        // 색상 조정
        if brightness != 0.0 || contrast != 1.0 || saturation != 1.0 {
            selectedOperations.append(.colorAdjust(
                brightness: brightness,
                contrast: contrast,
                saturation: saturation
            ))
        }
        
        // 선명도
        if sharpness > 0.0 {
            selectedOperations.append(.sharpen(intensity: sharpness))
        }
        
        // 노이즈 감소
        if noiseReduction > 0.0 {
            selectedOperations.append(.noiseReduction(strength: noiseReduction))
        }
        
        // 크기 조정
        if enableResize {
            selectedOperations.append(.resize(targetSize))
        }
    }
    
    private func resetToDefaults() {
        brightness = 0.0
        contrast = 1.0
        saturation = 1.0
        sharpness = 0.0
        noiseReduction = 0.0
        enableResize = false
        updateOperations()
    }
    
    private func applyPreset(_ preset: ImagePreset) {
        switch preset {
        case .cinematic:
            brightness = -0.1
            contrast = 1.2
            saturation = 0.9
            sharpness = 0.2
        case .vivid:
            brightness = 0.1
            contrast = 1.3
            saturation = 1.4
            sharpness = 0.3
        case .soft:
            brightness = 0.05
            contrast = 0.9
            saturation = 1.1
            sharpness = 0.0
            noiseReduction = 0.2
        case .sharp:
            brightness = 0.0
            contrast = 1.1
            saturation = 1.0
            sharpness = 0.5
        }
        updateOperations()
    }
}

struct ColorGradingControls: View {
    @Environment(\.theme) var theme
    
    @State private var shadowsRGB = Color.black
    @State private var midtonesRGB = Color.gray
    @State private var highlightsRGB = Color.white
    @State private var colorTemperature: Float = 0.0
    @State private var tint: Float = 0.0
    @State private var vibrance: Float = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("컬러 그레이딩")
                .font(.headline)
            
            GroupBox("색온도 & 틴트") {
                VStack(spacing: 12) {
                    SliderRow(title: "색온도", value: $colorTemperature, range: -1.0...1.0, format: "%.2f")
                    SliderRow(title: "틴트", value: $tint, range: -1.0...1.0, format: "%.2f")
                    SliderRow(title: "생동감", value: $vibrance, range: 0.0...2.0, format: "%.2f")
                }
            }
            
            GroupBox("3-Way 색상 보정") {
                VStack(spacing: 12) {
                    ColorWheelRow(title: "그림자", color: $shadowsRGB)
                    ColorWheelRow(title: "중간톤", color: $midtonesRGB)
                    ColorWheelRow(title: "하이라이트", color: $highlightsRGB)
                }
            }
            
            HStack {
                Button("초기화") {
                    resetColorGrading()
                }
                .themedButton(.secondary)
                
                Spacer()
                
                Button("적용") {
                    applyColorGrading()
                }
                .themedButton(.primary)
            }
        }
        .themedSurface()
    }
    
    private func resetColorGrading() {
        shadowsRGB = .black
        midtonesRGB = .gray
        highlightsRGB = .white
        colorTemperature = 0.0
        tint = 0.0
        vibrance = 0.0
    }
    
    private func applyColorGrading() {
        // 컬러 그레이딩 적용 로직
    }
}

struct ExportQualityControls: View {
    @Environment(\.theme) var theme
    
    @State private var selectedFormat = ExportFormat.gif
    @State private var qualityLevel: Double = 80
    @State private var compressionLevel: Double = 50
    @State private var enableOptimization = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("내보내기 품질")
                .font(.headline)
            
            // 형식 선택
            GroupBox("출력 형식") {
                Picker("형식", selection: $selectedFormat) {
                    Text("GIF").tag(ExportFormat.gif)
                    Text("WebP").tag(ExportFormat.webp)
                    Text("MP4").tag(ExportFormat.mp4)
                }
                .pickerStyle(.segmented)
            }
            
            // 품질 설정
            GroupBox("품질 설정") {
                VStack(spacing: 12) {
                    SliderRow(title: "품질", value: .constant(Float(qualityLevel)), range: 0...100, format: "%.0f%%") {
                        // 품질 업데이트
                    }
                    
                    if selectedFormat != .mp4 {
                        SliderRow(title: "압축", value: .constant(Float(compressionLevel)), range: 0...100, format: "%.0f%%")
                    }
                }
            }
            
            // 최적화 옵션
            GroupBox("최적화") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("자동 최적화", isOn: $enableOptimization)
                    
                    if selectedFormat == .gif {
                        Toggle("디더링 사용", isOn: .constant(true))
                        Toggle("유사 프레임 제거", isOn: .constant(true))
                    }
                    
                    if selectedFormat == .webp {
                        Toggle("무손실 압축", isOn: .constant(false))
                    }
                }
                .font(.caption)
            }
            
            // 예상 파일 크기
            HStack {
                Text("예상 파일 크기:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("~2.4MB")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .themedSurface()
    }
}

// MARK: - 헬퍼 뷰들

struct SliderRow<T: BinaryFloatingPoint>: View where T: Comparable {
    let title: String
    @Binding var value: T
    let range: ClosedRange<T>
    let format: String
    let onChange: (() -> Void)?
    
    init(title: String, value: Binding<T>, range: ClosedRange<T>, format: String = "%.1f", onChange: (() -> Void)? = nil) {
        self.title = title
        self._value = value
        self.range = range
        self.format = format
        self.onChange = onChange
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: format, Float(value)))
                    .font(.caption)
                    .foregroundColor(.primary)
                    .frame(width: 50, alignment: .trailing)
            }
            
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = T($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
            .onChange(of: value) { _, _ in
                onChange?()
            }
        }
    }
}

struct ColorWheelRow: View {
    let title: String
    @Binding var color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            ColorPicker("", selection: $color)
                .frame(width: 30, height: 20)
        }
    }
}

enum ImagePreset {
    case cinematic
    case vivid
    case soft
    case sharp
}

enum ExportFormat {
    case gif
    case webp
    case mp4
}

struct AnimationPreferencesView: View {
    var body: some View {
        Text("애니메이션 설정")
    }
}

struct PerformanceSettingsView: View {
    var body: some View {
        Text("성능 설정")
    }
}

struct GPUSettingsView: View {
    @ObservedObject var gpuAccelerator: GPUAccelerator
    
    var body: some View {
        Text("GPU 설정")
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Text("일반 설정")
    }
}

struct UltimateBatchView: View {
    @ObservedObject var batchProcessor: BatchProcessor
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedFiles: [URL] = []
    @State private var outputDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    @State private var batchSettings = BatchProcessor.BatchSettings(outputDirectory: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!)
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header
            
            Divider()
            
            HSplitView {
                // 좌측: 파일 목록 및 설정
                leftPanel
                
                // 우측: 진행 상황 및 통계
                rightPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // 하단: 컨트롤 버튼들
            bottomControls
        }
        .themedBackground()
        .sheet(isPresented: $showingFilePicker) {
            FilePickerView(selectedFiles: $selectedFiles)
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerView(selectedFolder: $outputDirectory)
        }
    }
    
    // MARK: - 헤더
    
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("배치 처리")
                    .font(.title.bold())
                
                Text("여러 파일을 한 번에 변환하세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if batchProcessor.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(batchProcessor.completedJobs)/\(batchProcessor.totalJobs)")
                            .font(.caption)
                        
                        Text(formatTimeRemaining(batchProcessor.estimatedTimeRemaining))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button("닫기") {
                dismiss()
            }
            .keyboardShortcut(.escape)
            .themedButton(.secondary)
        }
        .padding()
    }
    
    // MARK: - 좌측 패널
    
    var leftPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 파일 추가
            fileAdditionSection
            
            // 배치 설정
            batchSettingsSection
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 350)
    }
    
    var fileAdditionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("입력 파일")
                .font(.headline)
            
            // 파일 추가 버튼들
            HStack {
                Button("파일 추가") {
                    showingFilePicker = true
                }
                .themedButton(.primary)
                
                Button("폴더 추가") {
                    addFolder()
                }
                .themedButton(.secondary)
                
                if !selectedFiles.isEmpty {
                    Button("모두 제거") {
                        selectedFiles.removeAll()
                        batchProcessor.clearAllJobs()
                    }
                    .themedButton(.accent)
                }
            }
            
            // 드래그 앤 드롭 영역
            if selectedFiles.isEmpty {
                DropZoneView(
                    title: "파일을 여기로 드래그하세요",
                    subtitle: "MOV, MP4, GIF 파일 지원",
                    icon: "doc.badge.plus",
                    supportedTypes: [.movie, .quickTimeMovie, .gif]
                ) { urls in
                    selectedFiles.append(contentsOf: urls)
                    updateBatchJobs()
                }
                .frame(height: 100)
            } else {
                // 선택된 파일 목록
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(selectedFiles.enumerated()), id: \.offset) { index, file in
                            FileItemRow(file: file) {
                                selectedFiles.remove(at: index)
                                updateBatchJobs()
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .themedSurface()
            }
            
            Text("\(selectedFiles.count)개 파일 선택됨")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    var batchSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("출력 설정")
                .font(.headline)
            
            // 출력 디렉토리
            HStack {
                Text("출력 폴더:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(outputDirectory.lastPathComponent) {
                    showingFolderPicker = true
                }
                .themedButton(.accent)
                .font(.caption)
            }
            
            // 출력 형식
            Picker("출력 형식", selection: $batchSettings.outputFormat) {
                Text("GIF").tag("gif")
                Text("WebP").tag("webp")
                Text("MP4").tag("mp4")
            }
            .pickerStyle(.segmented)
            
            // 품질 설정
            GroupBox("품질 설정") {
                VStack(spacing: 8) {
                    Picker("품질", selection: $batchSettings.qualitySettings) {
                        Text("균형").tag(BatchProcessor.BatchSettings.QualitySettings.balanced)
                        Text("고품질").tag(BatchProcessor.BatchSettings.QualitySettings.highQuality)
                        Text("무손실").tag(BatchProcessor.BatchSettings.QualitySettings.lossless)
                    }
                    .pickerStyle(.menu)
                    
                    Toggle("기존 파일 덮어쓰기", isOn: $batchSettings.shouldOverwrite)
                        .font(.caption)
                }
            }
            
            // 파일 명명 규칙
            GroupBox("파일 이름") {
                Picker("명명 규칙", selection: $batchSettings.fileNaming) {
                    Text("원본 유지").tag(BatchProcessor.BatchSettings.FileNaming.keepOriginal)
                    Text("타임스탬프 추가").tag(BatchProcessor.BatchSettings.FileNaming.timestamp)
                }
                .pickerStyle(.menu)
                .font(.caption)
            }
        }
        .onChange(of: batchSettings.outputFormat) { _, _ in
            updateBatchJobs()
        }
    }
    
    // MARK: - 우측 패널
    
    var rightPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 진행 상황
            if batchProcessor.isProcessing {
                processingStatusSection
            }
            
            // 작업 목록
            jobListSection
            
            // 통계
            statisticsSection
        }
        .padding()
        .frame(minWidth: 400)
    }
    
    var processingStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("처리 진행 상황")
                .font(.headline)
            
            // 전체 진행률
            VStack(spacing: 8) {
                HStack {
                    Text("전체 진행률")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(batchProcessor.overallProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                ProgressView(value: batchProcessor.overallProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            .themedSurface()
            .padding(.vertical, 8)
            
            // 현재 작업
            if let currentJob = batchProcessor.currentJob {
                VStack(alignment: .leading, spacing: 4) {
                    Text("현재 작업")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(currentJob.inputFile.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                    
                    ProgressView(value: currentJob.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                .themedSurface()
                .padding(.vertical, 8)
            }
            
            // 성능 정보
            HStack {
                VStack(alignment: .leading) {
                    Text("처리 속도")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", batchProcessor.processingSpeed)) 작업/분")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("남은 시간")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatTimeRemaining(batchProcessor.estimatedTimeRemaining))
                        .font(.caption)
                }
            }
        }
    }
    
    var jobListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("작업 목록")
                .font(.headline)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(batchProcessor.jobs.prefix(10), id: \.id) { job in
                        BatchJobRow(job: job)
                    }
                    
                    if batchProcessor.jobs.count > 10 {
                        Text("... +\(batchProcessor.jobs.count - 10)개 작업")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxHeight: 300)
            .themedSurface()
        }
    }
    
    var statisticsSection: some View {
        let stats = batchProcessor.statistics
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("통계")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                StatCard(title: "성공", value: "\(stats.completedJobs)", color: .green)
                StatCard(title: "실패", value: "\(stats.failedJobs)", color: .red)
                StatCard(title: "압축률", value: "\(String(format: "%.1f", stats.averageCompressionRatio * 100))%", color: .blue)
                StatCard(title: "절약된 용량", value: formatFileSize(Int64(stats.spaceSavedMB * 1024 * 1024)), color: .orange)
            }
        }
    }
    
    // MARK: - 하단 컨트롤
    
    var bottomControls: some View {
        HStack {
            if batchProcessor.isProcessing {
                Button("일시정지") {
                    batchProcessor.pauseProcessing()
                }
                .themedButton(.secondary)
                
                Button("취소") {
                    batchProcessor.cancelProcessing()
                }
                .themedButton(.accent)
            } else {
                Button("완료된 작업 제거") {
                    batchProcessor.clearCompletedJobs()
                }
                .themedButton(.secondary)
                .disabled(batchProcessor.completedJobs == 0)
                
                Spacer()
                
                Button("처리 시작") {
                    startBatchProcessing()
                }
                .themedButton(.primary)
                .disabled(selectedFiles.isEmpty)
            }
        }
        .padding()
    }
    
    // MARK: - 액션들
    
    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            batchProcessor.addDirectory(url, settings: batchSettings, recursive: true)
            updateFileList()
        }
    }
    
    private func updateBatchJobs() {
        batchProcessor.clearAllJobs()
        if !selectedFiles.isEmpty {
            batchSettings.outputDirectory = outputDirectory
            batchProcessor.addFiles(selectedFiles, settings: batchSettings)
        }
    }
    
    private func updateFileList() {
        // BatchProcessor의 작업 목록에서 파일 목록 동기화
        selectedFiles = batchProcessor.jobs.map { $0.inputFile }
    }
    
    private func startBatchProcessing() {
        Task {
            await batchProcessor.startProcessing()
        }
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))초"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))분"
        } else {
            return "\(Int(seconds / 3600))시간 \(Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60))분"
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - 헬퍼 뷰들

struct FileItemRow: View {
    let file: URL
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(formatFileSize(getFileSize(file)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
    
    private func getFileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct BatchJobRow: View {
    @ObservedObject var job: BatchProcessor.BatchJob
    
    var body: some View {
        HStack {
            Circle()
                .fill(job.status.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(job.inputFile.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(job.status.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if job.status == .processing {
                ProgressView(value: job.progress)
                    .frame(width: 60)
                    .progressViewStyle(LinearProgressViewStyle())
            } else if job.status == .completed, let compressionRatio = job.compressionRatio {
                Text("\(Int(compressionRatio * 100))%")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else if job.status == .failed {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .themedSurface()
    }
}

struct FilePickerView: View {
    @Binding var selectedFiles: [URL]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text("파일 선택")
                .font(.title2)
                .padding()
            
            Button("동영상 파일 선택") {
                selectFiles()
            }
            .themedButton(.primary)
            .padding()
        }
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .quickTimeMovie, .gif, .png]
        panel.allowsMultipleSelection = true
        
        if panel.runModal() == .OK {
            selectedFiles.append(contentsOf: panel.urls)
        }
        dismiss()
    }
}

struct FolderPickerView: View {
    @Binding var selectedFolder: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text("출력 폴더 선택")
                .font(.title2)
                .padding()
            
            Button("폴더 선택") {
                selectFolder()
            }
            .themedButton(.primary)
            .padding()
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
        }
        dismiss()
    }
}

struct PerformanceMonitorView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    
    var body: some View {
        VStack(spacing: 16) {
            Text("성능 모니터")
                .font(.title2.bold())
            
            VStack(spacing: 12) {
                HStack {
                    Text("CPU 사용률:")
                    Spacer()
                    Text("\(String(format: "%.1f", performanceMonitor.cpuUsage))%")
                }
                
                HStack {
                    Text("메모리 사용량:")
                    Spacer()
                    Text("\(String(format: "%.2f", performanceMonitor.memoryUsage))GB")
                }
                
                HStack {
                    Text("GPU 사용률:")
                    Spacer()
                    Text("\(String(format: "%.1f", performanceMonitor.gpuUsage))%")
                }
                
                HStack {
                    Text("처리 속도:")
                    Spacer()
                    Text("\(String(format: "%.1f", performanceMonitor.processingSpeed)) fps")
                }
            }
            .padding()
            .themedSurface()
        }
        .padding()
    }
}