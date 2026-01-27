import SwiftUI
import Charts

// MARK: - Health App Style Effects
/// 参考画像3枚目のようなヘルスアプリ風のグラフアニメーション

struct HealthAppMetricCard: View {
    @ObservedObject private var theme = ThemeManager.shared
    
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let progress: Double
    
    @State private var animatedProgress: Double = 0
    @State private var scale: CGFloat = 0.95
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Spacer()
                
                // プログレスリング
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(theme.primaryText)
                
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
            }
            
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Animated Line Chart

struct AnimatedLineChart: View {
    @ObservedObject private var theme = ThemeManager.shared
    
    let data: [ChartDataPoint]
    let color: Color
    let showGradient: Bool
    
    @State private var animationProgress: CGFloat = 0
    
    init(data: [ChartDataPoint], color: Color, showGradient: Bool = true) {
        self.data = data
        self.color = color
        self.showGradient = showGradient
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // グラデーション背景
                if showGradient {
                    AnimatedChartGradient(
                        data: data,
                        color: color,
                        progress: animationProgress
                    )
                }
                
                // ライン
                AnimatedChartLine(
                    data: data,
                    color: color,
                    progress: animationProgress
                )
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // データポイント
                ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                    if CGFloat(index) / CGFloat(data.count) <= animationProgress {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .position(
                                x: geometry.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1)),
                                y: geometry.size.height * (1 - point.normalizedValue)
                            )
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animationProgress = 1.0
            }
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let value: Double
    let normalizedValue: Double
    let label: String?
    
    init(value: Double, normalizedValue: Double, label: String? = nil) {
        self.value = value
        self.normalizedValue = normalizedValue
        self.label = label
    }
}

// MARK: - Animated Chart Line

struct AnimatedChartLine: Shape {
    let data: [ChartDataPoint]
    let color: Color
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        guard data.count > 1 else { return Path() }
        
        var path = Path()
        let stepX = rect.width / CGFloat(max(data.count - 1, 1))
        
        let visibleCount = Int(CGFloat(data.count) * progress)
        guard visibleCount > 0 else { return Path() }
        
        let firstPoint = data[0]
        path.move(to: CGPoint(
            x: 0,
            y: rect.height * (1 - firstPoint.normalizedValue)
        ))
        
        for i in 1..<min(visibleCount, data.count) {
            let point = data[i]
            path.addLine(to: CGPoint(
                x: stepX * CGFloat(i),
                y: rect.height * (1 - point.normalizedValue)
            ))
        }
        
        return path
    }
}

// MARK: - Animated Chart Gradient

struct AnimatedChartGradient: View {
    let data: [ChartDataPoint]
    let color: Color
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }
                
                let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))
                let visibleCount = Int(CGFloat(data.count) * progress)
                guard visibleCount > 0 else { return }
                
                path.move(to: CGPoint(x: 0, y: geometry.size.height))
                path.addLine(to: CGPoint(
                    x: 0,
                    y: geometry.size.height * (1 - data[0].normalizedValue)
                ))
                
                for i in 1..<min(visibleCount, data.count) {
                    let point = data[i]
                    path.addLine(to: CGPoint(
                        x: stepX * CGFloat(i),
                        y: geometry.size.height * (1 - point.normalizedValue)
                    ))
                }
                
                path.addLine(to: CGPoint(
                    x: stepX * CGFloat(min(visibleCount - 1, data.count - 1)),
                    y: geometry.size.height
                ))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(0.3),
                        color.opacity(0.1),
                        color.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Activity Ring

struct ActivityRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    init(progress: Double, color: Color, lineWidth: CGFloat = 12) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            // 背景リング
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            // プログレスリング
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            
            // グロー効果
            Circle()
                .trim(from: max(0, animatedProgress - 0.05), to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth + 4,
                        lineCap: .round
                    )
                )
                .blur(radius: 4)
                .rotationEffect(.degrees(-90))
                .opacity(0.6)
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Streak Indicator

struct StreakIndicator: View {
    @ObservedObject private var theme = ThemeManager.shared
    
    let days: Int
    let color: Color
    
    @State private var scale: CGFloat = 0.8
    @State private var rotation: Double = -10
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .rotationEffect(.degrees(rotation))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(days)日")
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundStyle(theme.primaryText)
                
                Text("連続")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1.0
                rotation = 0
            }
        }
    }
}

// MARK: - Progress Bar with Animation

struct AnimatedProgressBar: View {
    let progress: Double
    let color: Color
    let height: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    init(progress: Double, color: Color, height: CGFloat = 8) {
        self.progress = progress
        self.color = color
        self.height = height
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(color.opacity(0.2))
                
                // プログレス
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * animatedProgress)
                
                // グロー
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(color)
                    .frame(width: geometry.size.width * animatedProgress)
                    .blur(radius: 4)
                    .opacity(0.5)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animatedProgress = progress
            }
        }
    }
}
