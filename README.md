# ANKI-HUB-iOS

ネイティブ SwiftUI で構築された iOS 向け単語学習アプリケーション。

## 概要

このプロジェクトは ANKI-HUB の完全ネイティブ iOS 版です。SwiftUI を使用して構築されており、iOS のネイティブ UI/UX を完全に再現しています。

## 機能

### 学習機能
- **4択クイズモード**: 英単語・古文・漢文・政経の4択問題
- **カードモード**: フラッシュカード形式の学習
- **タイピングモード**: 入力式の学習
- **古文助詞クイズ**: 助詞表の穴埋めクイズ
- **習熟度トラッキング**: 5段階の習熟度管理
- **学習統計**: 連続学習日数、学習時間、習熟率の追跡

### ツール
- **ポモドーロタイマー**: 集中・休憩・長休憩の3モード対応
- **ストップウォッチ**: ラップ機能付き
- **フロントカメラ起動**: ロック画面/Dynamic Islandから即起動
- **カレンダー**: 月間学習記録の可視化
- **レポート**: 週間推移チャート、習熟度分布、科目別進捗
- **マイ単語**: カスタム単語帳の作成・管理
- **ToDo**: タスク管理

### 科目
- 英単語（ターゲット1900対応）
- 英検
- 古文単語・文法
- 漢文句法・語彙
- 政経用語（憲法・年号）

## 技術スタック

- **言語**: Swift 5.9
- **UI**: SwiftUI
- **最小 iOS バージョン**: iOS 17.0
- **データ永続化**: UserDefaults + App Group
- **チャート**: Swift Charts
- **認証**: Supabase Auth
- **同期**: Supabase Database

## プロジェクト構成

```
ANKI-HUB-iOS/
├── ANKI-HUB-iOS.xcodeproj/
├── Sources/
│   ├── ANKI-HUB-iOS/
│   │   ├── ANKIHUBApp.swift
│   │   ├── Views/           # メイン画面
│   │   ├── UI/              # UI コンポーネント
│   │   ├── Models/          # データモデル
│   │   ├── Data/            # データ処理
│   │   ├── Services/        # サービス層
│   │   ├── Managers/        # マネージャー
│   │   └── Resources/       # リソース(JSON/TSV)
│   ├── ANKI-HUB-iOS-Widget/ # ウィジェット
│   └── Shared/              # 共有コード
├── Tools/                   # スクリプト
├── Package.swift
├── project.yml
└── README.md
```

## セットアップ

### 方法1: Xcode で直接開く

```bash
cd ANKI-HUB-iOS
open ANKI-HUB-iOS.xcodeproj
```

### 方法2: XcodeGen を使用（推奨）

```bash
brew install xcodegen
cd ANKI-HUB-iOS
xcodegen generate
open ANKI-HUB-iOS.xcodeproj
```

## ビルド要件

- macOS 14.0 以上
- Xcode 15.0 以上
- iOS 17.0 以上のシミュレータまたは実機

---

## Bug Fix Log

### 認証・同期関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| Googleログイン後にアプリへ戻らない | `ASWebAuthenticationSession`がローカル変数、Cookie継承 | 強参照プロパティ化、`prefersEphemeralWebBrowserSession = true` |
| サインイン後にWebサイトへ飛ぶ | 既存Webセッションへのリダイレクト | エフェメラルセッション使用 |
| ログイン状態にならない | `code`がfragment形式で返るケース未対応 | query/fragment両方から取得 |
| ToDoが端末間で同期されない | SyncManagerにToDo未対象 | `SyncManager`にToDo追加 |
| 同期の過負荷 | デバウンス/レート制限なし | 2秒デバウンス、30秒レート制限実装 |

