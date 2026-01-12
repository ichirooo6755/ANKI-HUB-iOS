import SwiftUI

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

// MARK: - Liquid Glass UI Extensions (Moved to top for visibility)
public struct LiquidGlassModifier: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared

    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 24) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let isDark = theme.effectiveIsDark
        let needsExtraContrast = theme.wallpaperKind == "photo" || theme.wallpaperKind == "bundle"
        let surface = theme.currentPalette.color(.surface, isDark: isDark)
        let border = theme.currentPalette.color(.border, isDark: isDark)
        let primary = theme.currentPalette.color(.primary, isDark: isDark)

        let useMaterial = needsExtraContrast
        let surfaceOpacity: Double = {
            if useMaterial {
                return isDark ? 0.55 : 0.32
            }
            return isDark ? 0.88 : 0.96
        }()

        let borderPrimaryOpacity: Double = {
            if useMaterial {
                return isDark ? 0.28 : 0.42
            }
            return isDark ? 0.14 : 0.25
        }()

        let borderSecondaryOpacity: Double = {
            if useMaterial {
                return isDark ? 0.5 : 0.7
            }
            return isDark ? 0.35 : 0.55
        }()

        Group {
            if useMaterial {
                content.background(.ultraThinMaterial)
            } else {
                content
            }
        }
        .background(surface.opacity(surfaceOpacity))
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            primary.opacity(borderPrimaryOpacity),
                            border.opacity(borderSecondaryOpacity),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(
                isDark ? (needsExtraContrast ? 0.34 : 0.28) : (needsExtraContrast ? 0.16 : 0.12)
            ),
            radius: needsExtraContrast ? 18 : 15,
            x: 0,
            y: 10
        )
    }
}

private struct AdaptiveLiquidGlassModifier: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared

    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 24) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        if theme.useLiquidGlass {
            return AnyView(content.modifier(LiquidGlassModifier(cornerRadius: cornerRadius)))
        }

        let isDark = theme.effectiveIsDark
        let needsExtraContrast = theme.wallpaperKind == "photo" || theme.wallpaperKind == "bundle"
        return AnyView(
            content
                .background(
                    theme.currentPalette.color(.surface, isDark: isDark)
                        .opacity(
                            isDark
                                ? (needsExtraContrast ? 0.92 : 0.85)
                                : (needsExtraContrast ? 0.98 : 0.95))
                )
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            theme.currentPalette.color(.border, isDark: isDark)
                                .opacity(
                                    isDark
                                        ? (needsExtraContrast ? 0.62 : 0.5)
                                        : (needsExtraContrast ? 0.8 : 0.7)),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(
                        isDark
                            ? (needsExtraContrast ? 0.26 : 0.22)
                            : (needsExtraContrast ? 0.1 : 0.08)
                    ),
                    radius: needsExtraContrast ? 12 : 10,
                    x: 0,
                    y: 6
                )
        )
    }
}

private struct LiquidGlassCircleModifier: ViewModifier {
    @ObservedObject private var theme = ThemeManager.shared

    func body(content: Content) -> some View {
        let isDark = theme.effectiveIsDark
        let needsExtraContrast = theme.wallpaperKind == "photo" || theme.wallpaperKind == "bundle"
        let surface = theme.currentPalette.color(.surface, isDark: isDark)
        let border = theme.currentPalette.color(.border, isDark: isDark)

        let useMaterial = theme.useLiquidGlass && needsExtraContrast
        let surfaceOpacity: Double = {
            if useMaterial {
                return isDark ? 0.55 : 0.32
            }
            return isDark ? 0.88 : 0.96
        }()

        let borderOpacity: Double = {
            if useMaterial {
                return isDark ? 0.5 : 0.7
            }
            return isDark ? 0.35 : 0.55
        }()

        return
            content
            .background(
                Group {
                    if useMaterial {
                        Circle().fill(.ultraThinMaterial)
                    }
                }
            )
            .background(Circle().fill(surface.opacity(surfaceOpacity)))
            .overlay(Circle().stroke(border.opacity(borderOpacity), lineWidth: 1))
            .shadow(
                color: Color.black.opacity(
                    isDark ? (needsExtraContrast ? 0.34 : 0.28) : (needsExtraContrast ? 0.16 : 0.12)
                ),
                radius: needsExtraContrast ? 18 : 15,
                x: 0,
                y: 10
            )
    }
}

