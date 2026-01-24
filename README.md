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
- **タイマー**: ポモドーロ・休憩・長休憩・カスタムの4モード対応
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
| HealthMetricCard/StatCard/StatBoxのビルドエラー | Color.green/redの推論エラー、braceの不一致 | Color.green/redを明示的に指定、不足braceを追加 |
| DashboardViewの構文エラー | VStackの閉じbrace不足 | bodyプロパティの閉じbraceを追加 |
| DashboardViewのビルドエラー | ヒーロー追加時に余分な閉じ括弧が混入 | 余分な`}`を削除して`private func`のスコープを修正 |
| StatBoxの引数エラー | 引数順序の不一致 | color引数をicon引数の前に移動 |
| build.dbがロックされてビルド失敗 | 同一出力先で並行ビルドが実行中 | 既存ビルドを停止し、build/XCBuildData/build.dbを削除して再ビルド |

### UIコンポーネント関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| タイポグラフィ階層が不明瞭 | Label/Value/Unitの区別が不十分 | HIGガイドラインに従いLabelは小文字/灰色、Valueは太字/大文字、Unitは小文字に統一 |
| アイコンスタイルが統一されていない | 背景なし、色のばらつき | パステルカラーの背景円/ボックスを追加、統一感のあるデザインに |
| 動的要素がない | プログレスバーや変化率の表示なし | プログレスバーと変化率チップをオプションで追加 |
| Widget側で型が見つからない | SwiftPMターゲット依存不足 | `ANKI-HUB-iOS-Shared`作成、依存追加 |
| macOS互換性エラー | iOS専用API使用 | `#if os(iOS)`でガード |
| 型チェックタイムアウト | List内の複雑なBinding | セクション分割、Binding切り出し |
| `ActivityKit`エラー | macOS解析時に型がunavailable | `#if canImport(ActivityKit) && os(iOS)` |
| 署名エラー | `DEVELOPMENT_TEAM`未設定 | `project.yml`に追加 |
| Widget拡張インストール失敗 | `CFBundleExecutable`未設定、不要キー存在 | Info.plist修正 |
| CodeSign失敗 | resource fork/xattr | `SYMROOT/OBJROOT`をDerivedData側に |
| `startActiveSegmentIfNeeded`が見つからない | タイマーリファクタで補助関数が欠落 | `TimerView`に補助関数を復旧 |
| `AppCalendarView`が見つからない | `UI/CalendarView.swift`が空でターゲットに含まれていなかった | `UI/CalendarView.swift`に`AppCalendarView`を実装し、SPMでは`Views/CalendarView.swift`を除外 |
| `StudyView`で`SectionHeader`/`HealthMetricCard`/`AppCalendarView`が見つからない | `HealthComponents.swift`/`AppCalendarView.swift`がターゲット未登録、カレンダー画面の定義が分散 | `HealthComponents.swift`と`AppCalendarView.swift`をSourcesに追加し、カレンダー画面を`AppCalendarView.swift`に統一 |
| `TodoView`で`summaryMetrics`が未定義 | `summaryMetrics`が`TodoItem`に混入してスコープ外 | `TodoView`内に移動して整理 |
| `TimelineView`が見つからない | 画面ファイルが欠落 | `Views/TimelineView.swift`を追加しDashboardから参照 |
| `InputModeView`の型チェック失敗 | View構造破損と`SpeechTranscriber`名競合 | `InputModeSessionView`に分割し`CustomSpeechTranscriber`で統一 |
| macOSビルドでiOS専用APIエラー | `.topBarTrailing`/`textInputAutocapitalization`/`AVAudioSession`が未対応 | `#if os(iOS)`でガードしmacOSでは`.automatic`等に切替 |
| `StudyMaterial`の公開APIで型エラー | `Subject`がinternalのままpublic型に露出 | `Subject`の公開範囲をpublicに統一 |
| `CustomSpeechTranscriber`が見つからない | `CustomSpeechTranscriber.swift`がターゲット未登録 | pbxprojに登録してSourcesへ追加 |
| `CustomSpeechTranscriber`の`override init`でビルド失敗 | `ObservableObject`のinitにoverrideが不要 | `override`と`super.init()`を削除 |
| `LockScreenMirrorGuideView`が見つからない | `LockScreenMirrorGuideView.swift`がターゲット未登録 | pbxprojに登録してSourcesへ追加 |
| `BookshelfView`で`formatMinutes`が見つからない | `MaterialCardView`が親Viewのprivate関数へアクセス | file-privateの`formatMinutes`を追加 |
| `DashboardView`で`Decodable`に`timer/due/weak/mirror`が見つからない | `NavigationPath.append`の型推論が`Decodable`に誤解決 | `Destination`を明示してappend |
| `xcodebuild`で指定シミュレータが見つからない | 端末名が環境に存在しない | `xcodebuild -destination`を`xcrun simctl list`の実在デバイスに合わせる |
| `xcodebuild`で`build.db`がロックされる | 同一ビルドディレクトリで並行ビルドが走っている | `build/`を削除して再ビルド |

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
| ダーク/ライトが混在して見える | 色指定が固定でもMaterialがシステム色に引っ張られる | カラー強制時はMaterialを無効化しテーマ色に統一 |
| カレンダー画面に月間カレンダーが表示されない | 履歴カードのリファクタで月間カレンダーのカードを削除 | 月間カレンダーのカードを復活し、月計算/曜日表示を再実装 |

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
| Widget背景の適用が不安定 | `.background` と `containerBackground` が混在 | `StudyWidgetEntryView`の背景を`containerBackground`へ統一し重複背景を削除 |
| ロック画面右下コントロールが追加できない | ControlWidget未登録 / iOS18未満 | ControlWidgetを追加し、iOS18以上で追加 |
| Live Activity背景がロック画面で白く浮く | テーマ色がライト固定 | 常にダーク半透明背景+白テキストに固定 |
| ControlWidgetのビルドエラー | iOS18/Swift6未満でControlWidget型が解決不能 | ControlWidget定義/使用箇所を`swift(>=6.0)`+`@available(iOS 18.0)`でガード |
| ロック画面のウィジェットが崩れる | accessory系で背景が適用されず視認性が低下 | accessory系のみcontainerBackgroundを適用して表示を復元 |

