import SwiftUI

#if os(iOS)
import UIKit
#endif

private extension Color {
    func toHexString() -> String {
        #if os(iOS)
            let ui = UIColor(self)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(
                format: "#%02X%02X%02X",
                Int(r * 255.0),
                Int(g * 255.0),
                Int(b * 255.0)
            )
        #else
            return "#000000"
        #endif
    }
}

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 170), spacing: 16)
    ]

    init() {}

    var body: some View {
        ZStack {
            ThemeManager.shared.background

            ScrollView {
                VStack(spacing: 24) {
                    // Preview Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("プレビュー")
                            .font(.caption)
                            .foregroundColor(themeManager.color(.secondary, scheme: colorScheme))
                            .padding(.horizontal)

                        ThemePreviewCard()
                            .padding(.horizontal)
                    }

                    // Theme Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("テーマを選択")
                            .font(.caption)
                            .foregroundColor(themeManager.color(.secondary, scheme: colorScheme))
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(themeManager.availableThemes, id: \.self) { themeId in
                                ThemeSelectionCard(
                                    themeId: themeId,
                                    isSelected: themeManager.selectedThemeId == themeId
                                )
                                .onTapGesture {
                                    withAnimation {
                                        themeManager.applyTheme(id: themeId)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Customization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("カスタマイズ")
                            .font(.caption)
                            .foregroundColor(themeManager.color(.secondary, scheme: colorScheme))
                            .padding(.horizontal)

                        Toggle(isOn: $themeManager.useLiquidGlass) {
                            Label("Liquid Glass（コンテナ背景）", systemImage: "sparkles")
                                .foregroundColor(themeManager.color(.text, scheme: colorScheme))
                        }
                        .padding()
                        .liquidGlass()
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            HStack {
                                Label("外観", systemImage: "circle.lefthalf.filled")
                                    .foregroundColor(themeManager.color(.text, scheme: colorScheme))
                                Spacer()
                            }

                            Picker("外観", selection: $themeManager.colorSchemeOverride) {
                                Text("システム").tag(0)
                                Text("ライト").tag(1)
                                Text("ダーク").tag(2)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                        .liquidGlass()
                        .padding(.horizontal)

                        NavigationLink(destination: WallpaperGalleryView()) {
                            HStack {
                                Label("壁紙", systemImage: "photo.on.rectangle")
                                    .foregroundColor(themeManager.color(.text, scheme: colorScheme))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(themeManager.color(.secondary, scheme: colorScheme))
                            }
                            .padding()
                            .liquidGlass()
                        }
                        .padding(.horizontal)

                        NavigationLink(destination: MasteryColorEditorView()) {
                            HStack {
                                Label("習熟度カラーを編集", systemImage: "paintbrush.fill")
                                    .foregroundColor(themeManager.color(.text, scheme: colorScheme))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(themeManager.color(.secondary, scheme: colorScheme))
                            }
                            .padding()
                            .liquidGlass()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("テーマ設定")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ThemePreviewCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Circle()
                    .fill(themeManager.color(.primary, scheme: colorScheme))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(
                                themeManager.onColor(for: themeManager.color(.primary, scheme: colorScheme))
                            )
                    )

                VStack(alignment: .leading) {
                    Text(themeManager.getThemeName(themeManager.selectedThemeId))
                        .font(.headline)
                        .foregroundColor(themeManager.color(.text, scheme: colorScheme))
                    Text("現在のテーマ")
                        .font(.caption)
                        .foregroundColor(themeManager.color(.secondary, scheme: colorScheme))
                }
                Spacer()
            }

            HStack(spacing: 12) {
                ColorCapsule(color: themeManager.color(.mastered, scheme: colorScheme), text: "覚えた")
                ColorCapsule(color: themeManager.color(.learning, scheme: colorScheme), text: "学習中")
                ColorCapsule(color: themeManager.color(.weak, scheme: colorScheme), text: "苦手")
            }
        }
        .padding()
        .background(themeManager.color(.surface, scheme: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.color(.border, scheme: colorScheme), lineWidth: 1)
        )
    }
}

struct ColorCapsule: View {
    let color: Color
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct ThemeSelectionCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    let themeId: String
    let isSelected: Bool

    // Create a temporary palette instance for preview to avoid changing global state
    // Note: In a real app we might want a static lookup or just use the manager if it exposes a way to look up without setting.
    // ThemeManager exposes presets, but they are private. I'll make them accessible or just use applyTheme logic.
    // Actually, ThemeManager has `presets` private. I should make it internal or have a helper.
    // For now, I will modify ThemeManager to make presets internal or add a helper `palette(for: id)`.
    // Assuming helper exists or I fix it. I will use a placeholder logic assuming I can get colors.

    var body: some View {
        // We need to access the palette for this specific themeId BEFORE selecting it.
        // I'll update ThemeManager to expose a helper function `palette(for:)`.
        // For now, I'll rely on ThemeManager having `getPalette(id: String) -> ThemePalette?`.

        let palette = themeManager.getPalette(id: themeId)
        let isDark = colorScheme == .dark
        let primary = Color(
            hex: palette?.hexString(for: .primary, isDark: colorScheme == .dark)
                ?? themeManager.color(.primary, scheme: colorScheme).toHexString()
        )
        let accent = Color(
            hex: palette?.hexString(for: .accent, isDark: isDark)
                ?? themeManager.color(.accent, scheme: colorScheme).toHexString()
        )
        let mastered = Color(
            hex: palette?.hexString(for: .mastered, isDark: isDark)
                ?? themeManager.color(.mastered, scheme: colorScheme).toHexString()
        )
        let learning = Color(
            hex: palette?.hexString(for: .learning, isDark: isDark)
                ?? themeManager.color(.learning, scheme: colorScheme).toHexString()
        )
        let weak = Color(
            hex: palette?.hexString(for: .weak, isDark: isDark)
                ?? themeManager.color(.weak, scheme: colorScheme).toHexString()
        )
        let newColor = Color(
            hex: palette?.hexString(for: .new, isDark: isDark)
                ?? themeManager.color(.new, scheme: colorScheme).toHexString()
        )
        let bg = Color(
            hex: palette?.hexString(for: .surface, isDark: colorScheme == .dark)
                ?? themeManager.color(.surface, scheme: colorScheme).toHexString()
        )
        let text = Color(
            hex: palette?.hexString(for: .text, isDark: colorScheme == .dark)
                ?? themeManager.color(.text, scheme: colorScheme).toHexString()
        )

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading) {
                HStack(spacing: 8) {
                    Circle().fill(primary).frame(width: 20, height: 20)
                    Spacer()
                }
                .padding(.bottom, 8)

                HStack(spacing: 6) {
                    Circle().fill(accent).frame(width: 10, height: 10)
                    Circle().fill(mastered).frame(width: 10, height: 10)
                    Circle().fill(learning).frame(width: 10, height: 10)
                    Circle().fill(weak).frame(width: 10, height: 10)
                    Circle().fill(newColor).frame(width: 10, height: 10)
                    Spacer()
                }
                .padding(.bottom, 6)

                Text(themeManager.getThemeName(themeId))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(text)
                    .lineLimit(1)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? primary : Color.clear, lineWidth: 2)
            )

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(primary)
                    .padding(8)
            }
        }
    }
}
