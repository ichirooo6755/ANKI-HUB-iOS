import SwiftUI

struct VisualEffectsSettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var effects = VisualEffectsManager.shared
    
    @State private var showPreview = false
    @State private var showCelebration = false
    
    var body: some View {
        ZStack {
            theme.background
            
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    headerSection
                    
                    // メインスイッチ
                    mainToggleSection
                    
                    // スタイル選択
                    if effects.effectsEnabled {
                        styleSelectionSection
                        
                        // 詳細設定
                        detailSettingsSection
                        
                        // プレビュー
                        previewSection
                    }
                }
                .padding()
            }
            
            // お祝いエフェクト
            if showCelebration {
                CelebrationEffect(type: .confetti, color: .yellow)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCelebration = false
                        }
                    }
            }
        }
        .navigationTitle("ビジュアルエフェクト")
        .applyAppTheme()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark),
                            theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shimmer(duration: 3.0)
            
            Text("高度なビジュアルエフェクト")
                .font(.title2.bold())
                .foregroundStyle(theme.primaryText)
            
            Text("サイバーパンク、カードスタック、ヘルスアプリ風のエフェクトを有効化")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .liquidGlass()
    }
    
    // MARK: - Main Toggle Section
    
    private var mainToggleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $effects.effectsEnabled) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                        .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("エフェクトを有効化")
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)
                        
                        Text("すべてのビジュアルエフェクトのオン/オフ")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
            .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
            .onChange(of: effects.effectsEnabled) { _, newValue in
                effects.savePreferences()
                if newValue {
                    showCelebration = true
                }
            }
        }
        .padding()
        .liquidGlass()
    }
    
    // MARK: - Style Selection Section
    
    private var styleSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("エフェクトスタイル")
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            
            ForEach(VisualEffectStyle.allCases) { style in
                styleCard(for: style)
            }
        }
        .padding()
        .liquidGlass()
    }
    
    private func styleCard(for style: VisualEffectStyle) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                effects.currentStyle = style
                effects.savePreferences()
            }
        } label: {
            HStack(spacing: 16) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(styleColor(for: style).opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: styleIcon(for: style))
                        .font(.title3)
                        .foregroundStyle(styleColor(for: style))
                }
                
                // 説明
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.displayName)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                    
                    Text(style.description)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 選択インジケーター
                if effects.currentStyle == style {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(styleColor(for: style))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        effects.currentStyle == style
                        ? styleColor(for: style).opacity(0.1)
                        : theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark).opacity(0.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        effects.currentStyle == style
                        ? styleColor(for: style).opacity(0.5)
                        : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func styleIcon(for style: VisualEffectStyle) -> String {
        switch style {
        case .adaptive: return "sparkles"
        case .cyberpunk: return "grid"
        case .cardStack: return "square.stack.3d.up"
        case .healthApp: return "chart.line.uptrend.xyaxis"
        case .minimal: return "circle"
        }
    }
    
    private func styleColor(for style: VisualEffectStyle) -> Color {
        switch style {
        case .adaptive: return .purple
        case .cyberpunk: return .cyan
        case .cardStack: return Color(hex: "#B7FF1A")
        case .healthApp: return .orange
        case .minimal: return .gray
        }
    }
    
    // MARK: - Detail Settings Section
    
    private var detailSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("詳細設定")
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            
            // アニメーション強度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("アニメーション強度")
                        .font(.subheadline)
                        .foregroundStyle(theme.primaryText)
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", effects.animationIntensity * 100))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(theme.secondaryText)
                }
                
                Slider(value: $effects.animationIntensity, in: 0.5...2.0, step: 0.1)
                    .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    .onChange(of: effects.animationIntensity) { _, _ in
                        effects.savePreferences()
                    }
            }
            
            Divider()
            
            // パーティクル
            Toggle(isOn: $effects.particlesEnabled) {
                HStack {
                    Image(systemName: "sparkle")
                        .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    Text("パーティクルエフェクト")
                        .foregroundStyle(theme.primaryText)
                }
            }
            .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
            .onChange(of: effects.particlesEnabled) { _, _ in
                effects.savePreferences()
            }
            
            // グリッドオーバーレイ
            Toggle(isOn: $effects.gridOverlayEnabled) {
                HStack {
                    Image(systemName: "grid")
                        .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    Text("グリッドオーバーレイ")
                        .foregroundStyle(theme.primaryText)
                }
            }
            .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
            .onChange(of: effects.gridOverlayEnabled) { _, _ in
                effects.savePreferences()
            }
            
            // 波形エフェクト
            Toggle(isOn: $effects.waveEffectsEnabled) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                    Text("波形エフェクト")
                        .foregroundStyle(theme.primaryText)
                }
            }
            .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
            .onChange(of: effects.waveEffectsEnabled) { _, _ in
                effects.savePreferences()
            }
        }
        .padding()
        .liquidGlass()
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("プレビュー")
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            
            Button {
                withAnimation {
                    showPreview.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "eye")
                    Text(showPreview ? "プレビューを隠す" : "プレビューを表示")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                )
                .foregroundStyle(.white)
            }
            
            if showPreview {
                previewContent
            }
        }
        .padding()
        .liquidGlass()
    }
    
    private var previewContent: some View {
        VStack(spacing: 16) {
            // スタイルに応じたプレビュー
            let effectiveStyle = effects.getStyleForTheme(theme.selectedThemeId)
            switch effectiveStyle {
            case .cyberpunk:
                cyberpunkPreview
            case .cardStack:
                cardStackPreview
            case .healthApp:
                healthAppPreview
            case .minimal, .adaptive:
                minimalPreview
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.currentPalette.color(.background, isDark: theme.effectiveIsDark).opacity(0.5))
        )
    }
    
    private var cyberpunkPreview: some View {
        VStack(spacing: 12) {
            Text("Cyberpunk Style")
                .font(.headline)
                .foregroundStyle(.cyan)
            
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .frame(height: 150)
                
                if effects.gridOverlayEnabled {
                    CyberpunkGridOverlay(intensity: effects.animationIntensity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .cyberpunkCard()
        }
    }
    
    private var cardStackPreview: some View {
        VStack(spacing: 12) {
            Text("Card Stack Style")
                .font(.headline)
                .foregroundStyle(Color(hex: "#B7FF1A"))
            
            ZStack {
                CardStackEffect(
                    colors: [
                        Color(hex: "#B7FF1A"),
                        Color(hex: "#FF6B6B"),
                        Color(hex: "#4ECDC4")
                    ],
                    rotation: 3,
                    offset: CGSize(width: 6, height: 6)
                )
            }
            .frame(height: 150)
        }
    }
    
    private var healthAppPreview: some View {
        VStack(spacing: 12) {
            Text("Health App Style")
                .font(.headline)
                .foregroundStyle(.orange)
            
            HStack(spacing: 12) {
                HealthMetricCard(
                    title: "学習時間",
                    value: "45",
                    unit: "分",
                    icon: "clock.fill",
                    color: .orange,
                    progress: 0.75
                )
                
                HealthMetricCard(
                    title: "習得語彙",
                    value: "120",
                    unit: "語",
                    icon: "checkmark.seal.fill",
                    color: .green,
                    progress: 0.6
                )
            }
        }
    }
    
    private var minimalPreview: some View {
        VStack(spacing: 12) {
            Text("Minimal Style")
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            
            Text("シンプルなエフェクトのみ")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .padding()
                .liquidGlass()
        }
    }
}

#Preview {
    NavigationStack {
        VisualEffectsSettingsView()
    }
}