### UI関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| 学習画面のカードテキストが薄くて見えない | liquidGlass透明度が高すぎ | 背景不透明度を上げ、SubjectCard/ToolCardをソリッド背景に変更 |
| ダーク/ライトがコンテナごとに混在して見える | Form/Listのシステム背景がテーマ背景と混ざる | `applyAppTheme`で`scrollContentBackground(.hidden)`+テーマ背景を適用して統一 |
| タブ導線の配置が画面によってズレる | `ContentView`と`MainTabView`でタブ構成が二重管理 | `ContentView`を`MainTabView`への委譲に統一 |
| `InputModeView`がビルドできない | パッチ適用時に`// ...`のプレースホルダが混入し、View構造が破損 | 該当ファイルをgitの内容に復元し、必要な差分のみを最小単位で再適用 |
| `TodoView`がビルドできない | パッチ競合で`struct`の境界が崩れ、関数/`body`定義が重複して構文破損 | `TodoView.swift`をgitの内容に復元し、追加変更はコンテキスト確認後に小さく適用 |
| クイズ画面がスクロールできない | `quizContentView`が`ScrollView`で包まれていない | `quizContentView`を`ScrollView`化 |
| ブックマークが目立ちすぎて配置が合わない | 円形背景/右上配置で視線が散る | 左端にアイコンのみ配置（Quiz/Flashcard/InputMode） |
| ホームカードの遷移が不安定/入力モードが二重表示 | `navigationPath`に同一Destinationを連続append | `navigate(to:)`で重複遷移を抑制 |
| ダッシュボード指標の数字が弱く丸ゴシック | ラベルと数値の階層差が不足 | 非丸ゴシック+サイズ/太さで数値強調 |
| カレンダー見出しが冗長で凡例が分かりにくい | 見出し説明と凡例ラベル不足 | 見出し簡素化・学習量ラベル追加 |
| 日付タップで学習記録/ジャーナルを編集できない | DayCellのタップ処理と編集UIがない | 日付編集シートで分/語数/ジャーナルを保存 |
| 学習タブのコンテナが野暮ったい | 影/装飾が過剰で階層が曖昧 | Subject/Tool/Sectionカードをミニマルに再設計 |
| ホーム最上部カードの遷移先が分かりにくい | ヒーローがタップ不能/目的不明 | 苦手一括復習へ遷移するボタンに変更 |
| InputModeでチャプター8以降が出ない | 古文が先頭350語で制限され既存設定がfalse | 全単語デフォルト化＋初回移行で制限解除 |
| 画面内の薄い説明文が多くてノイズ | サブタイトル/補足文が常時表示され視線を散らす | サブ説明文を削除し、見出しと主要情報だけに統一 |
| 学習タブに大きな丸い背景エフェクトが出る | 壁紙（画像/写真）が全タブ共通の背景として描画されていた | 壁紙表示の有効フラグを追加し、既存ユーザーは自動でOFFに移行 |
| メトリクスの数字が小さく情報が弱い | 数値とラベルの階層差が不足し、視認性が低い | ウィジェット風に再設計（巨大アイコン背景＋値を大きく、説明は薄く小さく） |
| ブックマークUIの位置/揃えがバラつく | 画面ごとに左/右や余白が異なる | 単語カード右端にアイコンのみで統一し、余白/サイズを揃えた |
| ヒートマップが何を表すか分かりにくい | 凡例が抽象的で学習量の基準が不明 | レベル0-3と閾値（分/語）を凡例に明記 |
| スクロール時の表示が重い | ヒーロー等でblurを多用し描画負荷が高い | スクロール連動blurを撤廃し、描画コストを削減 |
| 数字とラベルの優先順位が曖昧でプロっぽく見えない | タイポグラフィの強弱（サイズ/ウェイト）とカードの角丸・余白が揃っていない | 値をより大きく太く、ラベル/単位は小さく薄くし、角丸/余白を統一 |
| UIに機能説明テキストが多くノイズ | サブタイトル/誘導文/空状態の説明を常時表示していた | 説明文を削除し、タイトル/数値/必要最小限の操作要素だけを表示（空文字は描画しない） |
| 壁紙/テーマの雰囲気を一発で切り替えられない | 壁紙種別とテーマ設定が別操作で、統一されたプリセットが無かった | プリセット（壁紙＋テーマ）を3種追加し、1タップで適用できるようにした |
| カレンダーで日付を押してもその日の学習内容を見られない | 日付タップが編集シート直行で、閲覧専用の詳細UIが無かった | 日付タップで詳細シート（分/語/科目内訳/ジャーナル）を表示し、必要なら編集へ遷移できるようにした |
| ウィジェット/カードの見た目を複数から選べない | 1種類の描画スタイルに固定されていた | Soft/Outline/Neo の3スタイルを追加し、設定から切替できるようにした |
| カレンダー日付で「この日にやる」を操作できない | 学習記録は見られるが、日付に紐付くToDoの追加/完了ができなかった | 日付詳細にその日のToDoを表示し、追加/完了切替できるようにした（dueDateで日付に紐付け） |
| カレンダー日付とテスト履歴が連携できない | テスト結果保存が常に`Date()`で、任意の日付に紐付けられない | `ExamResultManager`に任意日付保存を追加し、日付詳細に当日のテスト一覧/追加/詳細表示を統合 |
| 古文のチャプターが被って出題されることがある | 古文データ統合後に重複語が残り、50語ブロック（チャプター）跨ぎで同一語が混入 | 古文データを正規化（重複排除＋安定ソート）してからチャプター分割し、出題側（Quiz/InputMode）で同一語が跨がないようにした |
| チャプター一覧/再出題UIが冗長で視線が散る | 説明文（範囲/誘導）が常時表示され、主情報の比重が下がっていた | チャプター一覧の説明文と再出題の誘導文を削除し、操作要素と主情報のみを残した |
| タイムラインが重くなりやすい | ScrollView内で非LazyのVStackを使い、エントリ数が増えるほど初期描画/再描画が重くなる | タイムラインのリストをLazyVStack化し、必要な分だけ描画されるようにしてスクロール負荷を軽減 |
| シート遷移が不安定（閉じない/意図せず別シートが出る） | 同一View内に複数の`.sheet`が同居し、表示タイミング次第で競合する | 日付詳細とTodoでsheetを単一の`activeSheet(item:)`に統合し、常に1枚だけが提示されるようにして遷移を安定化 |
| 教材詳細の編集/記録追加シートが不安定 | 教材詳細（MaterialDetailView）で複数の`.sheet`が同居し競合する | `showEditSheet/showRecordSheet`を廃止し、単一の`activeSheet(item:)`に統合して提示を1枚に固定 |
| クイズで残り秒数が単語横に出て視線が散る | 問題文ヘッダー内にタイマー表示を入れていた | 残り秒数を問題文ヘッダーから削除し、進捗ヘッダーのリング表示に集約 |
| ブックマークの位置がカードごとにズレる | `overlay`適用順とアイコンサイズが揃っていなかった | ブックマークに固定サイズを与え、`overlay`をカード基準で揃えて常に同位置に表示 |
| 目標カードで「今日が締切」が大きく、数値が主役にならない | ラベル文言も数値と同じ強さで表示していた | 主役を日数の数値に統一し、「今日が締切」等の文言はcaption2で弱く表示 |
| ダッシュボードの背景アイコンがカードからはみ出す | 大きい背景アイコンを`offset`で配置しており、クリップしていなかった | カード形状で`clipShape`し、背景アイコンがコンテナ外に出ないようにした |
| ヒーローセクションを引っ張っても苦手克服へ行かない | ヒーロー側にドラッグ検知が無く、タップ以外で遷移できなかった | ヒーローに下方向ドラッグの閾値トリガーを追加し、一定距離引っ張ると`苦手克服`へ遷移するようにした |
| ヒートマップの並び/サイズが崩れる | セルを`flexible`で組み、カード幅に引っ張られて歪む | ヒートマップを固定セル幅＋左寄せで安定させ、カード形状でクリップして崩れを抑えた |
| 学習タブのカードが崩れて見える | セクション/メニューカードの角丸・余白・影が不統一 | StudySectionCard/古文メニューをcornerRadius=28/padding=18に統一し、clipで外側はみ出しを抑止 |
| カード内の背景アイコンが全体的にはみ出す | `offset`配置が多く、カードでクリップしていなかった | 背景アイコンをpadding配置に変更し、主要カードを`clipShape`で内側に収めた |
| 連続/今日の学習時間カードのレイアウトが崩れる | 単位が数値と同サイズ、アイコンが小さく目立たない | 単位を数値の右下に小さく配置、アイコンを大きくして右寄せ見切れ、8ptグリッドのpaddingに統一 |
| 習熟度円グラフの背景が重い | chartCardラッパーで背景を付けていた | 習熟度チャートの背景を削除し、「習熟度」文言を太字からmediumに変更してシンプル化 |
| Viewsフォルダに不要ファイルが混入 | ブラウザからのドキュメントがファイルとして保存されていた | `# Buttons`等の不要ファイルを削除 |
| 横長1列コンテナに不要な背景/枠がある | GoalCountdownCardが1列を占めるのに背景/枠/影を持っていた | 背景/枠/影を削除してシンプル化、数値レイアウトも他カードと統一 |
| セクションヘッダーにtextCase(.uppercase)が適用されていた | 日本語テキストに大文字変換は不要で可読性を下げる | ThemeSettingsView/PastExamAnalysisViewからtextCase(.uppercase)を削除 |
| 学習タブのメトリクスカードが3列で画面からはみ出す | HStackで3つのHealthMetricCardを横並びにしていた | 2列LazyVGridに変更し、総単語数カードを削除してシンプル化 |
| 科目名が太字で目立ちすぎる | SubjectCardの科目名がtitle3.weight(.bold)だった | callout.weight(.medium)に変更して控えめに |
| StudyViewの余白/グリッドが中途半端で崩れやすい | spacing/paddingが12/15/20等で混在し、端末幅によって被り/はみ出しが起きやすい | 8ptグリッド（16中心）に統一してレイアウトの安定性を上げた |
| Bookshelfの空状態/カードが重い | 空状態ボタンの強いshadowやカードの強いshadowでoverdrawが増える | 空状態ボタンのshadowを削除し、カードshadowを弱めて描画負荷を軽くした |
| ダッシュボードのクイックアクションが重い | カード群に強いshadow（radius 10 / y 6）が多発し、overdrawが増える | shadowを弱め（radius 6 / y 3）て描画負荷を軽くした |
| 学習タブのspacing/paddingが8ptグリッドに合っていない | summaryMetricsのspacing=12、StudySectionCardのpadding=18で中途半端 | spacing=16、padding=16に統一して8ptグリッドに合わせた |
| 大きいテキストのletter-spacingが広すぎる | largeTitleなどの大きいテキストにtrackingが適用されていない | QuizViewのスコア表示などにtracking(-1)を適用してletter-spacingを減少 |
| ブックマークボタンのタップターゲットが小さい | 32x32でWCAG推奨の48x48を下回る | 48x48に拡大してタップしやすくした |
| 学習タブのBentoカードサイズ/タイトルが不揃い | ToolCardのpaddingが18で高さが合わず、タイトルが太字 | ToolCardをminHeight=150/ padding=16に統一し、タイトルをcallout.mediumへ変更 |
| 学習ウィジェットの余白が白く、文字が埋もれる | containerBackgroundとテキストカラーがthemeと合っていない | ウィジェット内に背景を敷き、text/secondaryTextをthemeベースに統一 |
| 学習タブのBentoのアイコン/カードサイズが揃わない | アイコンが固定フレームでなく、カード高さもminHeightで揺らいでいた | アイコンを96固定フレーム化し、カード高さを150固定、タイトルをregularへ統一 |
| 学習ウィジェットの白い余白とレイアウト崩れ | EntryViewで背景を塗っていたがcontainerBackgroundがclearで効いていなかった | EntryViewにcontainerBackgroundを適用し、重複背景を削除して余白を解消 |
| Bentoアイコンが右寄せされない | アイコンが固定フレーム内に留まり、カード幅への寄せが不足 | maxWidth/maxHeightのフレームを追加して右上に固定 |
| 学習タブのコンテナ背景が単調 | セクションカードやメニューに奥行きが無かった | 背景アイコンを右端見切れで配置して視線の流れを作る |
| 横区切り線が薄く見える | 透明度が低く境界が弱い | 区切り線の不透明度を上げて視認性を改善 |
| 学習タブにWindowsロゴ風のアイコンが見える | 背景装飾に`square.grid.2x2.fill`を使っており誤認されやすい | 学習文脈の`graduationcap.fill`へ差し替え |
| 学習タブのカード内アイコンが中央寄りで弱い | アイコンがカード内に収まり、右端の見切れ演出が不足 | アイコンを右へオフセットしてカード内で見切れさせる |
| 学習タブRecommended/チャプター/日数選択がカードで重い | 各行が丸角カード+影で情報量が多く見えた | 背景/影を外して上下境界線のみのリスト行に統一 |
| レポートの総学習時間が「時間/分」表記 | 単位が日本語でサイズも大きく見えて重い | h/m表記に変更し、unitをcaption2/lightで小さく細くした |
| 英単語クイズ前画面が横にはみ出す | ヘッダーとランクアップボタンの文言が長く1行で溢れていた | lineLimitとminimumScaleFactorで収めるよう調整 |
| クイズ画面で音声アイコンとブックマークが重なる | 問題行の右端に音声アイコンが配置されていた | 音声アイコンを削除して重なりを解消 |
| ブラック系ウィジェットの文字/余白が埋もれる | ダーク連動不足と文字コントラスト/余白の弱さ | ブラック3種のみ色解決をダーク連動し、ラベルと単位のコントラスト/余白を調整 |

