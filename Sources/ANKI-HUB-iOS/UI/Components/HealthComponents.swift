import SwiftUI

struct HealthRingView: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 10
    var size: CGFloat = 88

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        Gauge(value: clamped) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.accessoryCircular)
        .tint(color)
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("進捗"))
        .accessibilityValue(Text("\(Int(clamped * 100))%"))
    }
}

struct HealthMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let progress: Double?
    let changeRate: Double?

    @ObservedObject private var theme = ThemeManager.shared

    init(
        title: String,
        value: String,
        unit: String,
        icon: String,
        color: Color,
        progress: Double? = nil,
        changeRate: Double? = nil
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.icon = icon
        self.color = color
        self.progress = progress
        self.changeRate = changeRate
    }

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
                        .minimumScaleFactor(0.58)
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

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let trailing: String?

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            Spacer()
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }
}

struct PillBadge: View {
    let title: String
    let color: Color

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let useMaterial = theme.useLiquidGlass && theme.colorSchemeOverride == 0
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.onColor(for: color))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Group {
                    if useMaterial {
                        Capsule().fill(.thinMaterial)
                    }
                }
            )
            .background(color.opacity(useMaterial ? 0.6 : 1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(useMaterial ? 0.25 : 0), lineWidth: 1)
            )
    }
}
