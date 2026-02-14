import SwiftUI

// 🎨 리리의 아름다운 테마 시스템

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    case midnight = "midnight"
    case purple = "purple"
    case green = "green"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "시스템"
        case .light: return "라이트"
        case .dark: return "다크"
        case .midnight: return "미드나이트"
        case .purple: return "퍼플"
        case .green: return "그린"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gearshape"
        case .light: return "sun.max"
        case .dark: return "moon"
        case .midnight: return "moon.stars"
        case .purple: return "sparkles"
        case .green: return "leaf"
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .system
    @Published var customAccentColor: Color = .blue
    
    init() {
        // UserDefaults에서 테마 로드
        if let savedTheme = UserDefaults.standard.object(forKey: "AppTheme") as? String,
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
        
        // 커스텀 액센트 컬러 로드
        if let colorData = UserDefaults.standard.data(forKey: "CustomAccentColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            customAccentColor = Color(color)
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        withAnimation(AnimationSystem.smoothEaseInOut) {
            currentTheme = theme
        }
        UserDefaults.standard.set(theme.rawValue, forKey: "AppTheme")
    }
    
    func setAccentColor(_ color: Color) {
        withAnimation(AnimationSystem.smoothEaseInOut) {
            customAccentColor = color
        }
        
        // NSColor로 변환해서 저장
        let nsColor = NSColor(color)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: "CustomAccentColor")
        }
    }
    
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system: return nil
        case .light, .green: return .light
        case .dark, .midnight, .purple: return .dark
        }
    }
}

// MARK: - 테마별 컬러 팔레트

extension AppTheme {
    
    var colors: ThemeColors {
        switch self {
        case .system, .light:
            return ThemeColors(
                primary: .blue,
                secondary: .gray,
                accent: .blue,
                background: .white,
                surface: Color(NSColor.controlBackgroundColor),
                onSurface: .black,
                success: .green,
                warning: .orange,
                error: .red,
                info: .blue
            )
            
        case .dark:
            return ThemeColors(
                primary: .blue,
                secondary: .gray,
                accent: .blue,
                background: Color(NSColor.controlBackgroundColor).opacity(0.3),
                surface: Color(NSColor.unemphasizedSelectedContentBackgroundColor),
                onSurface: .white,
                success: .green,
                warning: .orange,
                error: .red,
                info: .blue
            )
            
        case .midnight:
            return ThemeColors(
                primary: .indigo,
                secondary: .gray,
                accent: .indigo,
                background: Color(.black).opacity(0.9),
                surface: Color(NSColor.controlBackgroundColor).opacity(0.1),
                onSurface: .white,
                success: .mint,
                warning: .yellow,
                error: .pink,
                info: .cyan
            )
            
        case .purple:
            return ThemeColors(
                primary: .purple,
                secondary: .gray,
                accent: .purple,
                background: Color.purple.opacity(0.05),
                surface: Color.purple.opacity(0.1),
                onSurface: Color.primary,
                success: .green,
                warning: .orange,
                error: .red,
                info: .purple
            )
            
        case .green:
            return ThemeColors(
                primary: .green,
                secondary: .gray,
                accent: .green,
                background: Color.green.opacity(0.05),
                surface: Color.green.opacity(0.1),
                onSurface: Color.primary,
                success: .green,
                warning: .orange,
                error: .red,
                info: .green
            )
        }
    }
}

struct ThemeColors {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
    let onSurface: Color
    let success: Color
    let warning: Color
    let error: Color
    let info: Color
}

// MARK: - 환경 객체

struct ThemeEnvironment {
    let theme: AppTheme
    let colors: ThemeColors
    let manager: ThemeManager
}

// MARK: - Environment Key

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeEnvironment(
        theme: .system,
        colors: AppTheme.system.colors,
        manager: ThemeManager()
    )
}

extension EnvironmentValues {
    var theme: ThemeEnvironment {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - 테마 적용 모디파이어

struct ThemedBackground: ViewModifier {
    @Environment(\.theme) var theme
    
    func body(content: Content) -> some View {
        content
            .background(theme.colors.background)
            .foregroundColor(theme.colors.onSurface)
    }
}

struct ThemedSurface: ViewModifier {
    @Environment(\.theme) var theme
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(theme.colors.surface)
            )
            .foregroundColor(theme.colors.onSurface)
    }
}

struct ThemedButton: ViewModifier {
    @Environment(\.theme) var theme
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary, secondary, accent, success, warning, error
        
        func color(from colors: ThemeColors) -> Color {
            switch self {
            case .primary: return colors.primary
            case .secondary: return colors.secondary
            case .accent: return colors.accent
            case .success: return colors.success
            case .warning: return colors.warning
            case .error: return colors.error
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .background(style.color(from: theme.colors))
            .cornerRadius(8)
            .buttonPressEffect()
    }
}

// MARK: - View Extensions

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }
    
    func themedSurface(cornerRadius: CGFloat = 8) -> some View {
        modifier(ThemedSurface(cornerRadius: cornerRadius))
    }
    
    func themedButton(_ style: ThemedButton.ButtonStyle = .primary) -> some View {
        modifier(ThemedButton(style: style))
    }
    
    func themeEnvironment(_ manager: ThemeManager) -> some View {
        self.environment(\.theme, ThemeEnvironment(
            theme: manager.currentTheme,
            colors: manager.currentTheme.colors,
            manager: manager
        ))
        .preferredColorScheme(manager.colorScheme)
    }
}

// MARK: - 테마 선택기 UI

struct ThemeSelector: View {
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.theme) var theme
    @State private var showingCustomColorPicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "paintbrush")
                    .foregroundColor(theme.colors.accent)
                Text("테마 선택")
                    .font(.headline)
                
                Spacer()
            }
            
            // 테마 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(AppTheme.allCases) { appTheme in
                    Button(action: {
                        themeManager.setTheme(appTheme)
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(appTheme.colors.accent)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: appTheme.icon)
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                            .overlay(
                                Circle()
                                    .stroke(
                                        themeManager.currentTheme == appTheme ? 
                                        theme.colors.accent : Color.clear,
                                        lineWidth: 3
                                    )
                                    .frame(width: 46, height: 46)
                            )
                            
                            Text(appTheme.displayName)
                                .font(.caption)
                                .foregroundColor(theme.colors.onSurface)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    themeManager.currentTheme == appTheme ?
                                    theme.colors.accent.opacity(0.1) :
                                    Color.clear
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            // 커스텀 액센트 컬러
            HStack {
                Image(systemName: "eyedropper")
                    .foregroundColor(theme.colors.accent)
                Text("액센트 컬러")
                    .font(.subheadline)
                
                Spacer()
                
                Button(action: {
                    showingCustomColorPicker = true
                }) {
                    Circle()
                        .fill(themeManager.customAccentColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .themedSurface(cornerRadius: 12)
        .sheet(isPresented: $showingCustomColorPicker) {
            ColorPicker("액센트 컬러 선택", selection: $themeManager.customAccentColor)
                .padding()
        }
    }
}