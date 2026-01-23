import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var unit: String = ""
    let icon: String
    let color: Color
    var progress: Double? = nil
    var changeRate: Double? = nil

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let shadow = Color.black.opacity(theme.effectiveIsDark ? 0.28 : 0.06)
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        let style = theme.widgetCardStyle
        let fill: AnyShapeStyle = {
            switch style {
            case "neo":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [surface.opacity(theme.effectiveIsDark ? 0.86 : 0.98), color.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case "outline":
                return AnyShapeStyle(surface.opacity(0.001))
            default:
                return AnyShapeStyle(surface.opacity(theme.effectiveIsDark ? 0.92 : 0.98))
            }
        }()
        let stroke: Color = {
            switch style {
            case "neo":
                return color.opacity(0.22)
            case "outline":
                return color.opacity(0.32)
            default:
                return color.opacity(0.14)
            }
        }()
        let shadowRadius: CGFloat = {
            switch style {
            case "outline":
                return 0
            case "neo":
                return 10
            default:
                return 8
            }
        }()
        let shadowColor: Color = {
            switch style {
            case "neo":
                return color.opacity(theme.effectiveIsDark ? 0.18 : 0.10)
            case "outline":
                return .clear
            default:
                return shadow
            }
        }()

        return ZStack(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.system(size: 96, weight: .bold, design: .default))
                .foregroundStyle(color.opacity(theme.effectiveIsDark ? (style == "neo" ? 0.22 : 0.18) : (style == "neo" ? 0.18 : 0.14)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .offset(x: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondaryText.opacity(0.62))

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 48, weight: .black, design: .default))
                        .monospacedDigit()
                        .tracking(-1)
                        .foregroundStyle(theme.primaryText)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.secondaryText.opacity(0.62))
                    }
                }

                if let progress {
                    let clamped = min(max(progress, 0), 1)
                    ProgressView(value: clamped)
                        .tint(color)
                        .frame(height: 4)
                        .opacity(0.95)
                        .accessibilityValue(Text("\(Int(clamped * 100))%"))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(cardShape.fill(fill))
        .overlay(cardShape.stroke(stroke, lineWidth: 1))
        .clipShape(cardShape)
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 4)
    }
}

struct DashboardHeroHeader: View {
    let title: String
    let subtitle: String
    let caption: String
    let detail: String
    let icon: String
    let accent: Color
    let secondary: Color

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var baseHeight: CGFloat = 230

    var body: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .named("scroll")).minY
            let height = reduceMotion ? baseHeight : baseHeight + max(minY, 0)
            let scale = reduceMotion ? 1 : min(1.06, max(0.96, 1 + minY / 600))
            let opacity = reduceMotion ? 1 : min(1, max(0.7, 1 + minY / 300))
            let blur: CGFloat = 0
            let yOffset = reduceMotion ? 0 : (minY < 0 ? minY * 0.25 : 0)
            let gradient = LinearGradient(
                colors: [accent.opacity(0.95), secondary.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            let textColor = theme.onColor(for: accent)
            let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

            ZStack(alignment: .bottomLeading) {
                cardShape
                    .fill(gradient)
                cardShape
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)

                Image(systemName: icon)
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 12)
                    .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(textColor)

                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(textColor.opacity(0.9))

                    HStack(spacing: 8) {
                        Text(caption)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(textColor.opacity(0.85))
                        Text(detail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(textColor.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(textColor.opacity(0.15), in: Capsule())
                    }
                }
                .padding(20)
            }
            .frame(height: height)
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: blur)
            .offset(y: yOffset)
            .clipShape(cardShape)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(subtitle))
        }
        .frame(height: baseHeight)
    }
}

struct HeroCarouselItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
}

struct HeroCarouselView: View {
    let items: [HeroCarouselItem]

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let reduceMotionEnabled = reduceMotion
        GeometryReader { proxy in
            let cardWidth = proxy.size.width * 0.78
            let cardHeight = proxy.size.height * 0.92
            let sidePadding = max((proxy.size.width - cardWidth) / 2, 0)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        Button(action: item.action) {
                            HeroCarouselCard(item: item)
                                .frame(width: cardWidth, height: cardHeight)
                        }
                        .buttonStyle(.plain)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(reduceMotionEnabled ? 1 : (phase.isIdentity ? 1 : 0.9))
                                .opacity(reduceMotionEnabled ? 1 : (phase.isIdentity ? 1 : 0.6))
                                .rotation3DEffect(
                                    reduceMotionEnabled ? .degrees(0) : .degrees(phase.isIdentity ? 0 : 6),
                                    axis: (x: 0, y: 1, z: 0)
                                )
                        }
                    }
                }
                .padding(.horizontal, sidePadding)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

private struct HeroCarouselCard: View {
    let item: HeroCarouselItem

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let gradient = LinearGradient(
            colors: item.gradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let textColor = theme.onColor(for: item.gradient.first ?? .blue)
        let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return ZStack(alignment: .topLeading) {
            cardShape
                .fill(gradient)
            cardShape
                .stroke(Color.white.opacity(0.14), lineWidth: 1)

            Image(systemName: item.icon)
                .font(.system(size: 120, weight: .bold, design: .default))
                .foregroundStyle(textColor.opacity(0.18))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 12)
                .padding(.trailing, 12)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(item.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(textColor)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.footnote)
                        .foregroundStyle(textColor.opacity(0.82))
                        .lineLimit(2)
                }

