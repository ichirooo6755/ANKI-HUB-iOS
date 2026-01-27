import SwiftUI
import Combine

// MARK: - Visual Effects Manager
/// 参考画像のような高度なビジュアルエフェクトを管理
/// 1. サイバーパンク風グリッド + データポイント
/// 2. カラフルなカードスタック
/// 3. ヘルスアプリ風グラフアニメーション

class VisualEffectsManager: ObservableObject {
    static let shared = VisualEffectsManager()
    
    @Published var effectsEnabled: Bool = true
    @Published var currentStyle: VisualEffectStyle = .adaptive
    @Published var animationIntensity: Float = 1.0
    @Published var particlesEnabled: Bool = true
    @Published var gridOverlayEnabled: Bool = false
    @Published var waveEffectsEnabled: Bool = true
    
    private init() {
        loadPreferences()
    }
    
    private func loadPreferences() {
        effectsEnabled = UserDefaults.standard.bool(forKey: "visual_effects_enabled")
        if let styleRaw = UserDefaults.standard.string(forKey: "visual_effect_style"),
           let style = VisualEffectStyle(rawValue: styleRaw) {
            currentStyle = style
        }
        animationIntensity = UserDefaults.standard.float(forKey: "animation_intensity")
        if animationIntensity == 0 { animationIntensity = 1.0 }
        particlesEnabled = UserDefaults.standard.bool(forKey: "particles_enabled")
        gridOverlayEnabled = UserDefaults.standard.bool(forKey: "grid_overlay_enabled")
        waveEffectsEnabled = UserDefaults.standard.bool(forKey: "wave_effects_enabled")
    }
    
    func savePreferences() {
        UserDefaults.standard.set(effectsEnabled, forKey: "visual_effects_enabled")
        UserDefaults.standard.set(currentStyle.rawValue, forKey: "visual_effect_style")
        UserDefaults.standard.set(animationIntensity, forKey: "animation_intensity")
        UserDefaults.standard.set(particlesEnabled, forKey: "particles_enabled")
        UserDefaults.standard.set(gridOverlayEnabled, forKey: "grid_overlay_enabled")
        UserDefaults.standard.set(waveEffectsEnabled, forKey: "wave_effects_enabled")
    }
    
    func getStyleForTheme(_ themeId: String) -> VisualEffectStyle {
        if currentStyle != .adaptive {
            return currentStyle
        }
        
        // テーマに応じて自動選択
        switch themeId {
        case "cyberpunk", "neonLime", "neonStreet":
            return .cyberpunk
        case "default", "ocean", "forest", "sunset":
            return .healthApp
        default:
            return .cardStack
        }
    }
}
