import SwiftUI

// MARK: - Cyberpunk Grid Overlay
/// 参考画像1枚目のようなグリッド + データポイント + 波形エフェクト

struct CyberpunkGridOverlay: View {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var animationPhase: CGFloat = 0
    @State private var dataPoints: [DataPoint] = []
    
    let intensity: Float
    
    init(intensity: Float = 1.0) {
        self.intensity = intensity
    }
    
    var body: some View {
        ZStack {
            // グリッドライン
            GridPattern()
                .stroke(
                    theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark).opacity(0.15),
                    lineWidth: 0.5
                )
            
            // データポイント
            ForEach(dataPoints) { point in
                DataPointView(point: point, phase: animationPhase)
            }
            
            // 波形エフェクト
            WaveEffect(phase: animationPhase, intensity: intensity)
                .stroke(
                    LinearGradient(
                        colors: [
                            .red.opacity(0.6),
                            .red.opacity(0.3),
                            .red.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
        }
        .allowsHitTesting(false)
        .onAppear {
            generateDataPoints()
            startAnimation()
        }
    }
    
    private func generateDataPoints() {
        dataPoints = (0..<8).map { i in
            DataPoint(
                id: UUID(),
                x: CGFloat.random(in: 0.1...0.9),
                y: CGFloat.random(in: 0.2...0.8),
                value: Int.random(in: 100...999),
                delay: Double(i) * 0.2
            )
        }
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            animationPhase = 1.0
        }
    }
}

// MARK: - Grid Pattern

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 40
        
        // 縦線
        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        
        // 横線
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        
        return path
    }
}

// MARK: - Data Point

struct DataPoint: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let value: Int
    let delay: Double
}

struct DataPointView: View {
    let point: DataPoint
    let phase: CGFloat
    
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 外側のリング
                Circle()
                    .stroke(Color.cyan.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                    .scaleEffect(scale)
                
                // 内側の点
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 8, height: 8)
                
                // 値のラベル
                Text("\(point.value)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .offset(y: -20)
            }
            .opacity(opacity)
            .position(
                x: geometry.size.width * point.x,
                y: geometry.size.height * point.y
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(point.delay)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // パルスアニメーション
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(point.delay)) {
                scale = 1.3
            }
        }
    }
}

// MARK: - Wave Effect

struct WaveEffect: Shape {
    var phase: CGFloat
    let intensity: Float
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height * 0.5
        let amplitude: CGFloat = 50 * CGFloat(intensity)
        let frequency: CGFloat = 0.02
        
        path.move(to: CGPoint(x: 0, y: midY))
        
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let sine = sin((relativeX + phase) * .pi * 2 * frequency * width)
            let y = midY + sine * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

// MARK: - Cyberpunk Card Modifier

struct CyberpunkCardModifier: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var glowIntensity: Double = 0.5
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .cyan.opacity(glowIntensity),
                                .red.opacity(glowIntensity * 0.5),
                                .cyan.opacity(glowIntensity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .cyan.opacity(glowIntensity * 0.3), radius: 10, x: 0, y: 0)
            .shadow(color: .red.opacity(glowIntensity * 0.2), radius: 15, x: 0, y: 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.8
                }
            }
    }
}

extension View {
    func cyberpunkCard() -> some View {
        self.modifier(CyberpunkCardModifier())
    }
}