extension View {
    /// iOS 26 style Liquid Glass effect
    /// Transparent background with blur, subtle border, and soft shadow.
    @ViewBuilder
    public func liquidGlass(cornerRadius: CGFloat = 24) -> some View {
        self.modifier(AdaptiveLiquidGlassModifier(cornerRadius: cornerRadius))
    }

    public func liquidGlassCircle() -> some View {
        self.modifier(LiquidGlassCircleModifier())
    }
}

// MARK: - Theme Models

struct ThemePalette: Codable, Equatable {
    var primary: String
    var secondary: String
    var accent: String
    var background: String
    var surface: String
    var text: String
    var border: String
    var selection: String

    // Status colors
    var mastered: String
    var almost: String
    var learning: String
    var weak: String
    var new: String

    // Dark mode overrides
    var primaryDark: String
    var backgroundDark: String
    var surfaceDark: String
    var textDark: String
    var borderDark: String
    var selectionDark: String

    // Computed Colors (SwiftUI)
    func color(_ key: ThemeColorKey, isDark: Bool) -> Color {
        let hex = hexString(for: key, isDark: isDark)
        return Color(hex: hex)
    }

    func hexString(for key: ThemeColorKey, isDark: Bool) -> String {
        if isDark {
            switch key {
            case .primary: return primaryDark
            case .background: return backgroundDark
            case .surface: return surfaceDark
            case .text: return textDark
            case .border: return borderDark
            case .selection: return selectionDark
            default: break
            }
        }

        switch key {
        case .primary: return primary
        case .secondary: return secondary
        case .accent: return accent
        case .background: return background
        case .surface: return surface
        case .text: return text
        case .border: return border
        case .selection: return selection
        case .mastered: return mastered
        case .almost: return almost
        case .learning: return learning
        case .weak: return weak
        case .new: return new
        }
    }
}

enum ThemeColorKey {
    case primary, secondary, accent, background, surface, text, border, selection
    case mastered, almost, learning, weak, new
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    @AppStorage("selectedThemeId") var selectedThemeId: String = "default"

    @AppStorage("anki_hub_wallpaper_kind") var wallpaperKind: String = ""
    @AppStorage("anki_hub_wallpaper_value") var wallpaperValue: String = ""

    // 0: system, 1: light, 2: dark
    @AppStorage("anki_hub_color_scheme_override_v1") var colorSchemeOverride: Int = 0

    @AppStorage("anki_hub_use_liquid_glass_v1") var useLiquidGlass: Bool = true {
        didSet {
            objectWillChange.send()
        }
    }

    // Dual theme support: separate themes for light and dark modes

    @Published private(set) var systemColorScheme: ColorScheme = .light

    private let masteryColorsKey = "anki_hub_mastery_colors_v1"

    // START MERGED FROM UI/ThemeManager.swift
    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "system"  // Default
        case ocean = "ocean"
        case forest = "forest"
        case sunset = "sunset"
        case night = "night"
        case sakura = "sakura"
        case matcha = "matcha"
        case coffee = "coffee"
        case monochrome = "monochrome"
        case cyberpunk = "cyberpunk"
        case nordic = "nordic"
        case dracula = "dracula"

        // Art
        case monaLisa = "monaLisa"
        case starryNight = "starryNight"
        case sunflowers = "sunflowers"
        case theScream = "theScream"