### ビルドエラー関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| Widget側で型が見つからない | SwiftPMターゲット依存不足 | `ANKI-HUB-iOS-Shared`作成、依存追加 |
| macOS互換性エラー | iOS専用API使用 | `#if os(iOS)`でガード |
| 型チェックタイムアウト | List内の複雑なBinding | セクション分割、Binding切り出し |
| `ActivityKit`エラー | macOS解析時に型がunavailable | `#if canImport(ActivityKit) && os(iOS)` |
| 署名エラー | `DEVELOPMENT_TEAM`未設定 | `project.yml`に追加 |
| Widget拡張インストール失敗 | `CFBundleExecutable`未設定、不要キー存在 | Info.plist修正 |
| CodeSign失敗 | resource fork/xattr | `SYMROOT/OBJROOT`をDerivedData側に |

### クイズ・学習関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| クイズが1問で終わる | 履歴除外で候補減少時の補充不足 | 要求数未満時に補充 |
| クイズが始まらない | リソースがビルドフェーズ未登録 | `project.pbxproj`修正 |
| 答えを連打すると正解数増加 | 回答ロックなし | `isAnswerLocked`追加 |
| セクション選択に戻ってしまう | `id = UUID()`が毎回変更 | `id`を固定値に |
| 漢文の問題が出ない | `category`フィルタが効かない | 全語彙4分割方式に変更 |
| 古文ヒントが出ない | PDF版にhint欠落 | `kobun.json`から補完 |
| 政経に答えが見える | 状態リセット漏れ | `nextQuestion()`でリセット |

### タイマー・学習時間関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| 学習時間が増えない/二重計上 | 複数経路で記録 | `StudySession`統合、再集計方式 |
| Streak/Todayが増えない | words > 0のみ活動扱い | 語数 or 分で活動扱い |
| タイマー0到達後に戻れない | 状態がViewのStateのみ | UserDefaultsに永続化 |
| Stop操作が分かりにくい | Play/Pauseと同一扱い | Stopボタン独立 |
| オーバータイム後に不安定 | 状態整合崩れ | `pauseTimer()`/`resetTimer()`統一 |
| 動作が重い・電池消費大 | 0.01秒Timer、毎秒永続化 | 0.2秒更新、15秒スロットリング |

### テーマ・UI関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| テーマが画面ごとに揺れる | `applyAppTheme()`適用漏れ | 全画面に適用 |
| 文字が背景に埋もれる | 固定色使用、コントラスト不足 | `ThemeManager.primaryText/onColor`使用 |
| Liquid Glassが効かない | 監視が弱い | `AdaptiveLiquidGlassModifier`統一 |
| 写真壁紙でコンテナ見えない | 透明度不足 | 壁紙時は不透明度/ボーダー強化 |
| ダークモードで読めない | `.secondary`等システム色依存 | テーマ基準の色に統一 |

### データ関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| 古文単語データ重複 | マージ時の照合キー不足 | hint別表記も照合、かな/漢字統合 |
| チャプター進捗が0% | getProgressがplaceholder | 実際の習熟度から計算 |
| 単語帳の削除が別項目を消す | フィルタ後IndexSetを元配列に適用 | ID一致で削除 |

### ウィジェット関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| ウィジェット反映が遅い | Timeline更新間隔長い | 短縮、`reloadTimelines`呼び出し |
| タイマー開始できない | ディープリンクなし | `sugwranki://timer/start`追加 |
| 教科フィルタ効かない | App Group設定未参照 | `SettingsView`で設定、Widget参照 |

---

## トラブルシューティング

### SIGTERM エラーが発生する場合

1. Xcode を完全に終了してから再度開く
2. **Product > Clean Build Folder** (⌘⇧K) を実行
3. DerivedData を削除: `rm -rf ~/Library/Developer/Xcode/DerivedData`
4. プロジェクトを再度開いてビルド

### ビルドエラーが発生する場合

1. iOS Deployment Target が **17.0** になっているか確認
2. **Signing & Capabilities** で Team を選択
3. シミュレータを iOS 17 対応機種に変更

---

## ライセンス

Private - All rights reserved

## 作者

ANKI-HUB Team
