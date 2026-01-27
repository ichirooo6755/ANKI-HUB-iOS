import SwiftUI

// MARK: - Card Stack Effects
/// 参考画像2枚目のようなカラフルなカード重ねエフェクト

struct CardStackEffect: View {
    @ObservedObject private var theme = ThemeManager.shared
    let colors: [Color]
    let rotation: Double
    let offset: CGSize
    
    init(
        colors: [Color]? = nil,
        rotation: Double = 5,
        offset: CGSize = CGSize(width: 8, height: 8)
    ) {
        self.colors = colors ?? [
            Color(hex: "#B7FF1A"),  // Neon Lime
            Color(hex: "#FF6B6B"),  // Red
            Color(hex: "#4ECDC4"),  // Cyan
            Color(hex: "#FFD93D"),  // Yellow
            Color(hex: "#6C5CE7")   // Purple
        ]
        self.rotation = rotation
        self.offset = offset
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color,
                                    color.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .frame(
                            width: geometry.size.width - CGFloat(index) * 4,
                            height: geometry.size.height - CGFloat(index) * 4
                        )
                        .rotationEffect(.degrees(rotation * Double(index)))
                        .offset(
                            x: offset.width * CGFloat(index),
                            y: offset.height * CGFloat(index)
                        )
                        .zIndex(Double(colors.count - index))
                }
            }
        }
    }
}

// MARK: - Colorful Card Modifier

struct ColorfulCardModifier: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var hueRotation: Double = 0
    
    let baseColor: Color
    let animated: Bool
    
    init(baseColor: Color? = nil, animated: Bool = true) {
        self.baseColor = baseColor ?? Color(hex: "#B7FF1A")
        self.animated = animated
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // ベースグラデーション
                    LinearGradient(
                        colors: [
                            baseColor,
                            baseColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // 斜めストライプ
                    DiagonalStripes()
                        .fill(Color.white.opacity(0.1))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: baseColor.opacity(0.3), radius: 15, x: 0, y: 8)
            .hueRotation(.degrees(animated ? hueRotation : 0))
            .onAppear {
                if animated {
                    withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                        hueRotation = 360
                    }
                }
            }
    }
}

// MARK: - Diagonal Stripes

struct DiagonalStripes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let stripeWidth: CGFloat = 20
        let stripeSpacing: CGFloat = 40
        
        let diagonal = sqrt(rect.width * rect.width + rect.height * rect.height)
        let count = Int(diagonal / stripeSpacing) + 2
        
        for i in 0..<count {
            let offset = CGFloat(i) * stripeSpacing - diagonal / 2
            
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset + rect.height, y: rect.height))
            path.addLine(to: CGPoint(x: offset + rect.height + stripeWidth, y: rect.height))
            path.addLine(to: CGPoint(x: offset + stripeWidth, y: 0))
            path.closeSubpath()
        }
        
        return path
    }
}

// MARK: - Transport Card Style

struct TransportCardStyle: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared
    
    let cardColor: Color
    let accentColor: Color
    let title: String
    
    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            // カードベース
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cardColor, cardColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // アクセントバー
            Rectangle()
                .fill(accentColor)
                .frame(height: 8)
                .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                
                content
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: cardColor.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Suica-style Card

struct SuicaStyleCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .modifier(
                TransportCardStyle(
                    cardColor: Color(hex: "#00AC4E"),
                    accentColor: Color(hex: "#B7FF1A"),
                    title: "Suica"
                )
            )
    }
}

// MARK: - Metro Card Style

struct MetroCardStyle<Content: View>: View {
    let content: Content
    let cardType: MetroCardType
    
    init(type: MetroCardType = .metrocard, @ViewBuilder content: () -> Content) {
        self.cardType = type
        self.content = content()
    }
    
    var body: some View {
        content
            .modifier(
                TransportCardStyle(
                    cardColor: cardType.color,
                    accentColor: cardType.accentColor,
                    title: cardType.title
                )
            )
    }
}

enum MetroCardType {
    case metrocard  // NYC
    case oyster     // London
    case octopus    // Hong Kong
    case bilhete    // Portugal
    
    var color: Color {
        switch self {
        case .metrocard: return Color(hex: "#FFD700")
        case .oyster: return Color(hex: "#003087")
        case .octopus: return Color(hex: "#00A651")
        case .bilhete: return Color(hex: "#E30613")
        }
    }
    
    var accentColor: Color {
        switch self {
        case .metrocard: return Color(hex: "#000000")
        case .oyster: return Color(hex: "#0098D4")
        case .octopus: return Color(hex: "#FFD700")
        case .bilhete: return Color(hex: "#FFFFFF")
        }
    }
    
    var title: String {
        switch self {
        case .metrocard: return "metrocard"
        case .oyster: return "oyster"
        case .octopus: return "octopus"
        case .bilhete: return "Bilhete Único"
        }
    }
}

extension View {
    func colorfulCard(color: Color? = nil, animated: Bool = true) -> some View {
        self.modifier(ColorfulCardModifier(baseColor: color, animated: animated))
    }
}