        // City
        case rushHour = "rushHour"
        case skyscrapers = "skyscrapers"
        case glassCity = "glassCity"
        case neonStreet = "neonStreet"
        case nightView = "nightView"
        // Missing "midnight" from V2 ref, mapping to "night" or keeping separate?
        // "midnight" was in previous AppTheme, "night" is in presets. Let's alias/use night.

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return "システム"
            case .ocean: return "オーシャン"
            case .forest: return "フォレスト"
            case .sunset: return "サンセット"
            case .night: return "ナイト"
            case .sakura: return "桜"
            case .matcha: return "抹茶"
            case .coffee: return "珈琲"
            case .monochrome: return "モノクロ"
            case .cyberpunk: return "サイバーパンク"
            case .nordic: return "北欧"
            case .dracula: return "ドラキュラ"
            case .monaLisa: return "モナ・リザ"
            case .starryNight: return "星月夜"
            case .sunflowers: return "ひまわり"
            case .theScream: return "叫び"
            case .rushHour: return "ラッシュアワー"
            case .skyscrapers: return "摩天楼"
            case .glassCity: return "硝子の街"
            case .neonStreet: return "ネオン街"
            case .nightView: return "夜景"
            }
        }

        var previewColor: Color {
            // Return primary color for preview
            if let palette = ThemeManager.shared.getPalette(id: self.rawValue) {
                return Color(hex: palette.primary)
            }
            return .gray
        }

        /// Whether this theme uses a dark color scheme
        var isDark: Bool {
            switch self {
            case .night, .dracula, .cyberpunk, .neonStreet, .nightView, .starryNight:
                return true
            default:
                return false
            }
        }
    }

    var effectiveIsDark: Bool {
        switch colorSchemeOverride {
        case 2: return true
        case 1: return false
        default: return systemColorScheme == .dark
        }
    }

    var effectivePreferredColorScheme: ColorScheme? {
        switch colorSchemeOverride {
        case 2: return .dark
        case 1: return .light
        default: return nil
        }
    }

    #if os(iOS)
        private func photoWallpaperImage() -> UIImage? {
            guard wallpaperKind == "photo", !wallpaperValue.isEmpty else { return nil }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            guard let url = docs?.appendingPathComponent(wallpaperValue) else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            guard let img = UIImage(data: data) else { return nil }

            // If an old wallpaper file is HEIC/HEIF, convert it to JPG and update reference.
            let lower = url.pathExtension.lowercased()
            if lower == "heic" || lower == "heif" {
                if let jpeg = img.jpegData(compressionQuality: 0.92) {
                    let newName = url.deletingPathExtension().lastPathComponent + ".jpg"
                    if let newUrl = docs?.appendingPathComponent(newName) {
                        do {
                            try jpeg.write(to: newUrl, options: .atomic)
                            DispatchQueue.main.async {
                                self.wallpaperValue = newName
                            }
                        } catch {
                            // keep original
                        }
                    }
                }
            }

            return img
        }

        private func bundledWallpaperImage() -> UIImage? {
            guard wallpaperKind == "bundle", !wallpaperValue.isEmpty else { return nil }
            let filename = wallpaperValue
            let ext = (filename as NSString).pathExtension
            let base = (filename as NSString).deletingPathExtension

            if let url = Bundle.main.url(
                forResource: base, withExtension: ext.isEmpty ? "jpg" : ext,
                subdirectory: "Wallpapers"),
                let data = try? Data(contentsOf: url),
                let img = UIImage(data: data)
            {
                return img
            }

            // Fallback: try common extensions if value has no extension
            if ext.isEmpty {
                for e in ["jpg", "jpeg", "png"] {
                    if let url = Bundle.main.url(
                        forResource: base, withExtension: e, subdirectory: "Wallpapers"),
                        let data = try? Data(contentsOf: url),
                        let img = UIImage(data: data)
                    {
                        return img
                    }
                }
            }
            return nil
        }
    #endif

    var background: AnyView {
        #if os(iOS)
            if let img = bundledWallpaperImage() {
                // Liquid Glass Style: Clear wallpaper with minimal overlay
                // The container views will handle readability with their own materials
                return AnyView(
                    ZStack {
                        GeometryReader { proxy in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                                .ignoresSafeArea()
                        }

                        // No blur (ultraThinMaterial) on background anymore
                        // Just a very subtle overlay for basic contrast if needed, or clear.
                        // User requested "clearly", so we keep it very light or removed.
                        // Let's keep a tiny bit of dark tint for text readability just in case,
                        // but much lighter than before.
                        Rectangle()
                            .fill(Color.black.opacity(effectiveIsDark ? 0.2 : 0.05))
                            .ignoresSafeArea()
                    }
                )
            }

            if let img = photoWallpaperImage() {
                return AnyView(
                    ZStack {
                        GeometryReader { proxy in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                                .ignoresSafeArea()
                        }

                        Rectangle()
                            .fill(Color.black.opacity(effectiveIsDark ? 0.2 : 0.05))
                            .ignoresSafeArea()
                    }
                )
            }

        #endif

        return AnyView(backgroundGradient.ignoresSafeArea())
    }

    // Liquid Glass Effect Background
    var backgroundGradient: LinearGradient {
        if wallpaperKind == "solid", let color = Color(hexOrName: wallpaperValue) {
            return LinearGradient(colors: [color, color], startPoint: .top, endPoint: .bottom)
        }
        if wallpaperKind == "gradient" {
            let parts = wallpaperValue.split(separator: ",").map { String($0) }
            if parts.count >= 2,
                let c1 = Color(hexOrName: parts[0]),
                let c2 = Color(hexOrName: parts[1])
            {
                return LinearGradient(
                    colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }

        let bg = currentPalette.color(.background, isDark: effectiveIsDark)
        let surface = currentPalette.color(.surface, isDark: effectiveIsDark)
        let primary = currentPalette.color(.primary, isDark: effectiveIsDark)
        let accent = currentPalette.color(.accent, isDark: effectiveIsDark)

        let top = Color.blend(bg, primary, t: effectiveIsDark ? 0.22 : 0.18)
        let mid = Color.blend(bg, accent, t: effectiveIsDark ? 0.08 : 0.06)
        let bottom = Color.blend(surface, accent, t: effectiveIsDark ? 0.18 : 0.14)
        return LinearGradient(
            colors: [top, mid, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var cardBackground: AnyShapeStyle {
        let surface = currentPalette.color(.surface, isDark: effectiveIsDark)
        return AnyShapeStyle(surface.opacity(effectiveIsDark ? 0.9 : 0.98))
    }

    var primaryText: Color {
        let surface = currentPalette.color(.surface, isDark: effectiveIsDark)
        let proposed = currentPalette.color(.text, isDark: effectiveIsDark)
        return readableTextColor(proposed: proposed, on: surface, minimumContrast: 4.5)
    }

    var secondaryText: Color {
        let surface = currentPalette.color(.surface, isDark: effectiveIsDark)
        let proposed = currentPalette.color(.secondary, isDark: effectiveIsDark)
        return readableTextColor(proposed: proposed, on: surface, minimumContrast: 3.0)
    }
    // END MERGED

    private func contrastRatio(foreground: Color, background: Color) -> Double? {
        guard let lf = foreground.relativeLuminance, let lb = background.relativeLuminance else {
            return nil
        }
        let lighter = max(lf, lb)
        let darker = min(lf, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func readableTextColor(proposed: Color, on background: Color, minimumContrast: Double) -> Color {
        if let r = contrastRatio(foreground: proposed, background: background), r >= minimumContrast {
            return proposed
        }

        let fallback = onColor(for: background)
        if let r2 = contrastRatio(foreground: fallback, background: background), r2 >= minimumContrast {
            return fallback
        }
        return fallback
    }

    func onColor(for background: Color, light: Color = .black, dark: Color = .white) -> Color {
        guard let l = background.relativeLuminance else {
            return effectiveIsDark ? dark : light
        }
        return l > 0.6 ? light : dark
    }

    static let shared = ThemeManager()

    @Published var currentPalette: ThemePalette

    func getPalette(id: String) -> ThemePalette? {
        return presets[id]
    }

    private let presets: [String: ThemePalette] = [
        // --- Standard Presets ---
        "default": ThemePalette(
            primary: "#4f46e5", secondary: "#64748b", accent: "#f59e0b", background: "#f9fafb",
            surface: "#ffffff", text: "#1f2937", border: "#e5e7eb", selection: "#4f46e5",
            mastered: "#10b981", almost: "#fbbf24", learning: "#f97316", weak: "#ef4444",
            new: "#9ca3af",
            primaryDark: "#6366f1", backgroundDark: "#0f172a", surfaceDark: "#1e293b",
            textDark: "#f8fafc", borderDark: "#334155", selectionDark: "#6366f1"
        ),
        "ocean": ThemePalette(
            primary: "#0ea5e9", secondary: "#64748b", accent: "#38bdf8", background: "#e0f2fe",
            surface: "#f0f9ff", text: "#0c4a6e", border: "#bae6fd", selection: "#0284c7",
            mastered: "#0ea5e9", almost: "#38bdf8", learning: "#7dd3fc", weak: "#0369a1",
            new: "#94a3b8",
            primaryDark: "#0ea5e9", backgroundDark: "#071f30", surfaceDark: "#0c4a6e",
            textDark: "#e0f2fe", borderDark: "#075985", selectionDark: "#38bdf8"
        ),
        "forest": ThemePalette(
            primary: "#22c55e", secondary: "#64748b", accent: "#86efac", background: "#dcfce7",
            surface: "#f0fdf4", text: "#14532d", border: "#bbf7d0", selection: "#16a34a",
            mastered: "#22c55e", almost: "#86efac", learning: "#16a34a", weak: "#14532d",
            new: "#9ca3af",
            primaryDark: "#22c55e", backgroundDark: "#052e16", surfaceDark: "#14532d",
            textDark: "#dcfce7", borderDark: "#14532d", selectionDark: "#4ade80"
        ),
        "sunset": ThemePalette(
            primary: "#f43f5e", secondary: "#64748b", accent: "#fb7185", background: "#ffe4e6",
            surface: "#fff1f2", text: "#881337", border: "#fecdd3", selection: "#e11d48",
            mastered: "#f43f5e", almost: "#fb7185", learning: "#fda4af", weak: "#881337",
            new: "#9ca3af",
            primaryDark: "#f43f5e", backgroundDark: "#4c0519", surfaceDark: "#881337",
            textDark: "#ffe4e6", borderDark: "#881337", selectionDark: "#fb7185"
        ),
        "night": ThemePalette(
            primary: "#8b5cf6", secondary: "#64748b", accent: "#a78bfa", background: "#ede9fe",
            surface: "#f5f3ff", text: "#5b21b6", border: "#ddd6fe", selection: "#7c3aed",
            mastered: "#8b5cf6", almost: "#a78bfa", learning: "#c4b5fd", weak: "#5b21b6",
            new: "#6b7280",
            primaryDark: "#8b5cf6", backgroundDark: "#1c1040", surfaceDark: "#2e1065",
            textDark: "#ede9fe", borderDark: "#5b21b6", selectionDark: "#8b5cf6"
        ),
        "sakura": ThemePalette(
            primary: "#f472b6", secondary: "#64748b", accent: "#fbcfe8", background: "#fdf2f8",
            surface: "#fff1f2", text: "#831843", border: "#fbcfe8", selection: "#ec4899",
            mastered: "#f472b6", almost: "#fbcfe8", learning: "#f9a8d4", weak: "#db2777",
            new: "#9ca3af",
            primaryDark: "#f472b6", backgroundDark: "#500724", surfaceDark: "#831843",
            textDark: "#fdf2f8", borderDark: "#831843", selectionDark: "#f472b6"
        ),
        "matcha": ThemePalette(
            primary: "#84cc16", secondary: "#64748b", accent: "#bef264", background: "#ecfccb",
            surface: "#f7fee7", text: "#3f6212", border: "#d9f99d", selection: "#65a30d",
            mastered: "#84cc16", almost: "#bef264", learning: "#a3e635", weak: "#3f6212",
            new: "#9ca3af",
            primaryDark: "#84cc16", backgroundDark: "#1a2e05", surfaceDark: "#3f6212",
            textDark: "#ecfccb", borderDark: "#3f6212", selectionDark: "#84cc16"
        ),
        "coffee": ThemePalette(
            primary: "#d97706", secondary: "#64748b", accent: "#fcd34d", background: "#fef3c7",
            surface: "#fffbeb", text: "#78350f", border: "#fde68a", selection: "#b45309",
            mastered: "#d97706", almost: "#fcd34d", learning: "#f59e0b", weak: "#78350f",
            new: "#9ca3af",
            primaryDark: "#d97706", backgroundDark: "#451a03", surfaceDark: "#78350f",
            textDark: "#fef3c7", borderDark: "#78350f", selectionDark: "#d97706"
        ),
        "monochrome": ThemePalette(
            primary: "#525252", secondary: "#a3a3a3", accent: "#737373", background: "#FFFFFF",
            surface: "#FAFAFA", text: "#000000", border: "#e5e5e5", selection: "#404040",
            mastered: "#525252", almost: "#a3a3a3", learning: "#737373", weak: "#171717",
            new: "#d4d4d4",
            primaryDark: "#d4d4d4", backgroundDark: "#000000", surfaceDark: "#171717",
            textDark: "#FFFFFF", borderDark: "#404040", selectionDark: "#d4d4d4"
        ),
        "cyberpunk": ThemePalette(
            primary: "#00ff41", secondary: "#fdfd00", accent: "#00ffff", background: "#f8fafc",
            surface: "#ffffff", text: "#0f172a", border: "#cbd5e1", selection: "#00ffff",
            mastered: "#00ff41", almost: "#fdfd00", learning: "#ff00ff", weak: "#ff0055",
            new: "#94a3b8",
            primaryDark: "#00ff41", backgroundDark: "#000507", surfaceDark: "#00151a",
            textDark: "#2aa198", borderDark: "#586e75", selectionDark: "#2aa198"
        ),
        "nordic": ThemePalette(
            primary: "#5e81ac", secondary: "#81a1c1", accent: "#88c0d0", background: "#d8dee9",
            surface: "#eceff4", text: "#2e3440", border: "#e5e9f0", selection: "#5e81ac",
            mastered: "#5e81ac", almost: "#81a1c1", learning: "#88c0d0", weak: "#bf616a",
            new: "#d8dee9",
            primaryDark: "#5e81ac", backgroundDark: "#2e3440", surfaceDark: "#3b4252",
            textDark: "#eceff4", borderDark: "#4c566a", selectionDark: "#88c0d0"
        ),
        "dracula": ThemePalette(
            primary: "#bd93f9", secondary: "#6272a4", accent: "#ffb86c", background: "#f8fafc",
            surface: "#ffffff", text: "#1f2937", border: "#e5e7eb", selection: "#bd93f9",
            mastered: "#50fa7b", almost: "#f1fa8c", learning: "#ffb86c", weak: "#ff5555",
            new: "#94a3b8",
            primaryDark: "#bd93f9", backgroundDark: "#191a21", surfaceDark: "#282a36",
            textDark: "#f8f8f2", borderDark: "#44475a", selectionDark: "#ff79c6"
        ),
        // --- Art Presets ---
        "monaLisa": ThemePalette(
            primary: "#8b7355", secondary: "#c4a574", accent: "#c9b896", background: "#f5efe0",
            surface: "#fdf8e8", text: "#3d2914", border: "#c9b896", selection: "#7c6543",
            mastered: "#8b7355", almost: "#c4a574", learning: "#a67c52", weak: "#6b4423",
            new: "#d4c4a8",
            primaryDark: "#8b7355", backgroundDark: "#1a150f", surfaceDark: "#2a2218",
            textDark: "#e8dcc8", borderDark: "#5c4a35", selectionDark: "#a67c52"
        ),
        "starryNight": ThemePalette(
            primary: "#1e3a6d", secondary: "#f4d03f", accent: "#7eb3e0", background: "#e8f2fc",
            surface: "#f0f7ff", text: "#1a2f4a", border: "#7eb3e0", selection: "#1e3a6d",
            mastered: "#4a90d9", almost: "#f4d03f", learning: "#5eb3f4", weak: "#2d4a87",
            new: "#8bacd0",
            primaryDark: "#1e3a6d", backgroundDark: "#0a1222", surfaceDark: "#0f1a2d",
            textDark: "#b8d4f0", borderDark: "#2d5a8c", selectionDark: "#5eb3f4"
        ),
        "sunflowers": ThemePalette(
            primary: "#e8a317", secondary: "#f4c430", accent: "#e8d080", background: "#fff8e0",
            surface: "#fffef5", text: "#5c4a1a", border: "#e8d080", selection: "#d4a520",
            mastered: "#f4c430", almost: "#e8a317", learning: "#d4942a", weak: "#8b4513",
            new: "#f5e6b8",
            primaryDark: "#e8a317", backgroundDark: "#1c180a", surfaceDark: "#2a2410",
            textDark: "#f5e6b8", borderDark: "#a67c20", selectionDark: "#f4c430"
        ),
        "theScream": ThemePalette(
            primary: "#c43c00", secondary: "#f4a460", accent: "#e8a060", background: "#ffeee0",
            surface: "#fff8f0", text: "#4a2a1a", border: "#e8a060", selection: "#c43c00",
            mastered: "#ff6b35", almost: "#f4a460", learning: "#e85d04", weak: "#8b0000",
            new: "#d4a574",
            primaryDark: "#c43c00", backgroundDark: "#1c1008", surfaceDark: "#2a1a10",
            textDark: "#f4d4b8", borderDark: "#8b4a20", selectionDark: "#ff6b35"
        ),
        // --- City/Modern Presets ---
        "rushHour": ThemePalette(
            primary: "#e85d04", secondary: "#ffd93d", accent: "#d0d0d0", background: "#f0ece8",
            surface: "#fafaf8", text: "#3a3028", border: "#d0d0d0", selection: "#e85d04",
            mastered: "#ff6b35", almost: "#ffd93d", learning: "#ff8c42", weak: "#c73e1d",
            new: "#a0a0a0",
            primaryDark: "#e85d04", backgroundDark: "#12100e", surfaceDark: "#1a1816",
            textDark: "#e0d8d0", borderDark: "#505050", selectionDark: "#ff6b35"
        ),
        "skyscrapers": ThemePalette(
            primary: "#3a6a8a", secondary: "#8ab4c8", accent: "#90a8b8", background: "#e4ecf0",
            surface: "#f5f8fa", text: "#1a2a38", border: "#90a8b8", selection: "#3a6a8a",
            mastered: "#4a7c9b", almost: "#8ab4c8", learning: "#6a9cb0", weak: "#2a4a5b",
            new: "#a8c0d0",
            primaryDark: "#3a6a8a", backgroundDark: "#0a1014", surfaceDark: "#10181c",
            textDark: "#b0c4d0", borderDark: "#3a5060", selectionDark: "#5a8aa4"
        ),
        "glassCity": ThemePalette(
            primary: "#4a9ac0", secondary: "#b8e0f0", accent: "#a8d0e0", background: "#e8f4fa",
            surface: "#f8fcff", text: "#1a3040", border: "#a8d0e0", selection: "#4a9ac0",
            mastered: "#7ec8e3", almost: "#b8e0f0", learning: "#98d4e8", weak: "#4a8aa0",
            new: "#c8e0ec",
            primaryDark: "#4a9ac0", backgroundDark: "#081018", surfaceDark: "#0c1820",
            textDark: "#b8d8ec", borderDark: "#3a6070", selectionDark: "#6ab4d4"
        ),
        "neonStreet": ThemePalette(
            primary: "#e040a0", secondary: "#00ffff", accent: "#00ffff", background: "#fff7fb",
            surface: "#ffffff", text: "#1f2937", border: "#f0abfc", selection: "#e040a0",
            mastered: "#ff00ff", almost: "#00ffff", learning: "#ff6ec7", weak: "#8a2be2",
            new: "#94a3b8",
            primaryDark: "#e040a0", backgroundDark: "#06040a", surfaceDark: "#0c0810",
            textDark: "#e8d8f0", borderDark: "#4a2a5a", selectionDark: "#ff40b0"
        ),
        "nightView": ThemePalette(
            primary: "#00a0c0", secondary: "#ff6b9d", accent: "#ffd700", background: "#f1f5f9",
            surface: "#ffffff", text: "#0f172a", border: "#cbd5e1", selection: "#00a0c0",
            mastered: "#ffd700", almost: "#ff6b9d", learning: "#00bfff", weak: "#1a1a3a",
            new: "#94a3b8",
            primaryDark: "#00a0c0", backgroundDark: "#080810", surfaceDark: "#101018",
            textDark: "#d8d8e8", borderDark: "#2a2a4a", selectionDark: "#40c0e0"
        ),
    ]

    init() {
        #if os(iOS)
            systemColorScheme =
                UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        #endif
        // Load initial
        self.currentPalette = ThemePalette(
            primary: "#4f46e5", secondary: "#64748b", accent: "#f59e0b", background: "#f9fafb",
            surface: "#ffffff", text: "#1f2937", border: "#e5e7eb", selection: "#4f46e5",
            mastered: "#10b981", almost: "#fbbf24", learning: "#f97316", weak: "#ef4444",
            new: "#9ca3af",
            primaryDark: "#6366f1", backgroundDark: "#0f172a", surfaceDark: "#1e293b",
            textDark: "#f8fafc", borderDark: "#334155", selectionDark: "#6366f1"
        )

        let id = UserDefaults.standard.string(forKey: "selectedThemeId") ?? "default"
        self.applyTheme(id: id)
        loadMasteryColorOverrides()
    }

    func updateSystemColorScheme(_ scheme: ColorScheme) {
        if systemColorScheme != scheme {
            systemColorScheme = scheme
        }
    }

    private func requestAutoSyncOnMainActor() {
        Task { @MainActor in
            SyncManager.shared.requestAutoSync()
        }
    }

    func applyTheme(id: String) {
        if let palette = presets[id] {
            currentPalette = palette
            selectedThemeId = id
            UserDefaults.standard.set(id, forKey: "selectedThemeId")
            requestAutoSyncOnMainActor()
        }
    }

    func applyWallpaper(kind: String, value: String) {
        wallpaperKind = kind
        wallpaperValue = value
        requestAutoSyncOnMainActor()
    }

    func applyMasteryColors(
        new: Color, weak: Color, learning: Color, almost: Color, mastered: Color
    ) {
        guard let newHex = new.toHexString(),
            let weakHex = weak.toHexString(),
            let learningHex = learning.toHexString(),
            let almostHex = almost.toHexString(),
            let masteredHex = mastered.toHexString()
        else {
            return
        }

        let dict: [String: String] = [
            "new": newHex,
            "weak": weakHex,
            "learning": learningHex,
            "almost": almostHex,
            "mastered": masteredHex,
        ]

        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: masteryColorsKey)
        }

        currentPalette.new = newHex
        currentPalette.weak = weakHex
        currentPalette.learning = learningHex
        currentPalette.almost = almostHex
        currentPalette.mastered = masteredHex

        objectWillChange.send()
        requestAutoSyncOnMainActor()
    }

    private func loadMasteryColorOverrides() {
        guard let data = UserDefaults.standard.data(forKey: masteryColorsKey),
            let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return
        }

        if let v = dict["new"] { currentPalette.new = v }
        if let v = dict["weak"] { currentPalette.weak = v }
        if let v = dict["learning"] { currentPalette.learning = v }
        if let v = dict["almost"] { currentPalette.almost = v }
        if let v = dict["mastered"] { currentPalette.mastered = v }
    }

    // Helper to get colors in Views
    func color(_ key: ThemeColorKey, scheme: ColorScheme) -> Color {
        let resolved = effectivePreferredColorScheme ?? scheme
        return currentPalette.color(key, isDark: resolved == .dark)
    }

    var availableThemes: [String] {
        return presets.keys.sorted()
    }

    func getThemeName(_ id: String) -> String {
        switch id {
        case "default": return "デフォルト"
        case "ocean": return "オーシャン"
        case "forest": return "フォレスト"
        case "sunset": return "サンセット"
        case "night": return "ナイト"
        case "sakura": return "桜"
        case "matcha": return "抹茶"
        case "coffee": return "珈琲"
        case "monochrome": return "モノクロ"
        case "cyberpunk": return "サイバーパンク"
        case "nordic": return "北欧"
        case "dracula": return "ドラキュラ"
        default: return id.capitalized
        }
    }
}

extension Color {
    init?(hexOrName: String) {
        let trimmed = hexOrName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#")
            || trimmed.range(of: "^[0-9A-Fa-f]{6,8}$", options: .regularExpression) != nil
        {
            self = Color(hex: trimmed)
            return
        }
        return nil
    }

    var relativeLuminance: Double? {
        #if os(iOS)
            let uiColor = UIColor(self)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
            func adjust(_ c: CGFloat) -> Double {
                let v = Double(c)
                return v <= 0.03928 ? (v / 12.92) : pow((v + 0.055) / 1.055, 2.4)
            }
            let rr = adjust(r)
            let gg = adjust(g)
            let bb = adjust(b)
            return 0.2126 * rr + 0.7152 * gg + 0.0722 * bb
        #else
            let nsColor = NSColor(self)
            guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { return nil }
            func adjust(_ c: CGFloat) -> Double {
                let v = Double(c)
                return v <= 0.03928 ? (v / 12.92) : pow((v + 0.055) / 1.055, 2.4)
            }
            let rr = adjust(rgb.redComponent)
            let gg = adjust(rgb.greenComponent)
            let bb = adjust(rgb.blueComponent)
            return 0.2126 * rr + 0.7152 * gg + 0.0722 * bb
        #endif
    }

    func toHexString() -> String? {
        #if os(iOS)
            let uiColor = UIColor(self)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        #else
            let nsColor = NSColor(self)
            guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { return nil }
            let r = rgb.redComponent
            let g = rgb.greenComponent
            let b = rgb.blueComponent
            let a = rgb.alphaComponent
        #endif

        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        let ai = Int(round(a * 255))
        return String(format: "#%02X%02X%02X%02X", ai, ri, gi, bi)
    }

    func onColor(for color: Color) -> Color {
        guard let luminance = color.relativeLuminance else { return .white }
        return luminance > 0.5 ? .black : .white
    }

    fileprivate func rgbaComponents() -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        #if os(iOS)
            let uiColor = UIColor(self)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
            return (r, g, b, a)
        #else
            let nsColor = NSColor(self)
            guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { return nil }
            return (rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent)
        #endif
    }

    static func blend(_ a: Color, _ b: Color, t: CGFloat) -> Color {
        let tt = max(0, min(1, t))
        guard let ca = a.rgbaComponents(), let cb = b.rgbaComponents() else {
            return tt < 0.5 ? a : b
        }
        let r = ca.0 + (cb.0 - ca.0) * tt
        let g = ca.1 + (cb.1 - ca.1) * tt
        let bb = ca.2 + (cb.2 - ca.2) * tt
        let aa = ca.3 + (cb.3 - ca.3) * tt
        return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(bb), opacity: Double(aa))
    }
}

// View Modifier for Easy Application
struct AppThemeModifier: ViewModifier {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let tintColor = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)

        content
            .preferredColorScheme(theme.effectivePreferredColorScheme)
            .tint(tintColor)
            .onAppear {
                theme.updateSystemColorScheme(colorScheme)
            }
            .onChange(of: colorScheme) { _, newValue in
                theme.updateSystemColorScheme(newValue)
            }
    }
}

extension View {
    func applyAppTheme() -> some View {
        self.modifier(AppThemeModifier())
    }
}
