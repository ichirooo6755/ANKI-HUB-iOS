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
| R14 | Manaba 採点外ドリル（木）取得→`accounting.json` マージ | P0 | ✅ 木: choicesユニーク60→展開115。`npm run manaba:extract` |
| R15 | `manefi.json` 充実（40問以上）と Subject 配線 | P0 | ✅ 完了（227問・PDF再解析） |
| R16 | Quiz 出題時に選択肢シャッフル（本文判定・correctIndex 再計算） | P0 | ✅ 済（`QuizView` MCQ / accounting / manefi） |
| R17 | 月曜`(月)`小テスト抽出＋木/月を章分け（同一 Subject `accounting`） | P0 | ✅ 月: choicesユニーク23→展開62。章「Manaba・木」「Manaba・月」。提出せず正解公開のみ |

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
| JSON | `Resources/accounting.json`（**221問**: 非Manaba44 + 木115 + 月62）、`Resources/manefi.json`（**246問**・ローカル教材・PDF再解析）。`select[0]` が正解（選択肢は**本文**、番号依存禁止） |
| 配線 | `VocabularyData` / `DataParser.parseMultipleChoiceData` / `QuizView`（出題時シャッフル）/ `ChapterSelectionView`（カテゴリ章で月/木を選択）/ `RankUpManager` |
| Manaba・木 | 採点外ドリル `course_6089558_drill_6812813` → 章 `管理会計・経理実務（Manaba・木）`。提出は採点外のみ |
| Manaba・月 | `(月)` 財務会計小テスト（query）。章 `管理会計・経理実務（Manaba・月）`。**採点対象のため提出しない**。受付終了後の「正解はこちら」から取得 |
| ユニーク（木） | choices セットユニーク **60**（pool ソース67）→ 展開 **115** |
| ユニーク（月） | choices セットユニーク **23**（pool ソース56）→ 展開 **62**（correct_multi / fill_blank 分解） |
| Manaba select 分布（木） | 5択80 / 4択27 / 6択6 / 3択2 |
| Manaba select 分布（月） | 8択9 / 5択15 / 4択24 / 3択12 / 2択2 |
| 取得方針（会計） | `scripts/manaba_extract/`（通常 Playwright + `fs`）。木/月同時に複数提出プロセス禁止。マネファイは Manaba Web 禁止 |

### マネファイ厳守ルール（ローカル教材のみ）

データ元: `Downloads/Manaba/マネー＆ファイナンス入門`（＋手元の中間/期末写真PDF）。**Playwright / Manaba ログイン / ドリル提出は行わない。**

| 優先 | 内容 |
|------|------|
| 1 | **前半**: 「小テスト」「練習問題」を重点的に問題化（テストに出やすい） |
| 2 | **後半**: ファイル名・本文に「テスト」「試験」「確認」がある箇所を重点 |
| 3 | `respon解答` / 練習問題解答があれば正解付き（`select[0]`=正解、選択肢は本文） |
| 4 | 講義スライドからの補強は上記が薄いときのみ |

カテゴリ（先生 / AI で章分け・授業回は章名に残す）:
`先生・前半・respon（第10-15回）` / `先生・前半・練習問題（第10-15回）` /
`先生・後半・クイズ（第16–19回）` / `先生・後半・練習問題（第19-20回）` /
`先生・試験・中間` / `先生・試験・期末` / `先生・期末（マネファイ期末.pdf）` /
`AI・前半・概念確認（第1-9回）` / `AI・後半・補強（第22-26回）` / `AI・補強・基礎概念`

### マネファイ 先生 / AI 分類ルール（2026-07-28）

ChapterSelection の章 = `category`。`先生・` / `AI・` プレフィックスで選択可能。件数: **先生 208問 / AI 38問**（計246）。

| 区分 | 対象（id） | 判断 |
|------|------------|------|
| **先生** | `mf-r` respon / `mf-p` 練習 / `mf-t` 授業内クイズ / `mf-h01–16` 後半練習 / `mf-m` 中間OCR / `mf-f` 期末OCR / `mf-pdf` 期末PDF | Manaba教材の小テスト・練習・respon解答・高見澤等の授業内クイズ・実試験写真OCR・**手元PDF**など **教材・試験由来** |
| **AI** | `mf-q`・`mf-e` 概念確認 / `mf-h17–24` 後半補強 / `mf-s` 基礎補強 | 講義スライド等からエージェントが作った **補強・概念確認カード**（オリジナルMCQ） |

