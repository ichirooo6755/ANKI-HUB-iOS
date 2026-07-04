# ANKI-HUB-iOS 要件・実装条件

> **更新日**: 2026-07-05  
> このファイルはユーザー要求と実装状態を毎回ここに集約する。作業前に必ず更新すること。

---

## 1. ユーザー要求（2026-07-05）

| # | 要求 | 優先度 | 状態 |
|---|------|--------|------|
| R1 | ダーク/ライト混在・コントラスト不足・白コンテナだけ浮く問題の色見直し | P0 | 🔄 進行中 |
| R2 | 壁紙機能の完成（選択→反映→テーマ連動→リセット） | P0 | 🔄 進行中 |
| R3 | ホーム最上部「今日の学習」を横スクロール列（集中タイマー等）に統合。下スクロールで各機能へ | P0 | 🔄 進行中 |
| R4 | ウィジェット実装の明確化（何が動く/動かない、実機同梱条件） | P1 | 📋 文書化 |
| R5 | Googleログイン復旧（Supabase DB 再構築含む） | P0 | 🔄 schema 追加 |
| R6 | 機能しないボタン/ウィジェットの調査・修正（勉強スタート、タイムライン、ToDo等） | P0 | 🔄 進行中 |
| R7 | 3アマ等の長文問題文の見切れ修正（集中暗記等） | P0 | 🔄 進行中 |
| R8 | スキャン→OCR→問題/答え領域選択→自動問題集→教科/チャプター整理 | P1 | ✅ 初版（統合C） |
| R9 | 統合候補機能の整理（ユーザーが統合可否を判断） | P1 | ✅ A-D 実施済 |
| R10 | 3アマチャプターから「間違い」仮想チャプター削除、法規/工学表記修正 | P0 | ✅ 完了 |
| R11 | 英検科目の記載削除（未実装のため） | P1 | ✅ 完了 |

---

## 2. 実装条件（共通）

### 2.1 テーマ・色

- **単一の明暗判定**: `ThemeManager.effectiveIsDark` を全 UI で使用。`.secondary` / `.primary` 等のシステム色は使わない。
- **カード面**: `surface` + `primaryText` / `secondaryText`。壁紙 ON 時は `.ultraThinMaterial` を併用可。
- **壁紙**: `wallpaperEnabled` + `wallpaperKind`（bundle / photo / solid / gradient）。適用時に `wallpaperEnabled = true`。リセットで両方クリア。
- **App Group**: `group.com.ankihub.ios`

### 2.2 ホーム UI

- 伸びるヒーローヘッダー（DashboardHeroHeader の pull stretch）は使わない。
- 機能ショートカットは `HeroCarouselView` の横スクロール 1 列に集約。
- 各カードタップ → `NavigationStack` の `navigationDestination` で遷移。

### 2.3 ウィジェット

| 項目 | 条件 |
|------|------|
| 実機 Debug | ウィジェット拡張同梱 OFF（`com.ankihub.ios.widget` コンテナ作成エラー回避） |
| 本体機能 | クイズ・学習・3アマは本体のみで利用可 |
| ウィジェット単体開発 | スキーム `ANKI-HUB-iOS-Widget` |
| 同梱復帰 | Developer Portal で App Groups 有効化後、Embed 復元 |

### 2.4 認証・DB（Supabase）

- プロジェクト: `https://uahrjcauawtftpecpxsq.supabase.co`
- リダイレクト: `sugwranki://login-callback`（Info.plist 登録済み）
- **DB 再構築**: `docs/supabase/schema.sql` を SQL Editor で実行
- **Supabase Dashboard 設定**:
  - Authentication → URL Configuration → Redirect URLs に `sugwranki://login-callback` 追加
  - Authentication → Providers → Google 有効化
  - Google Cloud Console → OAuth クライアントに iOS バンドル ID `com.ankihub.ios`

### 2.5 ビルド

- iOS 17.0+, Xcode 15+
- スキーム: `ANKI-HUB-iOS`（実機 Run 用）

---

## 3. 機能しない箇所の調査結果

| 箇所 | 原因 | 対応 |
|------|------|------|
| 学習タブ「勉強スタート」 | 右端 chevron のみ Button。ラベル領域はタップ不可 | カード全体を Button 化 |
| 学習タブ「タイムライン」 | ToolsGridView にリンク未配置 | NavigationLink 追加 |
| ホーム「今日の学習」 | 伸びるヘッダーが別 UI。カルーセルと分離 | カルーセル先頭に統合 |
| 壁紙 | `migrateWallpaperEnabledIfNeeded` が bundle/photo を強制 OFF | マイグレーション修正 |
| ウィジェット実機 | 拡張同梱でインストール失敗 | Debug は同梱 OFF（README 参照） |
| Google ログイン | DB スキーマ/RLS/Redirect URL 不一致の可能性 | schema.sql + Dashboard 設定手順 |

---

## 4. 統合結果（A-D 実施済み）

| 統合 | 内容 | 状態 |
|------|------|------|
| **A** | `InputModeView` → `FocusedMemorizationView` に統合（薄いラッパーのみ残存） | ✅ |
| **B** | `TimerView` 上部に `StudySessionBentoCard` を配置。学習タブからセッションカード削除 | ✅ |
| **C** | `ScanView` をハブ化（カメラ / 紙の単語帳 / 問題集）。`ScanSessionManager` でチャプター整理 | ✅ 初版 |
| **D** | `DisplaySettingsView` にテーマ・壁紙・エフェクト・ウィジェットを集約 | ✅ |

### 残候補（未統合）

| 項目 | 備考 |
|------|------|
| E. 苦手復習入口 | ホームカルーセルで整理済み。追加統合は任意 |
| F. SupabaseManager 削除 | レガシー stub |

---

## 5. R8 スキャン→問題集（設計メモ・未実装）

```
撮影 → 問題領域/答え領域を矩形選択 → OCR
  → CustomVocab / StudyMaterial に保存
  → 教科（Subject.custom）+ チャプター（写真束単位）で整理
  → 集中暗記・クイズのチャプター選択に表示
```

- **整理のポイント**: 1「スキャンセッション」= 1 チャプター。複数写真は同一チャプター内ページとして保持。
- **既存資産**: `ScanView`, `TextRecognitionService`, `StudyMaterialManager`, `CustomVocabView`

---

## 6. 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-07-05 | 初版。R1-R10、統合候補、DB 手順、不具合調査表 |
