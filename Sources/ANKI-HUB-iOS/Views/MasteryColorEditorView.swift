import SwiftUI

struct MasteryColorEditorView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var newColor: Color = .gray
    @State private var weakColor: Color = .red
    @State private var learningColor: Color = .orange
    @State private var almostColor: Color = .blue
    @State private var masteredColor: Color = .green
    
    var body: some View {
        List {
            Section("習熟度カラー") {
                ColorPicker("未学習", selection: $newColor)
                ColorPicker("苦手", selection: $weakColor)
                ColorPicker("うろ覚え", selection: $learningColor)
                ColorPicker("ほぼ覚えた", selection: $almostColor)
                ColorPicker("覚えた", selection: $masteredColor)
            }
            
            Section {
                Button("プレビュー") {
                    // Preview colors
                }
                .foregroundColor(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
            }
            
            Section {
                Button("デフォルトに戻す") {
                    let palette = theme.currentPalette
                    newColor = Color(hex: palette.new)
                    weakColor = Color(hex: palette.weak)
                    learningColor = Color(hex: palette.learning)
                    almostColor = Color(hex: palette.almost)
                    masteredColor = Color(hex: palette.mastered)
                }
                .foregroundColor(theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark))
            }
        }
        .navigationTitle("カラーエディター")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    ThemeManager.shared.applyMasteryColors(
                        new: newColor,
                        weak: weakColor,
                        learning: learningColor,
                        almost: almostColor,
                        mastered: masteredColor
                    )
                }
            }
        }
        .onAppear {
            let palette = ThemeManager.shared.currentPalette
            newColor = Color(hex: palette.new)
            weakColor = Color(hex: palette.weak)
            learningColor = Color(hex: palette.learning)
            almostColor = Color(hex: palette.almost)
            masteredColor = Color(hex: palette.mastered)
        }
    }
}

// Previews removed for SPM