- 曖昧なものは原則 **先生寄り**。ただし現行の「概念確認」「補強」カテゴリは生成経緯がエージェント補強なので **AI** に分類（`mf-e` 第4回期待効用もスライド概念のMCQ化のため AI）。
- 既存の前半=小テスト/練習・後半=試験記載の優先ルールは章名に維持。

### マネファイ PDF 再解析（2026-07-28・取りこぼし潰し）

| 項目 | 内容 |
|------|------|
| 件数 | **175 → 227問**（+52、stem+choices 重複除外） |
| 抽出 | `pdftotext -layout`（テキストPDF）、PPTXは zip+XML、試験写真は **Apple Vision OCR**（Tesseractは日本語スキャンに弱い） |
| 新規主戦場 | 第16–19回の**授業内クイズ**（スライド末尾に解答あり）／respon取りこぼし（デイトレーダー・2024収益構成など）／第4回期待効用／第22–26回金融政策・国際収支／中間OCRの確度高い計算問題 |
| 未使用・残り | 日経記事PDF6本（スキャンほぼテキスト無し・問題ではない）／第16–20回 Manaba「小テスト」本体（解答はManaba公開・**Web禁止のため未取得**）／第26回練習は記述式のためMCQ要約のみ／試験写真の一部はOCRノイズで未問題化 |
| ビルド | 実機 `platform=iOS,name=iPhoneA13` **BUILD SUCCEEDED** |

### マネファイ期末.pdf 新章（2026-07-28）

| 項目 | 内容 |
|------|------|
| ソース | `Downloads/マネファイ期末.pdf`（9ページ・iOS写真PDF・**pdftotext不可**） |
| 抽出 | `pdftoppm` → **Apple Vision OCR**（`.tmp-manaba/ocr_vision`） |
| 章名 | `先生・期末（マネファイ期末.pdf）`（既存 `先生・試験・期末` OCR56問と**別章**） |
| 件数 | **227 → 246問**（+19、stem+choices 重複51件は除外） |
| 内容 | p1–7: Manaba提出回答スクショ（40問・既存期末OCRと大半重複）／p8–9: **問題用紙**（はい/いいえ・国際収支・為替計算・日銀政策・payoff 等）／範囲・形式案内3問 |
| スクリプト | `python3 scripts/manaba_extract/merge_mf_fin_pdf.py` |
| Manaba Web | **未使用** |

### Manaba 抽出（通常 Playwright・推奨）

```bash
npm i
npx playwright install chromium
npm run manaba:extract          # 木・採点外 → out/pool.json
npm run manaba:extract:dry      # ログイン待ち起動確認のみ（提出しない）
npm run manaba:list             # (月)/(木) 一覧 → out/query_list.json
npm run manaba:extract:mon      # 月・正解公開のみ → out/pool_mon.json（提出しない）
npm run manaba:merge            # プレビュー
node scripts/manaba_extract/merge_pool.cjs --write
```

- 出力: `out/pool.json`（木）、`out/pool_mon.json`（月）
- storageState: `scripts/manaba_extract/storage/storageState.json`（gitignore・コミット禁止）
- 詳細: `scripts/manaba_extract/README.md` / README「現状」節

**`fs` について**: MCP の `browser_run_code_unsafe` では `require('fs')` 不可。抽出・保存は上記スクリプトを使う。

---

## 7. 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-07-28 | マネファイ期末.pdf: 新章 `先生・期末（マネファイ期末.pdf）` +19問（246問計）。Vision OCR。`先生・試験・期末` と別章。Manaba Web未使用 |
| 2026-07-28 | マネファイ: category を先生/AIで章分け（先生208 / AI38）。ChapterSelection で選択可。分類ルールを requirements に追記 |
| 2026-07-28 | マネファイ PDF再解析: `manefi.json` 175→227問。第16–19回クイズ・respon取りこぼし・章立て授業回化。Vision OCR。実機 iPhoneA13 BUILD SUCCEEDED。Manaba Web未使用 |
| 2026-07-28 | R17: 月曜`(月)`小テストを正解公開のみで抽出。木/月を章分け（Manaba・木 / Manaba・月）。accounting 221問 |
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
