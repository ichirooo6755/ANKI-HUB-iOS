import SwiftUI

#if canImport(WidgetKit)
    import WidgetKit
#endif

/// テーマ・壁紙・エフェクト・ウィジェットを1か所に集約（統合 D）
struct DisplaySettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            themeManager.background

            List {
                Section("外観モード") {
                    Picker("外観", selection: $themeManager.colorSchemeOverride) {
                        Text("システム").tag(0)
                        Text("ライト").tag(1)
                        Text("ダーク").tag(2)
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: $themeManager.useLiquidGlass) {
                        Text("Liquid Glass（コンテナ背景）")
                    }

                    Picker("カードスタイル", selection: $themeManager.widgetCardStyle) {
                        Text("Soft").tag("soft")
                        Text("Outline").tag("outline")
                        Text("Neo").tag("neo")
                    }
                    .pickerStyle(.segmented)
                }

                Section("テーマ・壁紙") {
                    NavigationLink {
                        ThemeSettingsView()
                            .environmentObject(themeManager)
                    } label: {
                        Label("テーマカラー", systemImage: "paintpalette.fill")
                    }

                    NavigationLink {
                        WallpaperGalleryView()
                    } label: {
                        Label("壁紙", systemImage: "photo.on.rectangle.angled")
                    }

                    NavigationLink {
                        MasteryColorEditorView()
                    } label: {
                        Label("習熟度カラー", systemImage: "circle.lefthalf.filled")
                    }
                }

                Section("ビジュアルエフェクト") {
                    NavigationLink {
                        VisualEffectsSettingsView()
                    } label: {
                        Label("エフェクト設定", systemImage: "sparkles")
                    }
                }

                Section("ウィジェット") {
                    NavigationLink {
                        WidgetSettingsView()
                            .environmentObject(themeManager)
                    } label: {
                        Label("ウィジェット", systemImage: "square.grid.2x2.fill")
                    }

                    NavigationLink {
                        LockScreenMirrorGuideView()
                    } label: {
                        Label("ロック画面ミラー", systemImage: "camera.viewfinder")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(themeManager.color(.surface, scheme: colorScheme))
            #if os(iOS)
                .listStyle(.insetGrouped)
            #endif
        }
        .navigationTitle("表示")
        .applyAppTheme()
    }
}
