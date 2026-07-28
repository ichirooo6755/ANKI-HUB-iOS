# ANKI-HUB-iOS 要件・実装条件

> **更新日**: 2026-07-28  
> このファイルはユーザー要求と実装状態を毎回ここに集約する。作業前に必ず更新すること。

---

## 1. ユーザー要求（2026-07-05 / 追記 2026-07-28）

| # | 要求 | 優先度 | 状態 |
|---|------|--------|------|
| R1 | ダーク/ライト混在・コントラスト不足・白コンテナだけ浮く問題の色見直し | P0 | ✅ 完了 |
| R2 | 壁紙機能の完成（選択→反映→テーマ連動→リセット） | P0 | ✅ 完了 |
| R3 | ホーム最上部「今日の学習」を横スクロール列（集中タイマー等）に統合。下スクロールで各機能へ | P0 | ✅ 完了 |
| R4 | ウィジェット実装の明確化（何が動く/動かない、実機同梱条件） | P1 | ✅ README 文書化 |
| R5 | Googleログイン復旧（Supabase DB 再構築含む） | P0 | 🔄 schema 追加済・Dashboard 設定要 |
| R6 | 機能しないボタン/ウィジェットの調査・修正（勉強スタート、タイムライン、ToDo等） | P0 | ✅ 完了 |
| R7 | 3アマ等の長文問題文の見切れ修正（集中暗記等） | P0 | ✅ 完了 |
| R8 | スキャン→OCR→問題/答え領域選択→自動問題集→教科/チャプター整理 | P1 | ✅ 完了 |
| R9 | 統合候補機能の整理（ユーザーが統合可否を判断） | P1 | ✅ A-D 実施済 |
| R10 | 3アマチャプターから「間違い」仮想チャプター削除、法規/工学表記修正 | P0 | ✅ 完了 |
| R11 | 英検科目の記載削除（未実装のため） | P1 | ✅ 完了 |
| R12 | アカウンティング・マネファイを別科目として追加（MCQ・`select[0]`正解） | P0 | ✅ 完了 |
| R13 | Playwright MCP（`@playwright/mcp`）導入・README 手順 | P1 | ✅ 完了（補助用。抽出本体は通常 Playwright スクリプト） |
| R14 | Manaba 採点外ドリルのみ取得→`accounting.json` マージ（提出しない） | P0 | ✅ ソース50→アプリ90（Web同数・基本5択）。再試験で結果画面から正解本文取得を確認。`npm run manaba:extract` |
| R15 | `manefi.json` 充実（40問以上）と Subject 配線 | P0 | ✅ 完了（175問） |
| R16 | Quiz 出題時に選択肢シャッフル（本文判定・correctIndex 再計算） | P0 | ✅ 済（`QuizView` MCQ / accounting / manefi） |

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
| 学習タブ「勉強スタート」 | 右端 chevron のみ Button。ラベル領域はタップ不可 | ✅ カード全体を Button 化 |
| 学習タブ「タイムライン」 | ToolsGridView にリンク未配置 | ✅ NavigationLink 追加 |
| ホーム「今日の学習」 | 伸びるヘッダーが別 UI。カルーセルと分離 | ✅ カルーセル先頭に統合 |
| 壁紙 | `migrateWallpaperEnabledIfNeeded` が bundle/photo を強制 OFF | ✅ マイグレーション修正 |
| ウィジェット実機 | 拡張同梱でインストール失敗 | Debug は同梱 OFF（README 参照） |
| Google ログイン | DB スキーマ/RLS/Redirect URL 不一致の可能性 | schema.sql + Dashboard 設定手順 |

---

## 4. 統合結果（A-D 実施済み）

| 統合 | 内容 | 状態 |
|------|------|------|
| **A** | `InputModeView` → `FocusedMemorizationView` に統合（薄いラッパーのみ残存） | ✅ |
| **B** | `TimerView` 上部に `StudySessionBentoCard` を配置。学習タブからセッションカード削除 | ✅ |
| **C** | `ScanView` をハブ化（カメラ / 紙の単語帳 / 問題集）。`ScanSessionManager` でチャプター整理 | ✅ |
| **D** | `DisplaySettingsView` にテーマ・壁紙・エフェクト・ウィジェットを集約 | ✅ |
| **F** | `SupabaseManager` レガシー stub 削除 | ✅ |

### 残候補（任意）

| 項目 | 備考 |
|------|------|
| E. 苦手復習入口 | ホームカルーセルで整理済み。追加統合は任意 |

---

## 5. R8 スキャン→問題集（実装済み）

```
撮影 → 問題領域/答え領域を矩形選択（ImageRegionSelectorView）→ 領域OCR
  → 問題文/答え編集 → ScanSessionManager に保存
  → 教科 + チャプター名（📷 プレフィックス）で整理
  → クイズ・集中暗記・ChapterSelectionView に表示
```

- **1 スキャンセッション = 1 チャプター**。複数写真は同一セッション内ページとして保持。
- **主要ファイル**: `ScanView`, `ImageRegionSelectorView`, `TextRecognitionService`, `ScanSessionManager`

