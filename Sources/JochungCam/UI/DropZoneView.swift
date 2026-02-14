import Foundation
import SwiftUI
import UniformTypeIdentifiers

// 📂 리리의 완벽한 드래그 앤 드롭 영역

struct DropZoneView: View {
    let title: String
    let subtitle: String
    let icon: String
    let supportedTypes: [UTType]
    let onFilesDropped: ([URL]) -> Void
    
    @State private var isTargeted = false
    @State private var isDraggedOver = false
    @Environment(\.theme) var theme
    
    var body: some View {
        ZStack {
            // 배경
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            borderColor,
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                )
            
            // 콘텐츠
            VStack(spacing: 12) {
                // 아이콘
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
                    .symbolEffect(.bounce, value: isDraggedOver)
                
                // 텍스트
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // 지원 형식 표시
                supportedTypesView
            }
            .padding()
        }
        .onDrop(of: supportedTypes, isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: isTargeted) { _, targeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isDraggedOver = targeted
            }
        }
        .scaleEffect(isDraggedOver ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggedOver)
    }
    
    // MARK: - 스타일 계산
    
    private var backgroundColor: Color {
        if isDraggedOver {
            return theme.colors.accent.opacity(0.1)
        } else {
            return theme.colors.surface.opacity(0.5)
        }
    }
    
    private var borderColor: Color {
        if isDraggedOver {
            return theme.colors.accent
        } else {
            return theme.colors.surface.opacity(0.8)
        }
    }
    
    private var iconColor: Color {
        if isDraggedOver {
            return theme.colors.accent
        } else {
            return theme.colors.secondary
        }
    }
    
    // MARK: - 지원 형식 뷰
    
    private var supportedTypesView: some View {
        HStack(spacing: 8) {
            ForEach(supportedTypeNames, id: \.self) { typeName in
                Text(typeName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var supportedTypeNames: [String] {
        supportedTypes.compactMap { type in
            switch type {
            case .movie:
                return "MOV"
            case .quickTimeMovie:
                return "MOV"
            case .mpeg4Movie:
                return "MP4"
            case .gif:
                return "GIF"
            case .png:
                return "PNG"
            case .jpeg:
                return "JPEG"
            default:
                return type.preferredFilenameExtension?.uppercased()
            }
        }.unique()
    }
    
    // MARK: - 드롭 처리
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let urlsLock = NSLock()
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    defer { group.leave() }
                    
                    guard let url, error == nil else { return }
                    
                    // 파일 타입 검증
                    if isFileSupported(url) {
                        urlsLock.lock()
                        urls.append(url)
                        urlsLock.unlock()
                    }
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                onFilesDropped(urls)
            }
        }
        
        return true
    }
    
    private func isFileSupported(_ url: URL) -> Bool {
        guard let resourceType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }
        
        return supportedTypes.contains { type in
            resourceType.conforms(to: type)
        }
    }
}

// MARK: - Array 확장 (중복 제거)

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - 미리보기 (간소화됨)