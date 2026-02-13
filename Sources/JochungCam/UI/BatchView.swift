import SwiftUI
import UniformTypeIdentifiers

struct BatchConvertView: View {
    @EnvironmentObject var appState: AppState
    @State private var files: [URL] = []
    @State private var outputDir: URL? = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    @State private var isConverting = false
    @State private var progress: Double = 0
    @State private var status: String = ""
    @State private var isDragOver = false
    @State private var completed: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(HCTheme.accent)
                Text("배치 변환").font(.system(size: 14, weight: .bold))
                Spacer()
                if !files.isEmpty { HCTag("\(files.count)개 파일") }
            }
            .padding(.horizontal, HCTheme.padLg).padding(.vertical, HCTheme.pad)

            Divider().opacity(0.3)

            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: HCTheme.radius)
                    .fill(isDragOver ? HCTheme.accentDim : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: HCTheme.radius)
                            .strokeBorder(isDragOver ? HCTheme.accent : HCTheme.border,
                                          style: StrokeStyle(lineWidth: 1, dash: isDragOver ? [] : [6, 4]))
                    )
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.doc").font(.title3).foregroundColor(HCTheme.textTertiary)
                    Text(files.isEmpty ? "파일 드래그 또는 클릭" : "\(files.count)개 파일 준비됨")
                        .font(HCTheme.caption).foregroundColor(HCTheme.textSecondary)
                }
            }
            .frame(height: 80)
            .padding(HCTheme.padLg)
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { handleDrop($0) }
            .onTapGesture { addFiles() }

            // File list
            if !files.isEmpty {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(files, id: \.absoluteString) { url in
                            HStack {
                                Image(systemName: fileIcon(url)).font(.system(size: 9)).foregroundColor(HCTheme.textTertiary)
                                Text(url.lastPathComponent).font(HCTheme.caption).lineLimit(1)
                                Spacer()
                                Text(fileSizeStr(url)).font(HCTheme.microMono).foregroundColor(HCTheme.textTertiary)
                                Button(action: { files.removeAll { $0 == url } }) {
                                    Image(systemName: "xmark").font(.system(size: 8))
                                }.buttonStyle(.plain).foregroundColor(HCTheme.textTertiary)
                            }
                            .padding(.horizontal, HCTheme.pad).padding(.vertical, 3)
                        }
                    }
                }.frame(maxHeight: 120).padding(.horizontal, HCTheme.pad)
            }

            Spacer()

            // Output settings
            HCCard {
                HStack {
                    Text("출력 →").font(HCTheme.caption).foregroundColor(HCTheme.textSecondary)
                    ForEach(OutputFormat.allCases) { fmt in
                        HCPillButton(fmt.rawValue, isActive: appState.outputFormat == fmt) {
                            appState.outputFormat = fmt
                        }
                    }
                    Spacer()
                    if appState.outputFormat == .gif {
                        ForEach(GIFQuality.allCases) { q in
                            HCPillButton(q.rawValue, isActive: appState.gifQuality == q) {
                                appState.gifQuality = q
                            }
                        }
                    }
                }
            }.padding(.horizontal, HCTheme.padLg)

            // Progress
            if isConverting {
                VStack(spacing: 6) {
                    ProgressView(value: progress)
                        .tint(HCTheme.accent).frame(width: 200)
                    Text(status).font(HCTheme.micro).foregroundColor(HCTheme.textSecondary)
                }.padding(.top, HCTheme.pad)
            }

            Divider().opacity(0.3).padding(.top, HCTheme.pad)

            // Bottom
            HStack {
                Button("초기화") { files = []; progress = 0; status = ""; completed = 0 }
                    .disabled(isConverting).font(HCTheme.caption)
                Spacer()
                Button(action: startBatch) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.system(size: 10))
                        Text("변환 시작").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(HCTheme.accent).foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: HCTheme.radiusSm))
                }
                .buttonStyle(.plain)
                .disabled(files.isEmpty || isConverting)
            }
            .padding(.horizontal, HCTheme.padLg).padding(.vertical, HCTheme.pad)
        }
        .frame(minWidth: 400, maxWidth: 400, minHeight: 380)
    }

    func fileIcon(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["gif", "webp", "png", "apng"].contains(ext) { return "photo" }
        if ["mp4", "mov", "m4v", "webm"].contains(ext) { return "film" }
        return "doc"
    }

    func fileSizeStr(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int else { return "" }
        return size > 1_048_576 ? String(format: "%.1fMB", Double(size) / 1_048_576) :
               String(format: "%dKB", size / 1024)
    }

    func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.gif, .mpeg4Movie, .quickTimeMovie, .png, .webP]
        panel.begin { r in guard r == .OK else { return }; files.append(contentsOf: panel.urls) }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for p in providers {
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async { files.append(url) }
            }
        }
        return true
    }

    func startBatch() {
        isConverting = true; progress = 0; completed = 0
        let filesToConvert = files
        let format = appState.outputFormat
        let opts = GIFEncoder.Options(maxColors: appState.gifQuality.maxColors, dither: appState.useDither,
            ditherLevel: appState.ditherLevel, speed: appState.liqSpeed, quality: appState.liqQuality, maxWidth: appState.maxWidth)
        let useGifski = appState.useGifski
        let fps = appState.fps
        let dir = outputDir!

        Task.detached {
            for (i, url) in filesToConvert.enumerated() {
                await MainActor.run { status = "\(url.lastPathComponent) (\(i + 1)/\(filesToConvert.count))" }
                var frames: [GIFFrame]?
                let ext = url.pathExtension.lowercased()
                if ["gif", "webp", "apng", "png"].contains(ext) { frames = FrameOps.importGIF(from: url) }
                else if ["mp4", "mov", "m4v"].contains(ext) { 
                    frames = await FrameOps.importVideo(from: url, fps: Double(fps)) { progress, status in
                        Task { @MainActor in 
                            self.status = "\(url.lastPathComponent): \(status)"
                        }
                    }
                }
                guard let frames, !frames.isEmpty else { continue }
                let outName = url.deletingPathExtension().lastPathComponent + "." + format.ext
                let outURL = dir.appendingPathComponent(outName)
                switch format {
                case .gif:
                    if useGifski && GifskiEncoder.isAvailable {
                        try? GifskiEncoder.encode(frames: frames, to: outURL, options: .init(fps: fps, quality: opts.quality, maxWidth: opts.maxWidth)) { _ in }
                    } else { try? GIFEncoder.encode(frames: frames, to: outURL, options: opts) { _ in } }
                case .mp4: try? await MP4Encoder.encode(frames: frames, to: outURL, quality: 80) { _ in }
                default: try? GIFEncoder.encode(frames: frames, to: outURL, options: opts) { _ in }
                }
                await MainActor.run { progress = Double(i + 1) / Double(filesToConvert.count); completed = i + 1 }
            }
            await MainActor.run {
                isConverting = false; status = "완료 ✓ (\(filesToConvert.count)개)"
                NSWorkspace.shared.open(dir)
            }
        }
    }
}