### 機能追加

| 追加機能 | 内容 |
|---------|------|
| ジャーナル（気分/メモ） | `CalendarView`の学習記録編集に「ジャーナル」を追加し、日付ごとに気分とメモを保存/閲覧できるようにした（Supabase同期はLearningStats内に統合） |
| 3日間学習 Day3 音声入力 | InputModeのDay3に音声入力（SpeechTranscriber）を追加し、発音確認を行えるようにした |
| バックアップ（JSONエクスポート） | 管理画面から`anki_hub_*`の設定・学習データをJSONとしてエクスポートできるようにした |

### ビルド関連

| 症状 | 原因 | 解決策 |
|------|------|--------|
| `BookshelfView`でビルドエラー | パッチ適用時に`+`が残り構文崩れ | `+`を除去しフォーム構造を復元 |
| `SyncManager`で`TimelineManager`/`StudyMaterialManager`が見つからない | SwiftPMターゲット間の可視性不足 | マネージャー本体/共有インスタンス/公開APIを`public`化 |
| `CalendarView` / `StudyView` 重複定義エラー | `StatCard`, `SubjectCard`等が複数ファイルで定義 | コンポーネントを`Components/`ディレクトリに外部化し、重複を削除 |
| `SettingsView`の`accountSection`で構文崩れ | パッチ適用の差分競合でView構造が破損 | `accountSection`を再構築し`SettingsIcon`統一のレイアウトに修正 |
| `CalendarView.swift`が空ファイルになりビルド不能 | ファイル内容が消失 | git履歴から復旧し、`CalendarStatCard`/`DayCell`に適合させた |
| `xcodebuild`でiPhone 16 Proが見つからない | `OS:latest`が26.2になり対象端末が存在しない | `-destination`に`OS=18.2`を明示 |

