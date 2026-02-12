import SwiftUI

// MARK: - JochungCam Design System
enum HCTheme {
    // Colors
    static let accent = Color(hex: "FFD60A")       // Honey yellow
    static let accentDim = Color(hex: "FFD60A").opacity(0.15)
    static let bg = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceHover = Color.white.opacity(0.05)
    static let border = Color.white.opacity(0.08)
    static let borderActive = Color(hex: "FFD60A").opacity(0.4)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.5)
    static let danger = Color(hex: "FF453A")
    static let success = Color(hex: "30D158")
    static let recording = Color(hex: "FF453A")

    // Spacing
    static let pad: CGFloat = 12
    static let padSm: CGFloat = 6
    static let padLg: CGFloat = 16
    static let radius: CGFloat = 8
    static let radiusSm: CGFloat = 5

    // Fonts
    static let title = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 12)
    static let caption = Font.system(size: 11)
    static let captionMono = Font.system(size: 11, design: .monospaced)
    static let micro = Font.system(size: 9)
    static let microMono = Font.system(size: 9, design: .monospaced)
    static let display = Font.system(size: 48, weight: .ultraLight, design: .monospaced)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

// MARK: - Reusable Components

struct HCCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(HCTheme.pad)
            .background(RoundedRectangle(cornerRadius: HCTheme.radius).fill(HCTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: HCTheme.radius).stroke(HCTheme.border))
    }
}

struct HCSection<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: HCTheme.padSm) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(HCTheme.textTertiary)
                .textCase(.uppercase).tracking(0.5)
            content
        }
    }
}

struct HCPillButton: View {
    let label: String
    let icon: String?
    let isActive: Bool
    let action: () -> Void

    init(_ label: String, icon: String? = nil, isActive: Bool = false, action: @escaping () -> Void) {
        self.label = label; self.icon = icon; self.isActive = isActive; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let icon { Image(systemName: icon).font(.system(size: 9)) }
                Text(label)
            }
            .font(.system(size: 10, weight: isActive ? .semibold : .regular))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(isActive ? HCTheme.accent.opacity(0.2) : Color.clear)
            .foregroundColor(isActive ? HCTheme.accent : HCTheme.textSecondary)
            .overlay(Capsule().stroke(isActive ? HCTheme.accent.opacity(0.5) : HCTheme.border))
            .clipShape(Capsule())
        }.buttonStyle(.plain)
    }
}

struct HCIconButton: View {
    let icon: String
    let help: String
    let danger: Bool
    let action: () -> Void

    init(_ icon: String, help: String = "", danger: Bool = false, action: @escaping () -> Void) {
        self.icon = icon; self.help = help; self.danger = danger; self.action = action
    }

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11))
                .frame(width: 26, height: 26)
                .background(isHovered ? (danger ? HCTheme.danger.opacity(0.15) : HCTheme.surfaceHover) : Color.clear)
                .foregroundColor(danger ? HCTheme.danger : HCTheme.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: HCTheme.radiusSm))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

struct HCStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value).font(HCTheme.captionMono).foregroundColor(HCTheme.textPrimary)
            Text(label).font(HCTheme.micro).foregroundColor(HCTheme.textTertiary)
        }
    }
}

struct HCTag: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = HCTheme.accent) {
        self.text = text; self.color = color
    }

    var body: some View {
        Text(text).font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - Pulsing record indicator
struct PulsingDot: View {
    @State private var pulse = false
    let color: Color

    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .scaleEffect(pulse ? 1.3 : 1.0)
            .opacity(pulse ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}
