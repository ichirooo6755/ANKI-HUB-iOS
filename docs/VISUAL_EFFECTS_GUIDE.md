# ビジュアルエフェクトガイド

## 概要

ANKI-HUB-iOSは、参考画像のような高度なビジュアルエフェクトシステムを搭載しています：

1. **サイバーパンク風**: グリッド + データポイント + 波形エフェクト
2. **カードスタック**: カラフルなカード重ねエフェクト（交通系ICカード風）
3. **ヘルスアプリ風**: グラフアニメーション + メトリクス表示

## エフェクトスタイル

### 1. サイバーパンク（Cyberpunk）

テクニカルで未来的なデザイン。

**特徴:**
- グリッドオーバーレイ
- アニメーションするデータポイント
- 波形エフェクト
- ネオングロー

**推奨テーマ:**
- cyberpunk
- neonLime
- neonStreet

**使用例:**
```swift
VStack {
    Text("データ")
}
.cyberpunkCard()
```

### 2. カードスタック（Card Stack）

カラフルで楽しいデザイン。交通系ICカードのような鮮やかな色使い。

**特徴:**
- 複数カードの重ねエフェクト
- 斜めストライプパターン
- グラデーション背景
- 色相回転アニメーション

**推奨テーマ:**
- default
- ocean
- forest
- sunset

**使用例:**
```swift
VStack {
    Text("学習カード")
}
.colorfulCard(color: .green, animated: true)
```

### 3. ヘルスアプリ（Health App）

Apple Healthアプリのような洗練されたデザイン。

**特徴:**
- アニメーションするプログレスリング
- ラインチャート
- メトリクスカード
- ストリークインジケーター

**推奨テーマ:**
- すべてのテーマ（デフォルト）

**使用例:**
```swift
HealthMetricCard(
    title: "学習時間",
    value: "45",
    unit: "分",
    icon: "clock.fill",
    color: .orange,
    progress: 0.75
)
```

## 設定方法

### 1. エフェクトを有効化

1. プロフィール画面を開く
2. 「ビジュアルエフェクト」をタップ
3. 「エフェクトを有効化」をオンにする

### 2. スタイルを選択

**自動選択（推奨）:**
- テーマに応じて最適なスタイルを自動選択

**手動選択:**
- サイバーパンク
- カードスタック
- ヘルスアプリ
- ミニマル

### 3. 詳細設定

**アニメーション強度:**
- 50% - 200%の範囲で調整
- デフォルト: 100%

**個別エフェクト:**
- パーティクルエフェクト
- グリッドオーバーレイ
- 波形エフェクト

## 開発者向け

### カスタムビューにエフェクトを適用

```swift
import SwiftUI

struct MyCustomView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var effects = VisualEffectsManager.shared
    
    var body: some View {
        VStack {
            Text("カスタムコンテンツ")
        }
        .enhancedCard(accentColor: theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
        .adaptiveVisualEffect(enableOverlay: true)
    }
}
```

### 利用可能なモディファイア

#### 1. enhancedCard
現在のエフェクトスタイルに応じてカードを装飾

```swift
.enhancedCard(accentColor: .blue)
```

#### 2. adaptiveVisualEffect
背景オーバーレイエフェクトを追加

```swift
.adaptiveVisualEffect(enableOverlay: true)
```

#### 3. cyberpunkCard
サイバーパンクスタイルのカード

```swift
.cyberpunkCard()
```

#### 4. colorfulCard
カラフルなカードスタック風

```swift
.colorfulCard(color: .green, animated: true)
```

#### 5. shimmer
シマーエフェクト

```swift
.shimmer(duration: 2.0, bounce: false)
```

#### 6. pulse
パルスエフェクト

```swift
.pulse(minScale: 1.0, maxScale: 1.05, duration: 1.0)
```

#### 7. glow
グローエフェクト

```swift
.glow(color: .cyan, radius: 10)
```

### カスタムコンポーネント

#### CelebrationEffect
お祝いエフェクト

```swift
CelebrationEffect(type: .confetti, color: .yellow)
```

#### ActivityRing
アクティビティリング

```swift
ActivityRing(progress: 0.75, color: .green, lineWidth: 12)
```

#### AnimatedLineChart
アニメーションするラインチャート

```swift
let data = [
    ChartDataPoint(value: 10, normalizedValue: 0.2),
    ChartDataPoint(value: 25, normalizedValue: 0.5),
    ChartDataPoint(value: 40, normalizedValue: 0.8)
]

AnimatedLineChart(data: data, color: .blue, showGradient: true)
```

#### StreakIndicator
ストリークインジケーター

```swift
StreakIndicator(days: 7, color: .orange)
```

## パフォーマンス最適化

### バッテリー消費

エフェクトシステムは以下の最適化を実装しています：

1. **レイヤー最適化**: 必要最小限のレイヤーのみ使用
2. **アニメーション制御**: 画面外では自動停止
3. **GPU加速**: Core Animationを活用
4. **条件付きレンダリング**: 設定に応じて動的に調整

### 推奨設定

**高性能デバイス（iPhone 14 Pro以降）:**
- アニメーション強度: 100-150%
- すべてのエフェクト有効

**標準デバイス（iPhone 12-13）:**
- アニメーション強度: 75-100%
- 必要なエフェクトのみ有効

**省電力モード:**
- アニメーション強度: 50-75%
- パーティクルとグリッドを無効化

## トラブルシューティング

### エフェクトが表示されない

1. 「エフェクトを有効化」がオンになっているか確認
2. アプリを再起動
3. iOS 17.0以降であることを確認

### アニメーションがカクつく

1. アニメーション強度を下げる（50-75%）
2. パーティクルエフェクトを無効化
3. バックグラウンドアプリを終了

### バッテリー消費が気になる

1. 「ミニマル」スタイルに変更
2. グリッドオーバーレイを無効化
3. アニメーション強度を50%に設定

## 今後の予定

- [ ] カスタムパーティクルシステム
- [ ] 3Dエフェクト
- [ ] インタラクティブアニメーション
- [ ] ユーザー定義エフェクト
- [ ] エフェクトプリセット共有

## フィードバック

ビジュアルエフェクトに関するフィードバックは、GitHubのIssuesまでお願いします。
