import SwiftUI

// 🎭 리리의 아름다운 애니메이션 시스템

struct AnimationSystem {
    
    // MARK: - 부드러운 트랜지션들
    
    static let smoothEaseInOut = Animation.easeInOut(duration: 0.3)
    static let quickResponse = Animation.easeOut(duration: 0.15)
    static let slowElegant = Animation.easeInOut(duration: 0.6)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.7)
    
    // MARK: - 속도 조절 애니메이션들
    
    static func speedChangeAnimation() -> Animation {
        .spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)
    }
    
    static func undoRedoAnimation() -> Animation {
        .easeInOut(duration: 0.25)
    }
    
    static func previewAnimation() -> Animation {
        .linear(duration: 0.1)
    }
    
    // MARK: - UI 상태 애니메이션들
    
    static func buttonPress() -> Animation {
        .spring(response: 0.3, dampingFraction: 0.6)
    }
    
    static func sheetPresent() -> Animation {
        .easeOut(duration: 0.4)
    }
    
    static func progressUpdate() -> Animation {
        .linear(duration: 0.2)
    }
    
    // MARK: - 고급 효과들
    
    static func pulseEffect(duration: Double = 1.0) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
    
    static func shimmerEffect() -> Animation {
        .linear(duration: 1.2).repeatForever(autoreverses: false)
    }
    
    static func breatheEffect() -> Animation {
        .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }
}

// MARK: - 커스텀 애니메이션 모디파이어들

struct PulseEffect: ViewModifier {
    @State private var isAnimating = false
    let color: Color
    let intensity: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.0 + intensity : 1.0)
            .opacity(isAnimating ? 0.8 : 1.0)
            .animation(AnimationSystem.pulseEffect(), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.4),
                        Color.white.opacity(0)
                    ],
                    startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
                )
                .mask(content)
            )
            .onAppear {
                withAnimation(AnimationSystem.shimmerEffect()) {
                    phase = 1.3
                }
            }
    }
}

struct ButtonPressEffect: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .brightness(isPressed ? -0.1 : 0)
            .animation(AnimationSystem.buttonPress(), value: isPressed)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: 50,
                pressing: { pressing in
                    isPressed = pressing
                },
                perform: {}
            )
    }
}

// MARK: - View Extensions

extension View {
    func pulse(color: Color = .blue, intensity: Double = 0.1) -> some View {
        modifier(PulseEffect(color: color, intensity: intensity))
    }
    
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
    
    func buttonPressEffect() -> some View {
        modifier(ButtonPressEffect())
    }
    
    func smoothScale(isActive: Bool, scale: CGFloat = 1.1) -> some View {
        self.scaleEffect(isActive ? scale : 1.0)
            .animation(AnimationSystem.smoothEaseInOut, value: isActive)
    }
    
    func smoothOpacity(isVisible: Bool) -> some View {
        self.opacity(isVisible ? 1.0 : 0.0)
            .animation(AnimationSystem.smoothEaseInOut, value: isVisible)
    }
    
    func slideInFromRight(isVisible: Bool) -> some View {
        self.offset(x: isVisible ? 0 : 100)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(AnimationSystem.smoothEaseInOut, value: isVisible)
    }
    
    func slideInFromLeft(isVisible: Bool) -> some View {
        self.offset(x: isVisible ? 0 : -100)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(AnimationSystem.smoothEaseInOut, value: isVisible)
    }
    
    func fadeInUp(isVisible: Bool) -> some View {
        self.offset(y: isVisible ? 0 : 20)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(AnimationSystem.smoothEaseInOut, value: isVisible)
    }
}

// MARK: - 프로그래스 애니메이션

struct AnimatedProgressBar: View {
    let progress: Double
    let height: CGFloat
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(
        progress: Double,
        height: CGFloat = 8,
        cornerRadius: CGFloat = 4,
        backgroundColor: Color = Color(NSColor.systemGray),
        foregroundColor: Color = .blue
    ) {
        self.progress = progress
        self.height = height
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 배경
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                
                // 진행 표시
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(foregroundColor)
                    .frame(width: geometry.size.width * progress)
                    .animation(AnimationSystem.progressUpdate(), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 로딩 인디케이터

struct BreathingDot: View {
    @State private var isBreathing = false
    let color: Color
    let size: CGFloat
    
    init(color: Color = .blue, size: CGFloat = 10) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isBreathing ? 1.3 : 1.0)
            .opacity(isBreathing ? 0.6 : 1.0)
            .animation(AnimationSystem.breatheEffect(), value: isBreathing)
            .onAppear {
                isBreathing = true
            }
    }
}

struct PulsingOrb: View {
    @State private var isPulsing = false
    let colors: [Color]
    let size: CGFloat
    
    init(colors: [Color] = [.blue, .purple], size: CGFloat = 60) {
        self.colors = colors
        self.size = size
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: colors + [colors.first!.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size/2
                        )
                    )
                    .frame(width: size, height: size)
                    .scaleEffect(isPulsing ? 1.2 : 0.8)
                    .opacity(isPulsing ? 0.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 1.5 + Double(index) * 0.2)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.3),
                        value: isPulsing
                    )
            }
        }
        .onAppear {
            isPulsing = true
        }
    }
}