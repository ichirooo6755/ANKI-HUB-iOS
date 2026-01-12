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

        let useMaterial = theme.useLiquidGlass && needsExtraContrast
        let surfaceOpacity: Double = {
            if useMaterial {
                return isDark ? 0.78 : 0.62
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

    private func readableTextColor(proposed: Color, on background: Color, minimumContrast: Double)
        -> Color
    {
        if let r = contrastRatio(foreground: proposed, background: background), r >= minimumContrast
        {
            return proposed
        }

        let fallback = onColor(for: background)
        if let r2 = contrastRatio(foreground: fallback, background: background),
            r2 >= minimumContrast
        {
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

    private static func makePreset(
        selection: String,
        background: String,
        surface: String,
        text: String,
        border: String,
        mastered: String,
        almost: String,
        learning: String,
        weak: String,
        new: String,
        isDarkBase: Bool = false
    ) -> ThemePalette {
        if isDarkBase {
            return ThemePalette(
                primary: selection,
                secondary: new,
                accent: almost,
                background: background,
                surface: surface,
                text: text,
                border: border,
                selection: selection,
                mastered: mastered,
                almost: almost,
                learning: learning,
                weak: weak,
                new: new,
                primaryDark: selection,
                backgroundDark: background,
                surfaceDark: surface,
                textDark: text,
                borderDark: border,
                selectionDark: selection
            )
        }

        return ThemePalette(
            primary: selection,
            secondary: new,
            accent: almost,
            background: background,
            surface: surface,
            text: text,
            border: border,
            selection: selection,
            mastered: mastered,
            almost: almost,
            learning: learning,
            weak: weak,
            new: new,
            primaryDark: selection,
            backgroundDark: "#0f172a",
            surfaceDark: "#1e293b",
            textDark: "#f8fafc",
            borderDark: "#334155",
            selectionDark: selection
        )
    }

    private let presets: [String: ThemePalette] = [
        // --- Standard Presets ---
        "default": ThemePalette(
            primary: "#4f46e5", secondary: "#64748b", accent: "#f59e0b", background: "#f9fafb",
            surface: "#ffffff", text: "#1f2937", border: "#e5e7eb", selection: "#4f46e5",
            mastered: "#10b981", almost: "#f59e0b", learning: "#f97316", weak: "#ef4444",
            new: "#9ca3af",
            primaryDark: "#6366f1", backgroundDark: "#0f172a", surfaceDark: "#1e293b",
            textDark: "#f8fafc", borderDark: "#334155", selectionDark: "#6366f1"
        ),
        "ocean": ThemePalette(
            primary: "#0ea5e9", secondary: "#64748b", accent: "#f59e0b", background: "#f0f9ff",
            surface: "#ffffff", text: "#0c4a6e", border: "#bae6fd", selection: "#0ea5e9",
            mastered: "#10b981", almost: "#f59e0b", learning: "#f97316", weak: "#ef4444",
            new: "#94a3b8",
            primaryDark: "#0ea5e9", backgroundDark: "#071f30", surfaceDark: "#0c4a6e",
            textDark: "#e0f2fe", borderDark: "#075985", selectionDark: "#38bdf8"
        ),
        "forest": ThemePalette(
            primary: "#16a34a", secondary: "#64748b", accent: "#84cc16", background: "#f0fdf4",
            surface: "#ffffff", text: "#14532d", border: "#bbf7d0", selection: "#16a34a",
            mastered: "#22c55e", almost: "#84cc16", learning: "#a3e635", weak: "#dc2626",
            new: "#a8a29e",
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
            primary: "#7c3aed", secondary: "#64748b", accent: "#a78bfa", background: "#f3e8ff",
            surface: "#faf5ff", text: "#4c1d95", border: "#c4b5fd", selection: "#7c3aed",
            mastered: "#818cf8", almost: "#a78bfa", learning: "#6366f1", weak: "#ec4899",
            new: "#71717a",
            primaryDark: "#7c3aed", backgroundDark: "#1c1040", surfaceDark: "#2e1065",
            textDark: "#ede9fe", borderDark: "#5b21b6", selectionDark: "#7c3aed"
        ),
        "sakura": ThemePalette(
            primary: "#f472b6", secondary: "#64748b", accent: "#f9a8d4", background: "#fdf2f8",
            surface: "#ffffff", text: "#831843", border: "#fbcfe8", selection: "#f472b6",
            mastered: "#ec4899", almost: "#f9a8d4", learning: "#e879f9", weak: "#f43f5e",
            new: "#d1d5db",
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
            primary: "#d946ef", secondary: "#0ea5e9", accent: "#c026d3", background: "#fdf4ff",
            surface: "#ffffff", text: "#4a044e", border: "#f0abfc", selection: "#e879f9",
            mastered: "#d946ef", almost: "#0ea5e9", learning: "#e879f9", weak: "#86198f",
            new: "#94a3b8",
            primaryDark: "#e040a0", backgroundDark: "#0a0818", surfaceDark: "#1a1020",
            textDark: "#f0e0f8", borderDark: "#5a3a7a", selectionDark: "#e040a0"
        ),
        "nightView": ThemePalette(
            primary: "#0284c7", secondary: "#f43f5e", accent: "#f59e0b", background: "#f0f9ff",
            surface: "#ffffff", text: "#0c4a6e", border: "#bae6fd", selection: "#38bdf8",
            mastered: "#fbbf24", almost: "#f43f5e", learning: "#0ea5e9", weak: "#0c4a6e",
            new: "#94a3b8",
            primaryDark: "#00a0c0", backgroundDark: "#0a0a1a", surfaceDark: "#1a1a2a",
            textDark: "#e8e8f0", borderDark: "#3a3a5a", selectionDark: "#00a0c0"
        ),

        "midnight": ThemePalette(
            primary: "#4f46e5", secondary: "#94a3b8", accent: "#6366f1", background: "#f8fafc",
            surface: "#ffffff", text: "#1e293b", border: "#e2e8f0", selection: "#818cf8",
            mastered: "#34d399", almost: "#fbbf24", learning: "#fb923c", weak: "#f87171",
            new: "#475569",
            primaryDark: "#818cf8", backgroundDark: "#0f172a", surfaceDark: "#1e293b",
            textDark: "#e2e8f0", borderDark: "#334155", selectionDark: "#818cf8"
        ),

        "fugaku36": ThemePalette(
            primary: "#d97706", secondary: "#916016", accent: "#f59e0b", background: "#fffbeb",
            surface: "#ffffff", text: "#1e3a8a", border: "#fcd34d", selection: "#b45309",
            mastered: "#4ade80", almost: "#fcd34d", learning: "#f59e0b", weak: "#f87171",
            new: "#94a3b8",
            primaryDark: "#d9c179", backgroundDark: "#010326", surfaceDark: "#011140",
            textDark: "#f2d1b3", borderDark: "#8c857d", selectionDark: "#d9c179"
        ),
        "nature": ThemeManager.makePreset(
            selection: "#6393A6",
            background: "#F2CBBD",
            surface: "#ffffff",
            text: "#733B36",
            border: "#BF785E",
            mastered: "#22C55E",
            almost: "#6393A6",
            learning: "#BF785E",
            weak: "#EF4444",
            new: "#9CA3AF"
        ),
        "travel": ThemeManager.makePreset(
            selection: "#A0D9D9",
            background: "#f4f4f5",
            surface: "#ffffff",
            text: "#1f2937",
            border: "#D9C589",
            mastered: "#45858C",
            almost: "#D9C589",
            learning: "#BF9765",
            weak: "#A62626",
            new: "#A0D9D9"
        ),
        "tunnel": ThemePalette(
            primary: "#0d9488", secondary: "#0f766e", accent: "#14b8a6", background: "#f0fdfa",
            surface: "#ffffff", text: "#134e4a", border: "#99f6e4", selection: "#0f766e",
            mastered: "#10b981", almost: "#14b8a6", learning: "#0e7490", weak: "#f43f5e",
            new: "#94a3b8",
            primaryDark: "#f2668b", backgroundDark: "#011f26", surfaceDark: "#025e73",
            textDark: "#f2668b", borderDark: "#026873", selectionDark: "#f2668b"
        ),
        "circle": ThemeManager.makePreset(
            selection: "#184040",
            background: "#F2F2F2",
            surface: "#ffffff",
            text: "#011F26",
            border: "#A9D9CB",
            mastered: "#8FD9C4",
            almost: "#A9D9CB",
            learning: "#184040",
            weak: "#F2F2F2",
            new: "#F2F2F2"
        ),
        "fugaku": ThemePalette(
            primary: "#d9bb84", secondary: "#916016", accent: "#d9bb84", background: "#fffbeb",
            surface: "#ffffff", text: "#422006", border: "#fcd34d", selection: "#b45309",
            mastered: "#4ade80", almost: "#d9bb84", learning: "#60a5fa", weak: "#f87171",
            new: "#94a3b8",
            primaryDark: "#d9bb84", backgroundDark: "#051931", surfaceDark: "#1f2937",
            textDark: "#d9bb84", borderDark: "#4a7348", selectionDark: "#d9bb84"
        ),
        "image1": ThemeManager.makePreset(
            selection: "#1F67A6",
            background: "#E9ECF2",
            surface: "#ffffff",
            text: "#011640",
            border: "#7B838C",
            mastered: "#1F67A6",
            almost: "#2474A6",
            learning: "#7B838C",
            weak: "#011640",
            new: "#E9ECF2"
        ),
        "image5": ThemeManager.makePreset(
            selection: "#A63333",
            background: "#F2F0D8",
            surface: "#ffffff",
            text: "#0D0D0D",
            border: "#BFBDB0",
            mastered: "#A63333",
            almost: "#BF2626",
            learning: "#BFBDB0",
            weak: "#0D0D0D",
            new: "#F2F0D8"
        ),
        "img1136": ThemeManager.makePreset(
            selection: "#05AFF2",
            background: "#ffffff",
            surface: "#ffffff",
            text: "#048C4D",
            border: "#809FA6",
            mastered: "#048C4D",
            almost: "#F2E394",
            learning: "#809FA6",
            weak: "#05AFF2",
            new: "#05C7F2"
        ),
        "img1136_2": ThemePalette(
            primary: "#05c7f2", secondary: "#03a64a", accent: "#05aff2", background: "#ecfdf5",
            surface: "#ffffff", text: "#064e3b", border: "#6ee7b7", selection: "#05c7f2",
            mastered: "#048c4d", almost: "#03a64a", learning: "#05c7f2", weak: "#05aff2",
            new: "#94a3b8",
            primaryDark: "#05c7f2", backgroundDark: "#022601", surfaceDark: "#022601",
            textDark: "#05aff2", borderDark: "#03a64a", selectionDark: "#05c7f2"
        ),
        "img1834": ThemePalette(
            primary: "#d99c9c", secondary: "#8cf25c", accent: "#d99c9c", background: "#f8fafc",
            surface: "#ffffff", text: "#0f172a", border: "#e2e8f0", selection: "#d99c9c",
            mastered: "#8cf25c", almost: "#d99c9c", learning: "#d9d1c7", weak: "#a61c28",
            new: "#94a3b8",
            primaryDark: "#d99c9c", backgroundDark: "#012340", surfaceDark: "#012340",
            textDark: "#d9d1c7", borderDark: "#d9d1c7", selectionDark: "#d99c9c"
        ),
        "img2815": ThemePalette(
            primary: "#7ebfd9", secondary: "#48592e", accent: "#7ebfd9", background: "#f8fafc",
            surface: "#ffffff", text: "#0f172a", border: "#e2e8f0", selection: "#7ebfd9",
            mastered: "#48592e", almost: "#7ebfd9", learning: "#c4e5f2", weak: "#8c4227",
            new: "#94a3b8",
            primaryDark: "#7ebfd9", backgroundDark: "#0d0d0d", surfaceDark: "#2c3540",
            textDark: "#c4e5f2", borderDark: "#2c3540", selectionDark: "#7ebfd9"
        ),
        "img2815_2": ThemePalette(
            primary: "#cee8f2", secondary: "#48592e", accent: "#7ebfd9", background: "#f8fafc",
            surface: "#ffffff", text: "#0f172a", border: "#7ebfd9", selection: "#cee8f2",
            mastered: "#48592e", almost: "#7ebfd9", learning: "#cee8f2", weak: "#8c4227",
            new: "#94a3b8",
            primaryDark: "#cee8f2", backgroundDark: "#2c3540", surfaceDark: "#ffffff",
            textDark: "#cee8f2", borderDark: "#7ebfd9", selectionDark: "#cee8f2"
        ),
        "img2815_3": ThemeManager.makePreset(
            selection: "#C4E5F2",
            background: "#161D26",
            surface: "#010D00",
            text: "#C4E5F2",
            border: "#434D59",
            mastered: "#1A2601",
            almost: "#010D00",
            learning: "#434D59",
            weak: "#161D26",
            new: "#C4E5F2",
            isDarkBase: true
        ),

        "greenForest": ThemeManager.makePreset(
            selection: "#16a34a",
            background: "#f0fdf4",
            surface: "#ffffff",
            text: "#14532d",
            border: "#86efac",
            mastered: "#22c55e",
            almost: "#84cc16",
            learning: "#eab308",
            weak: "#ef4444",
            new: "#6b7280"
        ),
        "pinkNoir": ThemePalette(
            primary: "#db2777", secondary: "#f472b6", accent: "#db2777", background: "#fdf2f8",
            surface: "#ffffff", text: "#831843", border: "#fbcfe8", selection: "#db2777",
            mastered: "#ec4899", almost: "#f472b6", learning: "#a855f7", weak: "#ef4444",
            new: "#9ca3af",
            primaryDark: "#db2777", backgroundDark: "#0a0a0a", surfaceDark: "#18181b",
            textDark: "#fce7f3", borderDark: "#831843", selectionDark: "#db2777"
        ),
        "sunshine": ThemeManager.makePreset(
            selection: "#eab308",
            background: "#fefce8",
            surface: "#ffffff",
            text: "#713f12",
            border: "#fde047",
            mastered: "#22c55e",
            almost: "#facc15",
            learning: "#f97316",
            weak: "#ef4444",
            new: "#9ca3af"
        ),
        "lavenderDream": ThemeManager.makePreset(
            selection: "#8b5cf6",
            background: "#f5f3ff",
            surface: "#ffffff",
            text: "#4c1d95",
            border: "#c4b5fd",
            mastered: "#a78bfa",
            almost: "#c4b5fd",
            learning: "#818cf8",
            weak: "#f87171",
            new: "#94a3b8"
        ),
        "coffeeBreak": ThemeManager.makePreset(
            selection: "#92400e",
            background: "#f5f5f4",
            surface: "#fafaf9",
            text: "#44403c",
            border: "#d6d3d1",
            mastered: "#84cc16",
            almost: "#d97706",
            learning: "#b45309",
            weak: "#dc2626",
            new: "#78716c"
        ),
        "retroGaming": ThemePalette(
            primary: "#10b981", secondary: "#4ade80", accent: "#06b6d4", background: "#f0fdfa",
            surface: "#ffffff", text: "#064e3b", border: "#67e8f9", selection: "#10b981",
            mastered: "#4ade80", almost: "#a3e635", learning: "#facc15", weak: "#f87171",
            new: "#22d3ee",
            primaryDark: "#10b981", backgroundDark: "#020617", surfaceDark: "#0f172a",
            textDark: "#4ade80", borderDark: "#06b6d4", selectionDark: "#10b981"
        ),

        "spring": ThemeManager.makePreset(
            selection: "#f472b6",
            background: "#fff1f2",
            surface: "#ffffff",
            text: "#4c0519",
            border: "#fecaca",
            mastered: "#86efac",
            almost: "#fda4af",
            learning: "#fdba74",
            weak: "#f87171",
            new: "#d1d5db"
        ),
        "summer": ThemeManager.makePreset(
            selection: "#0284c7",
            background: "#f0f9ff",
            surface: "#ffffff",
            text: "#0c4a6e",
            border: "#7dd3fc",
            mastered: "#22c55e",
            almost: "#0ea5e9",
            learning: "#f59e0b",
            weak: "#ef4444",
            new: "#94a3b8"
        ),
        "autumn": ThemeManager.makePreset(
            selection: "#c2410c",
            background: "#fef3c7",
            surface: "#fffbeb",
            text: "#78350f",
            border: "#fed7aa",
            mastered: "#84cc16",
            almost: "#f59e0b",
            learning: "#ea580c",
            weak: "#dc2626",
            new: "#a8a29e"
        ),
        "winter": ThemeManager.makePreset(
            selection: "#475569",
            background: "#f8fafc",
            surface: "#ffffff",
            text: "#1e293b",
            border: "#e2e8f0",
            mastered: "#64748b",
            almost: "#94a3b8",
            learning: "#a1a1aa",
            weak: "#9ca3af",
            new: "#e5e7eb"
        ),
        "morning": ThemeManager.makePreset(
            selection: "#fbbf24",
            background: "#fffbeb",
            surface: "#ffffff",
            text: "#422006",
            border: "#fef3c7",
            mastered: "#a7f3d0",
            almost: "#fef08a",
            learning: "#fed7aa",
            weak: "#fecaca",
            new: "#f1f5f9"
        ),
        "noon": ThemeManager.makePreset(
            selection: "#eab308",
            background: "#fefce8",
            surface: "#ffffff",
            text: "#713f12",
            border: "#fde047",
            mastered: "#22c55e",
            almost: "#facc15",
            learning: "#fb923c",
            weak: "#ef4444",
            new: "#9ca3af"
        ),
        "dusk": ThemeManager.makePreset(
            selection: "#ea580c",
            background: "#fff7ed",
            surface: "#fffbeb",
            text: "#7c2d12",
            border: "#fdba74",
            mastered: "#fb923c",
            almost: "#fbbf24",
            learning: "#f97316",
            weak: "#dc2626",
            new: "#a8a29e"
        ),
        "clearSky": ThemeManager.makePreset(
            selection: "#0284c7",
            background: "#f0f9ff",
            surface: "#ffffff",
            text: "#0c4a6e",
            border: "#bae6fd",
            mastered: "#22c55e",
            almost: "#0ea5e9",
            learning: "#06b6d4",
            weak: "#ef4444",
            new: "#94a3b8"
        ),
        "cloudy": ThemeManager.makePreset(
            selection: "#64748b",
            background: "#f1f5f9",
            surface: "#ffffff",
            text: "#334155",
            border: "#e2e8f0",
            mastered: "#10b981",
            almost: "#64748b",
            learning: "#94a3b8",
            weak: "#78716c",
            new: "#d1d5db"
        ),
        "rainy": ThemeManager.makePreset(
            selection: "#475569",
            background: "#e2e8f0",
            surface: "#f8fafc",
            text: "#1e293b",
            border: "#cbd5e1",
            mastered: "#14b8a6",
            almost: "#3b82f6",
            learning: "#6366f1",
            weak: "#8b5cf6",
            new: "#a1a1aa"
        ),
        "snow": ThemeManager.makePreset(
            selection: "#3b82f6",
            background: "#f9fafb",
            surface: "#ffffff",
            text: "#374151",
            border: "#f1f5f9",
            mastered: "#d1d5db",
            almost: "#e2e8f0",
            learning: "#cbd5e1",
            weak: "#e5e7eb",
            new: "#f3f4f6"
        ),
        "wind": ThemeManager.makePreset(
            selection: "#14b8a6",
            background: "#ecfdf5",
            surface: "#ffffff",
            text: "#065f46",
            border: "#ccfbf1",
            mastered: "#6ee7b7",
            almost: "#a7f3d0",
            learning: "#99f6e4",
            weak: "#fca5a5",
            new: "#d1fae5"
        ),
        "oceanDepth": ThemeManager.makePreset(
            selection: "#0284c7",
            background: "#ecfeff",
            surface: "#ffffff",
            text: "#164e63",
            border: "#bae6fd",
            mastered: "#22d3ee",
            almost: "#38bdf8",
            learning: "#0ea5e9",
            weak: "#f43f5e",
            new: "#94a3b8"
        ),
        "desert": ThemeManager.makePreset(
            selection: "#b45309",
            background: "#fef3c7",
            surface: "#fffbeb",
            text: "#78350f",
            border: "#fde68a",
            mastered: "#fbbf24",
            almost: "#f59e0b",
            learning: "#d97706",
            weak: "#b91c1c",
            new: "#d6d3d1"
        ),
        "skyGrad": ThemeManager.makePreset(
            selection: "#0ea5e9",
            background: "#f0f9ff",
            surface: "#ffffff",
            text: "#0369a1",
            border: "#e0f2fe",
            mastered: "#7dd3fc",
            almost: "#93c5fd",
            learning: "#a5b4fc",
            weak: "#fda4af",
            new: "#cbd5e1"
        ),
        "moonlight": ThemeManager.makePreset(
            selection: "#6366f1",
            background: "#eef2ff",
            surface: "#ffffff",
            text: "#312e81",
            border: "#e0e7ff",
            mastered: "#c4b5fd",
            almost: "#a5b4fc",
            learning: "#818cf8",
            weak: "#f9a8d4",
            new: "#d1d5db"
        ),
        "fog": ThemeManager.makePreset(
            selection: "#6b7280",
            background: "#f4f4f5",
            surface: "#fafafa",
            text: "#52525b",
            border: "#f3f4f6",
            mastered: "#9ca3af",
            almost: "#a1a1aa",
            learning: "#a8a29e",
            weak: "#9ca3af",
            new: "#e5e7eb"
        ),
        "lightning": ThemeManager.makePreset(
            selection: "#eab308",
            background: "#fefce8",
            surface: "#ffffff",
            text: "#422006",
            border: "#fde047",
            mastered: "#facc15",
            almost: "#a855f7",
            learning: "#6366f1",
            weak: "#ef4444",
            new: "#94a3b8"
        ),

        "lastSupper": ThemeManager.makePreset(
            selection: "#8b5a2b",
            background: "#f0e8d8",
            surface: "#faf5e8",
            text: "#3c2f1f",
            border: "#bfad8f",
            mastered: "#8b6f47",
            almost: "#c9a66b",
            learning: "#a08050",
            weak: "#5c3d2e",
            new: "#d4c4a0"
        ),
        "waterLilies": ThemeManager.makePreset(
            selection: "#4a8a7a",
            background: "#e8f4f0",
            surface: "#f5faf8",
            text: "#2a4a3a",
            border: "#a0c0d0",
            mastered: "#7eb37e",
            almost: "#a8c8e8",
            learning: "#90b090",
            weak: "#5a7a5a",
            new: "#c8d8c8"
        ),
        "guernica": ThemeManager.makePreset(
            selection: "#3a3a3a",
            background: "#f0f0f0",
            surface: "#fafafa",
            text: "#1a1a1a",
            border: "#a0a0a0",
            mastered: "#4a4a4a",
            almost: "#808080",
            learning: "#606060",
            weak: "#2a2a2a",
            new: "#c0c0c0"
        ),
        "girlWithPearl": ThemeManager.makePreset(
            selection: "#2a5a7b",
            background: "#e8f0f4",
            surface: "#f5f8fa",
            text: "#1a3040",
            border: "#7a9ab0",
            mastered: "#4a7c9b",
            almost: "#f4d03f",
            learning: "#5a8aab",
            weak: "#2a4a6b",
            new: "#a0b8c8"
        ),
        "nightWatch": ThemeManager.makePreset(
            selection: "#7a5a1a",
            background: "#e8e0c8",
            surface: "#f8f4e8",
            text: "#2a2010",
            border: "#b0944a",
            mastered: "#c9a227",
            almost: "#8b4513",
            learning: "#a67c00",
            weak: "#3c280a",
            new: "#9a8060"
        ),
        "libertyLeading": ThemeManager.makePreset(
            selection: "#2a4a7a",
            background: "#e8eaf0",
            surface: "#f8f8f8",
            text: "#1a2a3a",
            border: "#8a9ab0",
            mastered: "#1a4a8a",
            almost: "#c43c3a",
            learning: "#e8d8a8",
            weak: "#4a2a1a",
            new: "#8a9aaa"
        ),
        "theKiss": ThemeManager.makePreset(
            selection: "#a67c00",
            background: "#f8f0d8",
            surface: "#fffef0",
            text: "#3a2a10",
            border: "#d4c080",
            mastered: "#d4a520",
            almost: "#c9a66b",
            learning: "#b8860b",
            weak: "#6b4423",
            new: "#e8d8a8"
        ),
        "americanGothic": ThemeManager.makePreset(
            selection: "#4a5a3a",
            background: "#e8e8e0",
            surface: "#f8f8f4",
            text: "#2a2a20",
            border: "#a0a090",
            mastered: "#5a6a4a",
            almost: "#8b7355",
            learning: "#707860",
            weak: "#3a3a2a",
            new: "#b8b8a0"
        ),
        "theGleaners": ThemeManager.makePreset(
            selection: "#7a6030",
            background: "#f0e8d8",
            surface: "#faf8f0",
            text: "#3a3020",
            border: "#c0b090",
            mastered: "#c9a66b",
            almost: "#8b7355",
            learning: "#a08050",
            weak: "#5a4a30",
            new: "#d8c8a8"
        ),
        "lasMeninas": ThemeManager.makePreset(
            selection: "#5a4a30",
            background: "#ece4d4",
            surface: "#f8f4ec",
            text: "#2a2418",
            border: "#b8a888",
            mastered: "#8b7355",
            almost: "#c0a080",
            learning: "#a08060",
            weak: "#4a3a2a",
            new: "#d0c0a0"
        ),
        "shepherdess": ThemeManager.makePreset(
            selection: "#5a7a4a",
            background: "#e8f0e0",
            surface: "#f8faf4",
            text: "#2a3a20",
            border: "#a8b898",
            mastered: "#7a9a6a",
            almost: "#c9a66b",
            learning: "#8aaa7a",
            weak: "#4a5a3a",
            new: "#c8d4b8"
        ),
        "ophelia": ThemeManager.makePreset(
            selection: "#4a7a5a",
            background: "#e4ece8",
            surface: "#f4f8f6",
            text: "#1a2a24",
            border: "#90a898",
            mastered: "#5a8a6a",
            almost: "#a08090",
            learning: "#7aaa8a",
            weak: "#3a5a4a",
            new: "#b0c0b8"
        ),
        "bedroomArles": ThemeManager.makePreset(
            selection: "#3a70a0",
            background: "#e8f0f8",
            surface: "#f8fafc",
            text: "#2a3a4a",
            border: "#80a8c8",
            mastered: "#4a90d9",
            almost: "#f4c430",
            learning: "#5aaa5a",
            weak: "#8b4513",
            new: "#a8c8e0"
        ),
        "towerBabel": ThemeManager.makePreset(
            selection: "#6a5030",
            background: "#ece4d0",
            surface: "#f8f4e8",
            text: "#3a3020",
            border: "#b8a888",
            mastered: "#a08060",
            almost: "#c9a66b",
            learning: "#8a7050",
            weak: "#5a4030",
            new: "#c8b8a0"
        ),
        "luncheonBoating": ThemeManager.makePreset(
            selection: "#4a7a9a",
            background: "#e8f0f4",
            surface: "#f8fafb",
            text: "#1a3040",
            border: "#90b0c0",
            mastered: "#5a8aaa",
            almost: "#e8a870",
            learning: "#7aaaca",
            weak: "#3a5a7a",
            new: "#a8c0d0"
        ),
        "grandJatte": ThemeManager.makePreset(
            selection: "#5a8a5a",
            background: "#e8f0e4",
            surface: "#f8faf4",
            text: "#2a3a28",
            border: "#a0b890",
            mastered: "#6a9a6a",
            almost: "#d4a87a",
            learning: "#8aba8a",
            weak: "#4a6a4a",
            new: "#b8c8a8"
        ),

        "cityMorning": ThemeManager.makePreset(
            selection: "#4a90a4",
            background: "#e8f4f8",
            surface: "#f8fafc",
            text: "#2a3a4a",
            border: "#c8d8e4",
            mastered: "#87ceeb",
            almost: "#ffd700",
            learning: "#98d8c8",
            weak: "#708090",
            new: "#b0c4de"
        ),
        "concrete": ThemeManager.makePreset(
            selection: "#5a5a5a",
            background: "#e8e8e8",
            surface: "#f8f8f8",
            text: "#2a2a2a",
            border: "#b0b0b0",
            mastered: "#6a7a6a",
            almost: "#9a9a9a",
            learning: "#808080",
            weak: "#4a4a4a",
            new: "#c0c0c0"
        ),
        "underground": ThemeManager.makePreset(
            selection: "#a08020",
            background: "#e0dcd0",
            surface: "#f8f4ec",
            text: "#3a3428",
            border: "#a09080",
            mastered: "#d4a520",
            almost: "#f0c040",
            learning: "#c09020",
            weak: "#8a6a10",
            new: "#a0a090"
        ),
        "rainyIntersection": ThemeManager.makePreset(
            selection: "#4a6a88",
            background: "#dce4ec",
            surface: "#f0f4f8",
            text: "#2a3a48",
            border: "#8a9aa8",
            mastered: "#4a6a8a",
            almost: "#7a9ab0",
            learning: "#5a7a9a",
            weak: "#3a4a5a",
            new: "#9aaaba"
        ),
        "eveningStation": ThemeManager.makePreset(
            selection: "#d06830",
            background: "#f8e8dc",
            surface: "#fff8f0",
            text: "#3a2a1a",
            border: "#c8a890",
            mastered: "#ff8c42",
            almost: "#ffa560",
            learning: "#e87830",
            weak: "#a05020",
            new: "#b8a090"
        ),
        "officeDistrict": ThemeManager.makePreset(
            selection: "#3a6080",
            background: "#e4ecf4",
            surface: "#f6f8fa",
            text: "#1a2838",
            border: "#88a0b0",
            mastered: "#4a7090",
            almost: "#6890a8",
            learning: "#5a80a0",
            weak: "#3a5070",
            new: "#98b0c0"
        ),
        "redevelopment": ThemeManager.makePreset(
            selection: "#3a80b0",
            background: "#e8ecf0",
            surface: "#f8f8fa",
            text: "#2a3a48",
            border: "#90a0b0",
            mastered: "#ff7f50",
            almost: "#4a90c0",
            learning: "#90b0c0",
            weak: "#4a5a6a",
            new: "#a8b8c8"
        ),
        "oldTown": ThemeManager.makePreset(
            selection: "#6a5a40",
            background: "#ece4d8",
            surface: "#faf6f0",
            text: "#3a3020",
            border: "#b8a890",
            mastered: "#8b7355",
            almost: "#a08060",
            learning: "#9a7a5a",
            weak: "#5a4a3a",
            new: "#c8b8a0"
        ),
        "backAlley": ThemeManager.makePreset(
            selection: "#4a6a40",
            background: "#e0e4d8",
            surface: "#f4f6f0",
            text: "#2a3020",
            border: "#909880",
            mastered: "#6a8a5a",
            almost: "#a09080",
            learning: "#7a9a6a",
            weak: "#3a4a30",
            new: "#a0a890"
        ),
        "rooftop": ThemeManager.makePreset(
            selection: "#4a90b0",
            background: "#e4f0f8",
            surface: "#f8fcff",
            text: "#1a3040",
            border: "#a0c0d0",
            mastered: "#87ceeb",
            almost: "#f0e68c",
            learning: "#98d8e8",
            weak: "#5a7a8a",
            new: "#b8d0e0"
        ),
        "underElevated": ThemeManager.makePreset(
            selection: "#5a6a50",
            background: "#e0e4dc",
            surface: "#f4f6f0",
            text: "#2a3428",
            border: "#a0a898",
            mastered: "#7a8a6a",
            almost: "#9a9a8a",
            learning: "#8a9a7a",
            weak: "#4a5a4a",
            new: "#b0b8a8"
        ),
        "downtown": ThemeManager.makePreset(
            selection: "#e04080",
            background: "#ece8f0",
            surface: "#f8f8fc",
            text: "#2a2a3a",
            border: "#8080a0",
            mastered: "#ff6b6b",
            almost: "#ffd93d",
            learning: "#4ecdc4",
            weak: "#c44569",
            new: "#a0a0b0"
        ),
        "lateNight": ThemeManager.makePreset(
            selection: "#3a5068",
            background: "#0c1020",
            surface: "#1a2030",
            text: "#c8d0e0",
            border: "#506070",
            mastered: "#4a6080",
            almost: "#6a8090",
            learning: "#5a7088",
            weak: "#2a3a48",
            new: "#7888a0",
            isDarkBase: true
        ),
        "trafficSign": ThemeManager.makePreset(
            selection: "#0080c0",
            background: "#eaeaea",
            surface: "#f8f8f8",
            text: "#1a1a1a",
            border: "#a0a0a0",
            mastered: "#00a550",
            almost: "#ffd700",
            learning: "#ff6b00",
            weak: "#e02020",
            new: "#808080"
        ),
        "cityOutline": ThemeManager.makePreset(
            selection: "#4a6080",
            background: "#e0e8f0",
            surface: "#f4f8fc",
            text: "#1a2a38",
            border: "#90a0b0",
            mastered: "#5a7090",
            almost: "#8aa0b0",
            learning: "#7090a8",
            weak: "#3a4a5a",
            new: "#a0b0c0"
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
        case "monaLisa": return "モナ・リザ"
        case "starryNight": return "星月夜"
        case "sunflowers": return "ひまわり"
        case "theScream": return "叫び"
        case "rushHour": return "通勤ラッシュ"
        case "skyscrapers": return "高層ビル群"
        case "glassCity": return "ガラス張りの街"
        case "neonStreet": return "ネオン街"
        case "nightView": return "夜景"
        case "midnight": return "ミッドナイト"
        case "fugaku36": return "富嶽三十六景"
        case "nature": return "自然"
        case "travel": return "旅行"
        case "tunnel": return "トンネルドライブ"
        case "circle": return "Circle"
        case "fugaku": return "富嶽"
        case "image1": return "画像 1"
        case "image5": return "画像 5"
        case "img1136": return "IMG 1136"
        case "img1136_2": return "IMG 1136-2"
        case "img1834": return "IMG 1834"
        case "img2815": return "IMG 2815"
        case "img2815_2": return "IMG 2815-2"
        case "img2815_3": return "IMG 2815-3"
        case "greenForest": return "フォレストグリーン"
        case "pinkNoir": return "ピンクノワール"
        case "sunshine": return "サンシャイン"
        case "lavenderDream": return "ラベンダードリーム"
        case "coffeeBreak": return "コーヒーブレイク"
        case "retroGaming": return "レトロゲーミング"
        case "spring": return "春・淡色"
        case "summer": return "夏・高彩度"
        case "autumn": return "秋・深色"
        case "winter": return "冬・低彩度"
        case "morning": return "朝・白寄り"
        case "noon": return "昼・高明度"
        case "dusk": return "夕・暖色"
        case "clearSky": return "晴天"
        case "cloudy": return "曇天・ソフト"
        case "rainy": return "雨天・低明度"
        case "snow": return "雪原・ハイキー"
        case "wind": return "風通し"
        case "oceanDepth": return "海・深度"
        case "desert": return "砂漠・乾色"
        case "skyGrad": return "空・グラデ"
        case "moonlight": return "月光・寒色"
        case "fog": return "霧・低コントラスト"
        case "lightning": return "雷・アクセント"
        case "lastSupper": return "最後の晩餐"
        case "waterLilies": return "睡蓮"
        case "guernica": return "ゲルニカ"
        case "girlWithPearl": return "真珠の耳飾りの少女"
        case "nightWatch": return "夜警"
        case "libertyLeading": return "民衆を導く自由の女神"
        case "theKiss": return "接吻"
        case "americanGothic": return "アメリカン・ゴシック"
        case "theGleaners": return "落穂拾い"
        case "lasMeninas": return "ラス・メニーナス"
        case "shepherdess": return "羊飼いの少女"
        case "ophelia": return "オフィーリア"
        case "bedroomArles": return "アルルの寝室"
        case "towerBabel": return "バベルの塔"
        case "luncheonBoating": return "舟遊びの昼食"
        case "grandJatte": return "グランド・ジャット島の日曜日"
        case "cityMorning": return "都心の朝"
        case "concrete": return "コンクリート"
        case "underground": return "地下通路"
        case "rainyIntersection": return "雨の交差点"
        case "eveningStation": return "夕方の駅前"
        case "officeDistrict": return "オフィス街"
        case "redevelopment": return "再開発地区"
        case "oldTown": return "旧市街"
        case "backAlley": return "路地裏"
        case "rooftop": return "屋上"
        case "underElevated": return "高架下"
        case "downtown": return "繁華街"
        case "lateNight": return "無人の深夜"
        case "trafficSign": return "交通標識"
        case "cityOutline": return "都市の輪郭"
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