---

## 6. アカウンティング / マネファイ（2026-07-28）

| 項目 | 内容 |
|------|------|
| 科目 | `Subject.accounting` / `Subject.manefi`（表示名: アカウンティング / マネファイ）。**完全に別科目** |
| JSON | `Resources/accounting.json`（**134問**: 非Manaba44 + Manaba90）、`Resources/manefi.json`（**175問**・ローカル教材）。`select[0]` が正解（選択肢は**本文**、番号依存禁止） |
| 配線 | `VocabularyData` / `DataParser.parseMultipleChoiceData` / `QuizView`（出題時 `allAnswers.shuffled()` → `correctIndex` を本文で再計算）/ `ChapterSelectionView`（カテゴリ章）/ `RankUpManager`（全チャンク解放） |
| Manaba（アカウンティング） | 採点外ドリル `course_6089558_drill_6812813` のみ。採点対象小テストは提出しない。資格情報は扱わない |
| ユニーク（会計ドリル） | ソース **50**（choices セット）。wrong_multi は案Aで誤りごとに1問（選択肢は Web 元のまま、基本5） |
| Manaba select 分布 | 5択66 / 4択19（穴埋め等）/ 6択4 / 3択1 |
| 再試験（2026-07-28） | storageState 再利用・3ラウンド提出。結果「正解はこちら」から正解本文取得成功。既存 sources と options 一致36件は wrong 完全一致（不一致5は tmp 優先で解消） |
| 取得方針（会計） | `scripts/manaba_extract/`（通常 Playwright + `fs`）。マネファイは Manaba Web 禁止 |

### マネファイ厳守ルール（ローカル教材のみ）

データ元: `Downloads/Manaba/マネー＆ファイナンス入門`（＋手元の中間/期末写真PDF）。**Playwright / Manaba ログイン / ドリル提出は行わない。**

| 優先 | 内容 |
|------|------|
| 1 | **前半**: 「小テスト」「練習問題」を重点的に問題化（テストに出やすい） |
| 2 | **後半**: ファイル名・本文に「テスト」「試験」「確認」がある箇所を重点 |
| 3 | `respon解答` / 練習問題解答があれば正解付き（`select[0]`=正解、選択肢は本文） |
| 4 | 講義スライドからの補強は上記が薄いときのみ |

カテゴリ例: `前半・respon` / `前半・練習問題` / `前半・小テスト` / `後半・練習問題` / `後半・中間試験` / `後半・期末試験` / `後半・補強`

### Manaba 抽出（通常 Playwright・推奨）

```bash
npm i
npx playwright install chromium
npm run manaba:extract          # headed で SSO → out/pool.json
npm run manaba:extract:dry      # ログイン待ち起動確認のみ（提出しない）
npm run manaba:merge            # プレビュー
node scripts/manaba_extract/merge_pool.cjs --write
```

- 出力: `scripts/manaba_extract/out/pool.json`
- storageState: `scripts/manaba_extract/storage/storageState.json`（gitignore・コミット禁止）
- 詳細: `scripts/manaba_extract/README.md` / README「現状」節

**`fs` について**: MCP の `browser_run_code_unsafe` では `require('fs')` 不可。抽出・保存は上記スクリプトを使う。

---

## 7. 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-07-05 | 初版。R1-R10、統合候補、DB 手順、不具合調査表 |
| 2026-07-05 | R8 領域選択 OCR、ScanSession 配線、SupabaseManager 削除、R1-R7 完了 |
| 2026-07-28 | R12-R15: accounting/manefi 科目・JSON 充実、Playwright MCP、Manaba ドリル方針、README 更新 |
| 2026-07-28 | Playwright MCP に `--allow-unrestricted-file-access` 追加。`require`/`fs` 制限と再起動要を README/requirements に追記 |
| 2026-07-28 | Manaba 抽出を通常 Playwright スクリプト化（`scripts/manaba_extract/` + `package.json`）。MCP は補助、`fs` 保存はスクリプト側 |
| 2026-07-28 | R14: Playwright MCP で Manaba 採点外ドリルをライブ取得し accounting.json マージ（BUILD SUCCEEDED） |
| 2026-07-28 | Manaba を Web 同数選択肢に修正（案A: 元 options 維持・4択へ切り捨て廃止）。実ユニーク=ソース34 / アプリ展開60 |
| 2026-07-28 | 受験25回目 answerlog から未収録 wrong_multi 2問をマージ。実ユニーク=ソース36（WM28+single8）/ アプリ展開64 / accounting合計108 |
| 2026-07-28 | マネファイ: ローカル教材のみで `manefi.json` を175問に拡充。優先ルール（前半=小テスト/練習、後半=試験記載）を requirements に明記。Manaba Web 同時アクセス禁止 |
| 2026-07-28 | Manaba 再試験3R: 正解本文取得確認。pool ソース50→accounting Manaba90（計134）。選択肢シャッフルは既存実装を確認。BUILD SUCCEEDED |