                Spacer()

                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(textColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(textColor.opacity(0.15), in: Capsule())
                }
            }
            .padding(16)
        }
        .clipShape(cardShape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(Text(item.detail))
    }
}

struct SubjectCard: View {
    let subject: Subject

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let isDark = theme.effectiveIsDark
        let surface = theme.currentPalette.color(.surface, isDark: isDark)
        let accent = subject.color
        let shadow = Color.black.opacity(isDark ? 0.32 : 0.08)
        let textColor = theme.primaryText
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let style = theme.widgetCardStyle
        let fill: AnyShapeStyle = {
            switch style {
            case "neo":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [surface.opacity(isDark ? 0.88 : 0.98), accent.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case "outline":
                return AnyShapeStyle(surface.opacity(0.001))
            default:
                return AnyShapeStyle(surface.opacity(isDark ? 0.93 : 0.98))
            }
        }()
        let stroke: Color = {
            switch style {
            case "neo":
                return accent.opacity(0.22)
            case "outline":
                return accent.opacity(0.32)
            default:
                return accent.opacity(0.14)
            }
        }()
        let shadowRadius: CGFloat = {
            switch style {
            case "outline":
                return 0
            case "neo":
                return 10
            default:
                return 8
            }
        }()
        let shadowColor: Color = {
            switch style {
            case "neo":
                return accent.opacity(isDark ? 0.16 : 0.10)
            case "outline":
                return .clear
            default:
                return shadow
            }
        }()

        return ZStack(alignment: .topTrailing) {
            Image(systemName: subject.icon)
                .font(.system(size: 96, weight: .bold, design: .default))
                .foregroundStyle(accent.opacity(isDark ? (style == "neo" ? 0.22 : 0.18) : (style == "neo" ? 0.18 : 0.14)))
                .padding(.top, 10)
                .padding(.trailing, 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(subject.displayName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(textColor)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 150)
        .background(cardShape.fill(fill))
        .overlay(cardShape.stroke(stroke, lineWidth: 1))
        .clipShape(cardShape)
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 4)
    }
}

struct ToolCard: View {
    let title: String
    let icon: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let isDark = theme.effectiveIsDark
        let surface = theme.currentPalette.color(.surface, isDark: isDark)
        let textColor = theme.primaryText
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let style = theme.widgetCardStyle

        let fill: AnyShapeStyle = {
            switch style {
            case "neo":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [surface.opacity(isDark ? 0.86 : 0.98), color.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case "outline":
                return AnyShapeStyle(surface.opacity(0.001))
            default:
                return AnyShapeStyle(surface.opacity(isDark ? 0.92 : 0.98))
            }
        }()

        let stroke: Color = {
            switch style {
            case "neo":
                return color.opacity(0.22)
            case "outline":
                return color.opacity(0.32)
            default:
                return color.opacity(0.14)
            }
        }()

        let shadowRadius: CGFloat = {
            switch style {
            case "outline":
                return 0
            default:
                return 6
            }
        }()
        let shadowColor: Color = {
            switch style {
            case "outline":
                return .clear
            default:
                return Color.black.opacity(isDark ? 0.20 : 0.05)
            }
        }()

        return ZStack(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.system(size: 96, weight: .bold, design: .default))
                .foregroundStyle(color.opacity(isDark ? (style == "neo" ? 0.20 : 0.16) : (style == "neo" ? 0.16 : 0.12)))
                .padding(.top, 10)
                .padding(.trailing, 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(textColor)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText.opacity(0.45))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .background(cardShape.fill(fill))
        .overlay(cardShape.stroke(stroke, lineWidth: 1))
        .clipShape(cardShape)
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 4)
    }
}

struct GoalCountdownCard: View {
    let daysRemaining: Int
    let targetDate: Date
    let progress: Double
    let progressText: String

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let accent = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let surface = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
        let shadow = Color.black.opacity(theme.effectiveIsDark ? 0.24 : 0.06)
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("目標まで")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(theme.secondaryText.opacity(0.62))
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(max(0, daysRemaining))")
                            .font(.system(size: 48, weight: .black, design: .default))
                            .monospacedDigit()
                            .tracking(-1)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .foregroundStyle(theme.primaryText)
                        Text("日")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.secondaryText.opacity(0.62))
                    }
                    Text("目標日 \(dateString(targetDate))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(theme.secondaryText.opacity(0.62))
                }
                Spacer()
                CircularProgressView(
                    progress: progress,
                    color: accent,
                    lineWidth: 8,
                    accessibilityLabel: "目標達成率"
                )
                    .frame(width: 64, height: 64)
            }

            HStack {
                Text("学習時間")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondaryText.opacity(0.62))
                Spacer()
                Text(progressText)
                    .font(.callout.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.primaryText)
            }
        }
        .padding(16)
        .background(cardShape.fill(surface.opacity(theme.effectiveIsDark ? 0.9 : 0.98)))
        .overlay(cardShape.stroke(accent.opacity(0.2), lineWidth: 1))
        .clipShape(cardShape)
        .shadow(color: shadow, radius: 6, x: 0, y: 3)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