### UI刷新・リファクタリング
- **Apple HIG準拠**: 設定画面やプロフィール画面のリストスタイルを`insetGrouped`に統一し、アイコンデザインを`SettingsIcon`コンポーネントで標準化。
- **コンポーネント外部化**:
  - `CalendarComponents.swift`: `CalendarStatCard`, `DayCell`
  - `DashboardComponents.swift`: `StatCard`, `SubjectCard`, `ToolCard`, `GoalCountdownCard`
  - `SettingsIcon.swift`: 設定系画面のアイコン統一
- **Liquid Glass適用**: 各種カードUIに統一されたBlurエフェクトとシャドウを適用。
- **BookshelfView UI改善**:
  - カード背景を不透明化し、コントラストを強化してフラットデザインに近づけた
  - アイコンを大きくし、パステル背景色（opacity 0.25）を採用
  - タイポグラフィ階層を改善：数字を大きく（title3.weight(.bold)）、見出しを太字に
  - 空の状態を魅力的に：ポジティブなメッセージとグラデーションアイコン、カラフルなボタンに
  - 検索バーをモダンなデザインに：アイコン拡大、背景不透明化、ボーダー追加
- **DashboardComponents改善**:
  - StatCard：数字を大きく（title.weight(.bold)）、アイコンをパステル背景で強調
  - SubjectCard：アイコンを64x64に拡大、パステル背景とシャドウで統一感を向上
  - ToolCard：アイコンを50x50に拡大、統一されたパステルデザインを採用
  - GoalCountdownCard：タイポグラフィを強化し、日付表示を太字に改善
- **DashboardView改善**:
  - Recommendedセクションの全カードを統一デザインに改善
  - liquidGlassから不透明背景とシャドウのモダンデザインに変更
  - アイコンを36x36のパステル背景で強調
  - タイポグラフィを改善：見出しを太字に、サブテキストをmediumウェイトに
  - 復習待ち、タイムライン、復習待ち、今日の復習、やることリスト、テスト履歴、タイマーカードを改善

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
