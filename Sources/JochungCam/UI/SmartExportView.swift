import SwiftUI

// 🚀 리리의 혁신적인 스마트 저장 다이얼로그

struct SmartExportView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    let frames: [GIFFrame]
    let onExport: (URL) -> Void
    
    // 예측 & 미리보기 엔진
    @StateObject private var sizePredictor = SizePredictor()
    @StateObject private var previewGenerator = PreviewGenerator()
    
    // UI 상태
    @State private var currentPrediction: SizePredictionResult?
    @State private var currentPreview: PreviewResult?
    @State private var isUpdating = false
    @State private var lastUpdateTime = Date()
    
    // 스마트 밸런스 슬라이더 (핵심!)
    @State private var qualitySizeBalance: Double = 0.5 // 0=최소사이즈, 1=최고품질
    
    // 원클릭 최적화 옵션들
    @State private var selectedOptimization: OptimizationPreset = .balanced
    
    enum OptimizationPreset: String, CaseIterable, Identifiable {
        case compact = "압축"
        case balanced = "균형"
        case quality = "품질"
        case lossless = "무손실"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .compact: return "적당한 크기, 좋은 품질 (2MB)"
            case .balanced: return "품질과 크기의 최적 균형 (5MB)"
            case .quality: return "높은 품질, 큰 용량 (10MB)"
            case .lossless: return "원본 품질, 매우 큰 용량"
            }
        }
        
        var icon: String {
            switch self {
            case .compact: return "archivebox.fill"
            case .balanced: return "scale.3d"
            case .quality: return "star.fill"
            case .lossless: return "crown.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .compact: return .blue
            case .balanced: return .orange
            case .quality: return .purple
            case .lossless: return .pink
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header
            
            Divider()
            
            // 메인 컨텐츠
            ScrollView {
                VStack(spacing: 20) {
                    // 실시간 미리보기 섹션
                    previewSection
                    
                    // 스마트 밸런스 컨트롤
                    balanceControlSection
                    
                    // 원클릭 최적화 프리셋
                    optimizationPresetsSection
                    
                    // 고급 설정 (접을 수 있게)
                    advancedSettingsSection
                    
                    // 예측 정보
                    predictionInfoSection
                }
                .padding(20)
            }
            
            Divider()
            
            // 하단 액션 버튼
            footerActions
        }
        .frame(width: 600, height: 700)
        .onAppear {
            setupInitialSettings()
            startRealTimeUpdates()
        }
        .onDisappear {
            previewGenerator.cancelPreview()
        }
    }
    
    // MARK: - 헤더
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("스마트 저장")
                    .font(.title2.bold())
                
                Text("\(frames.count)프레임 · \(frameInfo)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 실시간 상태 표시
            if isUpdating || previewGenerator.isGenerating {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("분석 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let prediction = currentPrediction {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(prediction.humanReadableSize)
                        .font(.headline.bold())
                        .foregroundColor(.primary)
                    
                    Text("신뢰도 \(prediction.confidencePercentage)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - 실시간 미리보기 섹션
    var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.blue)
                Text("실시간 미리보기")
                    .font(.headline)
                
                Spacer()
                
                if let preview = currentPreview {
                    Text("\(preview.frames.count)개 대표 프레임")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let preview = currentPreview {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(preview.frames.indices, id: \.self) { index in
                            let previewFrame = preview.frames[index]
                            
                            VStack(spacing: 6) {
                                // 미리보기 이미지
                                Image(nsImage: NSImage(cgImage: previewFrame.processedImage, size: .zero))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .background(Color(.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.separatorColor), lineWidth: 1)
                                    )
                                
                                // 프레임 정보
                                VStack(spacing: 2) {
                                    Text("#\(previewFrame.frameIndex + 1)")
                                        .font(.caption2.bold())
                                    
                                    Text("\(previewFrame.sizeKB)KB")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Q\(Int(previewFrame.quality))")
                                        .font(.caption2)
                                        .foregroundColor(qualityColor(previewFrame.quality))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 120)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .frame(height: 120)
                    .overlay(
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("미리보기 생성 중...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
    
    // MARK: - 스마트 밸런스 컨트롤
    var balanceControlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.orange)
                Text("품질 ↔ 크기 밸런스")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 메인 밸런스 슬라이더
                VStack(spacing: 8) {
                    Slider(value: $qualitySizeBalance, in: 0...1) { _ in
                        scheduleUpdate()
                    }
                    .accentColor(balanceColor)
                    
                    HStack {
                        VStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                            Text("작은 파일")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 현재 밸런스 표시
                        VStack(spacing: 4) {
                            Text(balanceDescription)
                                .font(.caption.bold())
                                .foregroundColor(balanceColor)
                            
                            if let prediction = currentPrediction {
                                Text("\(prediction.humanReadableSize) · \(prediction.qualityGrade)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(.purple)
                            Text("고품질")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 빠른 밸런스 버튼들
                HStack(spacing: 8) {
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                        Button(action: {
                            qualitySizeBalance = value
                            scheduleUpdate()
                        }) {
                            Text(balanceLabel(for: value))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(qualitySizeBalance == value ? .orange : .gray)
                        .controlSize(.mini)
                    }
                }
            }
        }
    }
    
    // MARK: - 원클릭 최적화 프리셋
    var optimizationPresetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.blue)
                Text("원클릭 최적화")
                    .font(.headline)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(OptimizationPreset.allCases) { preset in
                    Button(action: {
                        selectedOptimization = preset
                        applyOptimizationPreset(preset)
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: preset.icon)
                                .font(.title2)
                                .foregroundColor(preset.color)
                            
                            Text(preset.rawValue)
                                .font(.caption.bold())
                                .multilineTextAlignment(.center)
                            
                            Text(preset.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedOptimization == preset ? 
                                     preset.color.opacity(0.2) : 
                                     Color(.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedOptimization == preset ? 
                                        preset.color : 
                                        Color(.separatorColor), 
                                       lineWidth: selectedOptimization == preset ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 고급 설정
    @State private var showAdvancedSettings = false
    
    var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAdvancedSettings.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundColor(.gray)
                    Text("고급 설정")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            
            if showAdvancedSettings {
                VStack(spacing: 16) {
                    // 출력 포맷
                    HStack {
                        Text("포맷:")
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("", selection: $appState.outputFormat) {
                            ForEach(OutputFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appState.outputFormat) { _, _ in
                            scheduleUpdate()
                        }
                    }
                    
                    // 해상도 제한
                    HStack {
                        Text("최대 폭:")
                            .frame(width: 80, alignment: .leading)
                        
                        TextField("픽셀", value: $appState.maxWidth, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: appState.maxWidth) { _, _ in
                                scheduleUpdate()
                            }
                        
                        Text("px (0 = 원본)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // 파일 크기 제한
                    HStack {
                        Text("크기 제한:")
                            .frame(width: 80, alignment: .leading)
                        
                        TextField("KB", value: $appState.maxFileSizeKB, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: appState.maxFileSizeKB) { _, _ in
                                scheduleUpdate()
                            }
                        
                        Text("KB (0 = 무제한)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // 추가 옵션들
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("유사 프레임 제거", isOn: $appState.removeSimilarPixels)
                            .onChange(of: appState.removeSimilarPixels) { _, _ in scheduleUpdate() }
                        
                        Toggle("디더링", isOn: $appState.useDither)
                            .onChange(of: appState.useDither) { _, _ in scheduleUpdate() }
                        
                        if appState.outputFormat == .gif {
                            Toggle("Gifski 사용", isOn: $appState.useGifski)
                                .onChange(of: appState.useGifski) { _, _ in scheduleUpdate() }
                        }
                    }
                    .font(.caption)
                }
                .padding(12)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - 예측 정보
    var predictionInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                Text("예측 정보")
                    .font(.headline)
            }
            
            if let prediction = currentPrediction {
                VStack(spacing: 8) {
                    HStack {
                        InfoRow(title: "예상 크기", value: prediction.humanReadableSize, color: .blue)
                        Spacer()
                        InfoRow(title: "품질", value: prediction.qualityGrade, color: .purple)
                    }
                    
                    HStack {
                        InfoRow(title: "처리 시간", value: prediction.humanReadableTime, color: .orange)
                        Spacer()
                        InfoRow(title: "압축률", value: "\(prediction.compressionPercentage)%", color: .green)
                    }
                    
                    if !prediction.recommendedSettings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("💡 추천:")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                            
                            Text(prediction.recommendedSettings)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            } else {
                Text("예측 정보를 계산 중...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 하단 액션
    var footerActions: some View {
        HStack(spacing: 12) {
            Button("취소") {
                isPresented = false
            }
            .keyboardShortcut(.escape)
            
            Spacer()
            
            if let prediction = currentPrediction {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("예상: \(prediction.humanReadableSize)")
                        .font(.caption.bold())
                    Text("\(prediction.humanReadableTime) 소요")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Button("저장") {
                performSave()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
            .disabled(isUpdating || previewGenerator.isGenerating)
        }
        .padding(20)
    }
}

// MARK: - 헬퍼 뷰

struct InfoRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }
}

// MARK: - 로직 구현

extension SmartExportView {
    
    var frameInfo: String {
        guard let first = frames.first else { return "" }
        let duration = frames.reduce(0) { $0 + $1.duration }
        return "\(first.image.width)×\(first.image.height) · \(String(format: "%.1fs", duration))"
    }
    
    var balanceColor: Color {
        switch qualitySizeBalance {
        case 0..<0.3: return .green
        case 0.3..<0.7: return .orange  
        default: return .purple
        }
    }
    
    var balanceDescription: String {
        switch qualitySizeBalance {
        case 0..<0.2: return "극압축"
        case 0.2..<0.4: return "압축"
        case 0.4..<0.6: return "균형"
        case 0.6..<0.8: return "품질"
        default: return "최고품질"
        }
    }
    
    func balanceLabel(for value: Double) -> String {
        switch value {
        case 0.0: return "극소"
        case 0.25: return "압축"
        case 0.5: return "균형"
        case 0.75: return "품질"
        default: return "최고"
        }
    }
    
    func qualityColor(_ quality: Double) -> Color {
        switch quality {
        case 90...: return .green
        case 70..<90: return .orange
        default: return .red
        }
    }
    
    func setupInitialSettings() {
        // 기본값을 밸런스 슬라이더에 맞춤
        applyBalanceSettings(qualitySizeBalance)
        scheduleUpdate()
    }
    
    func scheduleUpdate() {
        lastUpdateTime = Date()
        
        // 500ms 디바운스
        Task {
            try await Task.sleep(nanoseconds: 500_000_000)
            
            if Date().timeIntervalSince(lastUpdateTime) >= 0.5 {
                await updatePredictionAndPreview()
            }
        }
    }
    
    func startRealTimeUpdates() {
        // 초기 업데이트
        Task {
            await updatePredictionAndPreview()
        }
    }
    
    @MainActor
    func updatePredictionAndPreview() async {
        isUpdating = true
        
        // 현재 설정 적용
        let options = getCurrentOptions()
        
        // 사이즈 예측 (빠름)
        let prediction = await sizePredictor.predictSize(
            frames: frames,
            options: options,
            outputFormat: appState.outputFormat
        )
        currentPrediction = prediction
        
        // 미리보기 생성 (느림, 비동기)
        do {
            let preview = try await previewGenerator.generatePreview(
                frames: frames,
                options: options,
                outputFormat: appState.outputFormat
            )
            currentPreview = preview
        } catch {
            print("미리보기 생성 실패: \(error)")
        }
        
        isUpdating = false
    }
    
    func getCurrentOptions() -> GIFEncoder.Options {
        return GIFEncoder.Options(
            maxColors: appState.gifQuality.maxColors,
            dither: appState.useDither,
            ditherLevel: appState.ditherLevel,
            speed: appState.liqSpeed,
            quality: appState.liqQuality,
            loopCount: appState.loopCount,
            maxWidth: appState.maxWidth,
            maxFileSizeKB: appState.maxFileSizeKB,
            removeSimilarPixels: appState.removeSimilarPixels
        )
    }
    
    func applyBalanceSettings(_ balance: Double) {
        // 밸런스 값에 따라 설정 자동 조절
        switch balance {
        case 0..<0.2: // 극압축
            appState.gifQuality = .tiny
            appState.maxWidth = 320
            appState.liqQuality = 80
            appState.removeSimilarPixels = true
        case 0.2..<0.4: // 압축
            appState.gifQuality = .low
            appState.maxWidth = 480
            appState.liqQuality = 85
            appState.removeSimilarPixels = true
        case 0.4..<0.6: // 균형
            appState.gifQuality = .medium
            appState.maxWidth = 640
            appState.liqQuality = 90
            appState.removeSimilarPixels = true
        case 0.6..<0.8: // 품질
            appState.gifQuality = .high
            appState.maxWidth = 0
            appState.liqQuality = 95
            appState.removeSimilarPixels = false
        default: // 최고품질
            appState.gifQuality = .high
            appState.maxWidth = 0
            appState.liqQuality = 100
            appState.removeSimilarPixels = false
        }
    }
    
    func applyOptimizationPreset(_ preset: OptimizationPreset) {
        switch preset {
        case .compact:
            qualitySizeBalance = 0.3
            appState.maxFileSizeKB = 2000
        case .balanced:
            qualitySizeBalance = 0.5
            appState.maxFileSizeKB = 3000
        case .quality:
            qualitySizeBalance = 0.75
            appState.maxFileSizeKB = 0
        case .lossless:
            qualitySizeBalance = 1.0
            appState.maxFileSizeKB = 0
            appState.outputFormat = .apng
        }
        
        applyBalanceSettings(qualitySizeBalance)
        scheduleUpdate()
    }
    
    func performSave() {
        // 기존 저장 로직과 연결
        let savePanel = NSSavePanel()
        savePanel.title = "스마트 저장"
        savePanel.allowedContentTypes = [.init(filenameExtension: appState.outputFormat.ext)!]
        savePanel.nameFieldStringValue = "jochung_smart.\(appState.outputFormat.ext)"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            onExport(url)
            isPresented = false
        }
    }
}