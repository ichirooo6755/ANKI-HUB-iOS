import SwiftUI

// MARK: - Visual Effect Modifiers
/// テーマとビジュアルエフェクトを統合するモディファイア

struct AdaptiveVisualEffectModifier: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var effects = VisualEffectsManager.shared
    
    let enableOverlay: Bool
    
    func body(content: Content) -> some View {
        let style = effects.getStyleForTheme(theme.selectedThemeId)
        
        ZStack {
            content
            
            if effects.effectsEnabled && enableOverlay {
                switch style {
                case .cyberpunk:
                    if effects.gridOverlayEnabled {
                        CyberpunkGridOverlay(intensity: effects.animationIntensity)
                    }
                    
                case .cardStack, .healthApp, .minimal, .adaptive:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Enhanced Card Modifier

struct EnhancedCardModifier: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var effects = VisualEffectsManager.shared
    
    let accentColor: Color?
    
    func body(content: Content) -> some View {
        let style = effects.getStyleForTheme(theme.selectedThemeId)
        let accent = accentColor ?? theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        
        Group {
            if effects.effectsEnabled {
                switch style {
                case .cyberpunk:
                    content.cyberpunkCard()
                    
                case .cardStack:
                    content.colorfulCard(color: accent, animated: true)
                    
                case .healthApp, .minimal, .adaptive:
                    content.liquidGlass()
                }
            } else {
                content.liquidGlass()
            }
        }
    }
}

// MARK: - Celebration Effect

struct CelebrationEffect: View {
    @State private var isAnimating = false
    @State private var particles: [CelebrationParticle] = []
    
    let type: CelebrationType
    let color: Color
    
    init(type: CelebrationType = .confetti, color: Color = .yellow) {
        self.type = type
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ParticleView(particle: particle, isAnimating: isAnimating)
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
                withAnimation(.easeOut(duration: 2.0)) {
                    isAnimating = true
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func generateParticles(in size: CGSize) {
        let count = type == .confetti ? 50 : 30
        particles = (0..<count).map { _ in
            CelebrationParticle(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                color: randomColor(),
                size: CGFloat.random(in: 4...12),
                rotation: Double.random(in: 0...360),
                velocity: CGFloat.random(in: 100...300)
            )
        }
    }
    
    private func randomColor() -> Color {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        return colors.randomElement() ?? color
    }
}

struct CelebrationParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let velocity: CGFloat
}

struct ParticleView: View {
    let particle: CelebrationParticle
    let isAnimating: Bool
    
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .opacity(opacity)
            .position(x: particle.x, y: particle.y)
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    withAnimation(.easeOut(duration: 2.0)) {
                        offset = CGSize(
                            width: CGFloat.random(in: -100...100),
                            height: particle.velocity
                        )
                        opacity = 0
                        rotation = particle.rotation + Double.random(in: 360...720)
                    }
                }
            }
    }
}

enum CelebrationType {
    case confetti
    case sparkles
    case fireworks
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    let duration: Double
    let bounce: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.3),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: geometry.size.width * phase - geometry.size.width * 0.3)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: bounce)
                ) {
                    phase = 1.3
                }
            }
    }
}

// MARK: - Pulse Effect

struct PulseEffect: ViewModifier {
    @State private var scale: CGFloat = 1.0
    
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = maxScale
                }
            }
    }
}

// MARK: - Glow Effect

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.4), radius: radius * 1.5, x: 0, y: 0)
            .shadow(color: color.opacity(0.2), radius: radius * 2, x: 0, y: 0)
    }
}

// MARK: - View Extensions

extension View {
    func adaptiveVisualEffect(enableOverlay: Bool = true) -> some View {
        self.modifier(AdaptiveVisualEffectModifier(enableOverlay: enableOverlay))
    }
    
    func enhancedCard(accentColor: Color? = nil) -> some View {
        self.modifier(EnhancedCardModifier(accentColor: accentColor))
    }
    
    func shimmer(duration: Double = 2.0, bounce: Bool = false) -> some View {
        self.modifier(ShimmerEffect(duration: duration, bounce: bounce))
    }
    
    func pulse(minScale: CGFloat = 1.0, maxScale: CGFloat = 1.05, duration: Double = 1.0) -> some View {
        self.modifier(PulseEffect(minScale: minScale, maxScale: maxScale, duration: duration))
    }
    
    func glow(color: Color, radius: CGFloat = 10) -> some View {
        self.modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: - Button Styles

struct CyberpunkButtonStyle: ButtonStyle {
    @ObservedObject private var theme = ThemeManager.shared
    
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    color,
                                    color.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }
            )
            .foregroundStyle(color)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .glow(color: color, radius: configuration.isPressed ? 15 : 8)
    }
}

struct HealthAppButtonStyle: ButtonStyle {
    @ObservedObject private var theme = ThemeManager.shared
    
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 4 : 8, x: 0, y: 4)
    }
}

extension ButtonStyle where Self == CyberpunkButtonStyle {
    static func cyberpunk(color: Color = .cyan) -> CyberpunkButtonStyle {
        CyberpunkButtonStyle(color: color)
    }
}

extension ButtonStyle where Self == HealthAppButtonStyle {
    static func healthApp(color: Color = .blue) -> HealthAppButtonStyle {
        HealthAppButtonStyle(color: color)
    }
}
