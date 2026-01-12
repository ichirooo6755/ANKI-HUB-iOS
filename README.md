# ANKI-HUB-iOS

## Bug Fix Log

### 2026-01-12: マイページ/設定の統合 + テーマ(Liquid Glass/カラープリセット)がページごとに揺れる
- **症状**:
  - マイページと設定が別ページ/別UIのように見えて、体験が分断される。
  - カラープリセット（テーマ色）がページによって効いていないように見える（タブ選択色が固定、背景が白っぽい等）。
  - Liquid Glass（コンテナ背景）がページによって効いている/いないが混在し、見た目が揺れる。
- **原因**:
  - 画面によって `applyAppTheme()` の適用が漏れており、`tint` が固定値（例: `.tint(.blue)`）になっていた。
  - `.regularMaterial` / `.ultraThinMaterial` の直貼りが残っており、独自の `liquidGlass()` と混在していた。
  - 壁紙未設定時の背景が `background/surface` のみで構成され、テーマによっては白背景寄りに見えていた。
- **解決策**:
  - 設定（マイページ）を `SettingsView` に統一し、アカウント/学習統計/学習/外観/同期/情報の構成で整理。
  - `SettingsView` / `ContentView` に `applyAppTheme()` を適用し、固定 `tint(.blue)` を撤去してカラープリセットが全ページで反映されるようにした。
  - 直貼りMaterialを `liquidGlass(cornerRadius:)` / `liquidGlassCircle()` に置換し、ページ間でコンテナ表現が揺れないよう統一。
  - 壁紙未設定時の背景は `ThemeManager.backgroundGradient` でテーマ色をブレンドしたグラデーションに変更し、白背景感を抑制。

### 2026-01-12: InputModeの答え側がテーマ未適用・英語混在（カードUIの不一致）
- **症状**:
  - InputModeで「Known/Unknown」「Chapter」「Complete」など英語が混在する。
  - 答え側（意味/ヒント/読み）がテーマに追従せず、ダークで薄い/読みにくいことがある。
  - Day3が「タップで答えを表示」と出るのに、実際には答えが表示されない/カードUIが他画面と違う。
- **原因**:
  - 文字色が `opacity` 二重指定や固定表現のままで、`ThemeManager.primaryText/secondaryText` を使っていなかった。
  - Day3の「表示トリガ（状態）」が無く、表示文言のみ存在していた。
  - 一部が独自スタイルで `liquidGlass()` と統一されていなかった。
- **解決策**:
  - 文言を日本語化（「わかる/わからない」「チャプター」「◯日目 完了」など）。
  - 答え/補助情報の色を `ThemeManager.primaryText/secondaryText` に統一し、ダーク/ライトで可読性が落ちないよう調整。
  - Day3に `showDay3Answer` を追加し、タップで答え（意味＋ヒント/読み）を表示するUIに修正。
  - Day3の判定ボタンも `liquidGlass(cornerRadius:)` + テーマ色ボーダーで統一。

### 2026-01-12: モード別テーマ（ライト/ダーク別テーマ）を廃止し、単一プリセット+外観設定に統一
- **症状**:
  - 設定やWebView（政経）などで、テーマや外観の判定が複数系統になって挙動が分かりにくい。
  - ページによって「どの基準でダーク判定しているか」が揺れる。
- **原因**:
  - `ThemeManager` に `useDualTheme` / `lightModeTheme` / `darkModeTheme` / `currentTheme(AppTheme)` が混在し、外観判定の責務が分散していた。
  - `SeikeiWebView` が `currentTheme` に依存して `overrideUserInterfaceStyle` を決めていた。
- **解決策**:
  - ライト/ダーク別テーマ設定（dual theme）を削除し、テーマ選択は `selectedThemeId` に一本化。
  - 外観は `colorSchemeOverride`（システム/ライト/ダーク）のみで決まるよう整理。
  - `SeikeiWebView` は `effectivePreferredColorScheme` に追従して `overrideUserInterfaceStyle` を設定し、シグネチャも外観設定を含めるよう修正。
  - `cardBackground` を `.ultraThinMaterial` 依存からテーマ `surface` ベースへ変更して、背景/コンテナの一貫性を改善。

### 2026-01-12: 一部カラープリセットでコンテナ内の文字が同化する
- **症状**:
  - テーマ（カラープリセット）によって、コンテナ（カード/行）の中の文字が背景と同系色になり読みにくい。
- **原因**:
  - `ThemePalette.text/secondary` がプリセットにより背景（surface）とコントラスト不足になることがあり、固定の文字色をそのまま使うと可読性が担保できない。
- **解決策**:
  - `ThemeManager` にコントラスト比（輝度）ベースの補正（`readableTextColor`）を追加し、`primaryText/secondaryText` が最低コントラストを満たすよう自動で補正。

### 2026-01-12: サイバーパンク等の暗色プリセットがライト外観で暗すぎる
- **症状**:
  - 外観がライト（システムライト/ライト固定）のとき、サイバーパンク等のプリセットで背景/コンテナが暗いままになり、文字が同化して読めない。
- **原因**:
  - 一部プリセットの `background/surface/text` がライト用としては暗色寄りの配色のまま定義されていた。
- **解決策**:
  - 対象プリセット（例: cyberpunk / dracula / neonStreet / nightView）のライト側配色を明るいトーンへ調整し、暗色配色は `*Dark` 側に寄せて、ライト/ダーク双方で可読性を確保。

### 2026-01-12: Googleログイン後にアプリへ戻らずWeb側に残ることがある
- **症状**:
  - Googleログインを押すと、以前のWebセッション（古いSupabase関連ページ等）に遷移してしまい、アプリへ戻ってこないことがある。
- **原因**:
  - `ASWebAuthenticationSession` が既存Cookie/セッションを引き継いでしまい、意図しないリダイレクトが発生するケースがある。
- **解決策**:
  - `ASWebAuthenticationSession.prefersEphemeralWebBrowserSession = true` にして、エフェメラル（クッキーなし）セッションで認証を開始するように変更。

### 2026-01-12: ウィジェットに「間違えた単語と答え」を表示し、教科フィルタをアプリから設定
- **症状**:
  - ウィジェットで「間違えた単語 → 答え」を表示したい。
  - ロック画面ウィジェット（アクセサリ）でも同様に表示したい。
  - 教科（英語/英検/古文/漢文/政経）をアプリ側からフィルタできるようにしたい。
- **原因**:
  - 直近ミスが単発保存のみで、複数件の表示やフィルタができなかった。
  - Widget側で教科フィルタ設定を参照していなかった。
- **解決策**:
  - アプリ側で直近ミスをリスト形式（最大20件）でも保存し、Widgetで最大3件（表示サイズに応じて1〜2件）を表示。
  - `SettingsView` に「ウィジェット教科」設定を追加し、App Groupの `UserDefaults` に保存してWidgetに反映。
  - iOSではロック画面用の `.accessoryInline` / `.accessoryRectangular` もサポート（macOSターゲットでは除外してビルド可能に）。

### 2026-01-12: ToDo/テスト履歴が⚠️のアイコンになる（環境によって表示されない）
- **症状**:
  - 「やることリスト」や「テスト履歴」などのアイコンが⚠️になってしまい、表示が不安定に見える。
- **原因**:
  - 一部の環境/OSで未対応のSF Symbols名を使うと代替の警告アイコンになることがある。
- **解決策**:
  - 互換性の高いSF Symbols（例: `list.bullet`, `doc.text`）へ置換して、環境依存の⚠️表示を回避。

### 2026-01-12: 古文データはCSV優先、PDFは不足分のみ補完したい
- **症状**:
  - `kobun_pdf.json` 優先だと、CSV側で整備した単語・表記・意味が反映されず、差分の管理が難しい。
  - ただしPDFにしか無い単語もあるため、完全にPDFを捨てると欠けが出る。
- **原因**:
  - 古文データのロード順（優先順位）が `kobun_pdf.json` → `kobun.json` になっており、CSV側を正として扱えなかった。
- **解決策**:
  - アプリ内の古文ロードを `kobun.json`（CSV）優先に変更し、`kobun.json` に存在しない単語のみ `kobun_pdf.json` から追加してマージ。
  - `Tools/update_kobun_json.py` も同方針で、CSV生成後に `kobun_pdf.json` を補完データとして取り込み、欠けている単語のみを追加できるようにした。

### 2026-01-12: 集中した時間（Today）と連続学習日数（Streak）が増えない/不安定
- **症状**:
  - タイマーで勉強しても「今日の学習（分）」が増えないことがある。
  - 連続学習日数（Streak）が増えない/日付跨ぎでズレることがある。
- **原因**:
  - タイマーの学習記録が「0到達後に停止して保存した場合」に限定されており、途中停止や未入力だと学習分が記録されない。
  - `LearningStats.todayMinutes` が保存値ベースで、起動/同期反映後に `dailyHistory` の今日分から再計算されず、表示がズレることがある。
- **解決策**:
  - タイマーは途中停止でも一定時間経過していれば記録できるようにし、入力必須を解除（集中/カスタムのみ学習分として加算）。
  - `LearningStats` は起動・同期反映時に `dailyHistory` の今日分から `todayMinutes` を復元し、`streak` を再計算して安定化。

### 2026-01-12: マイページにカラープリセットが適用されていないように見える
- **症状**:
  - マイページ（設定）のListがシステム標準の行背景に戻り、テーマのsurface/背景と一体にならず「テーマが効いていない」ように見える。
- **原因**:
  - `List` の行背景がデフォルト（白/半透明）になりやすく、背景を隠していても行背景がテーマ外で残る。
- **解決策**:
  - `SettingsView` の `List` に `listRowBackground(theme surface)` を適用し、行背景をテーマのsurfaceに統一。

### 2026-01-12: Total Mastery / Weekly Activity / 教科別が動かない（0に見える）
- **症状**:
  - Total Mastery/週間/教科別のグラフが「動かない」「0のまま」に見える。
- **原因**:
  - 週間の可視化が `words` だけだと、タイマー学習（minutesのみ増える）では棒が伸びず、動いていないように見える。
  - 教科別は `dailyHistory[*].subjects` が0の場合、空で何も表示されず誤解を招く。
- **解決策**:
  - `Weekly Activity` を `minutes`（学習分）ベースで可視化し、タイマー学習も反映されるよう修正。
  - 教科別が空のときはガイド文を表示して、記録方法が分かるようにした。

### 2026-01-12: InputModeの設定画面がスクロールできない
- **症状**:
  - 画面が小さい端末で InputMode の設定（開始前）UIが下まで到達できず、スクロールできない。
- **原因**:
  - `words.isEmpty` 時の設定UIが `VStack` 固定で、`ScrollView` になっていなかった。
- **解決策**:
  - `words.isEmpty` 時の設定UIを `ScrollView` 化し、全要素にアクセスできるようにした。

### 2026-01-12: ToDoが端末間で同期されない / loadAll後に画面に反映されない
- **症状**:
  - ToDoを追加/編集/完了しても、別端末へ同期されない。
  - `loadAll` 後にUserDefaultsは更新されているのに、ToDo画面が更新されず古い表示のままになることがある。
- **原因**:
  - Supabase同期（`SyncManager.performSyncAll/performLoadAll`）の対象に `anki_hub_todo_items_v1` が含まれていなかった。
  - `loadAll` によりUserDefaultsが更新されても、ToDo画面側がその更新を購読していなかった。
- **解決策**:
  - `SyncManager` にToDo（`todo`）のupsert/fetchを追加して同期対象に含めた。
  - `loadAll` でToDoを反映した際に通知を投げ、`TodoManager` が再ロードするようにして画面更新を安定化。

### 2026-01-12: InputModeで「間違えた単語だけ」を復習したい
- **症状**:
  - InputModeで直近に間違えた単語だけを集中的に回したい。
- **原因**:
  - InputMode側に「直近ミス」のデータソース（`anki_hub_recent_mistakes_v1`）を参照する導線が無かった。
- **解決策**:
  - InputModeに「間違えた単語だけ」トグルを追加し、`anki_hub_recent_mistakes_v1` から教科別にwordIdを抽出してフィルタするようにした。

### 2026-01-12: ウィジェットの内容/見た目をアプリ側で変更したい・間違えた単語を定期的に切り替えたい
- **症状**:
  - ウィジェットで表示する内容（連続/今日/間違えた単語）や見た目を変更したい。
  - 間違えた単語の表示が固定で、1時間に1回くらい変えたい。
- **原因**:
  - ウィジェット側の表示が固定で、App側の設定値を参照していなかった。
  - タイムライン更新が短い間隔（数分）で、時刻に応じたローテーション選択が無かった。
- **解決策**:
  - `SettingsView` にウィジェット設定（表示項目/表示件数/スタイル）を追加し、App GroupのUserDefaultsへ保存してWidget側が参照するようにした。
  - ウィジェットのタイムラインを1時間間隔で生成し、時刻に応じて直近ミスの表示開始位置をずらしてローテーションするようにした。

### 2026-01-12: タイマーがオーバータイムになると進行中画面に戻れない / 学習時間のカウントが不安定
- **症状**:
  - タイマーが0到達してオーバータイムになった後、画面遷移やバックグラウンド復帰を挟むと「進行中のタイマー」に戻れないことがある。
  - タイマー学習の学習時間が `Weekly Activity` 等に反映されない/ズレることがある。
- **原因**:
  - 進行中タイマーの状態（開始/終了予定/残り/オーバータイム）がViewの `@State` のみで、復帰時に復元できない。
  - タイマー学習は `recordStudyMinutes` 経由で記録され、教科別/セッション系の集計と経路が分かれていた。
- **解決策**:
  - `PomodoroView` でタイマー状態をUserDefaultsに永続化し、`onAppear` で復元してオーバータイム中でも継続表示できるようにした。
  - タイマーの学習時間記録を `recordStudySession(subject:"", wordsStudied:0, minutes:...)` に統一し、週間グラフ等への反映を安定化。

### 2026-01-12: タイピング回答で「入力が答えに含まれていれば正解」にしたい
- **症状**:
  - タイピングモードで、長い答えの一部を打てていても不正解になる。
- **原因**:
  - 判定が `isFuzzyMatch`（距離ベース）中心で、部分一致（contains）判定が無かった。
- **解決策**:
  - タイピング判定に部分一致（`answer.contains(typed)`、最小3文字）を追加し、長い答えでも運用しやすくした。

### 2026-01-12: ストップウォッチのラップが未実装（プレースホルダーのまま）
- **症状**:
  - ストップウォッチ画面に旗ボタンがあるが、押しても何も起きない。
- **原因**:
  - ラップ追加/表示/クリアの状態管理が未実装だった。
- **解決策**:
  - `PomodoroView` に `stopwatchLaps` を追加し、ラップ追加/一覧表示/クリア/リセット時の消去を実装。

### 2026-01-12: タイマー使用中に動作が重い・電池消費が大きい
- **症状**:
  - タイマー/ストップウォッチ利用中にCPU使用率が上がり、動作が重い・電池の減りが早い。
- **原因**:
  - ストップウォッチが 0.01 秒間隔で `Timer` 更新しており、頻繁なウェイクアップで負荷が高かった。
  - タイマー状態の永続化が毎秒のように実行され、UserDefaults書き込みが多かった。
  - タイマー文字盤の目盛り（60本）を毎回再生成して描画していた。
- **解決策**:
  - ストップウォッチは「開始時刻 + 経過秒」方式に変更し、UI更新頻度を 0.2 秒に抑制。
  - タイマー状態の永続化をスロットリング（15秒に1回）し、バックグラウンド遷移時だけ強制保存。
  - 目盛り描画を `TickMarksView` に分離し `drawingGroup()` でキャッシュ寄りにして描画負荷を軽減。

### 2026-01-13: Total Mastery が0に見える / ウィジェットからタイマー開始 / ウィジェットにタイマー分数を保存
- **症状**:
  - `Total Mastery（習熟度）` のドーナツが0のまま、または動いていないように見える。
  - ウィジェットから「タイマー開始」ができない。
  - ウィジェットで開始するタイマー分数をアプリ側で保存しておきたい。
- **原因**:
  - `DashboardCharts` の合算が「追跡済み（MasteryTracker.itemsに存在する単語）」のみを集計しており、`.new（未学習）` を総語彙数から算出していなかった。
  - `MasteryTracker.loadData()` 時に `LearningStats` のスナップショットへ反映が無く、起動直後に表示が0になりやすかった。
  - ウィジェットにタイマー起動の導線（ディープリンク）が無かった。
  - ウィジェットのタイマー分数をApp Groupへ保存して参照する仕組みが無かった。
- **解決策**:
  - `DashboardCharts` で全教科の総単語数を合算し、`trackedCount` との差分で `.new` を算出してドーナツに反映。
  - `MasteryTracker.loadData()` で `LearningStats.applyMasterySnapshot(...)` を呼び、起動時表示を安定化。
  - ウィジェットに `sugwranki://timer/start?minutes=...` の `Link` を追加し、App側で `onOpenURL` 受信→`PomodoroView` を開いて自動開始。
  - `SettingsView` に「ウィジェット: タイマー（分）」を追加し、App GroupのUserDefaults（`anki_hub_widget_timer_minutes_v1`）へ保存してWidget側で参照。

### 2026-01-13: カラープリセット（theme-system.js由来）を全追加
- **症状**:
  - Web側（`theme-system.js`）にあるカラープリセットをiOS側で選べず、テーマ一覧に不足がある。
- **原因**:
  - iOS側の `ThemeManager.presets` がWeb側のプリセット一覧に追従しておらず、定義が一部のみだった。
- **解決策**:
  - `color_presets_list.md` の全ID/色コードを `ThemeManager.presets` に追加し、テーマ選択UIから選択可能にした。
  - `getThemeName` に表示名マッピングを追加し、一覧で英語IDが露出しないように調整。

### 2026-01-13: InputModeのスクロール不可 / OCRクラッシュ / マイページ・学習タブのテーマ不整合 / ToDo・テスト履歴が使えない
- **症状**:
  - インプットモード（集中暗記）の画面でスクロールできず、端末サイズによってはUIが画面外に逃げる。
  - OCR/スキャン機能を使おうとするとクラッシュする（またはSimで使えない）。
  - 学習タブ/マイページで一部コンテナの背景や文字色がテーマに追従せず、白/黒固定っぽく見える。
  - やることリスト/テスト点数記録の機能が見つからず、実質使えない。
- **原因**:
  - `FocusedMemorizationView` の一部画面が `ScrollView` ではなく `VStack + Spacer` 依存だった。
  - `Info.plist` にカメラ利用許可（`NSCameraUsageDescription`）が無く、実機で起動時に落ちる可能性があった。
  - VisionKitスキャナ非対応環境（特にSimulator）でのガードが無かった。
  - 一部カード/ラベルが `.secondary` 等に依存しており、テーマ側の `text/surface` とズレるケースがあった。
  - ToDo/テスト履歴への導線がマイページ側に無かった。
- **解決策**:
  - `FocusedMemorizationView` の該当画面を `ScrollView` 化。
  - `Info.plist` に `NSCameraUsageDescription` を追加。
  - `VNDocumentCameraViewController.isSupported` をチェックし、非対応時はアラート表示にしてクラッシュ回避。
  - 学習/マイページのカードやリスト背景・文字色を `ThemeManager` 基準に寄せて統一。
  - `SettingsView`（マイページ）に「やることリスト」「テスト履歴」への導線を追加。

### 2026-01-11: PomodoroView のビルド失敗（accent参照/opaque return type）
- **症状**:
  - `PomodoroView.swift` のコンパイルで `cannot find 'accent' in scope` / `function declares an opaque return type, but has no return statements...` が出てビルドが失敗する。
- **原因**:
  - `stopwatchView` 内で `let accent = ...` を `ZStack` のローカルスコープに置いたまま、下部のボタン側でも参照していた。
  - `stopwatchView` の先頭に `let accent = ...` を置いたことで SwiftUI の implicit return が効かず、`some View` の推論ができなくなっていた。
- **解決策**:
  - `accent` を `stopwatchView` のスコープに移動。
  - `return VStack { ... }` の形にして明示的に返すよう修正。

### 2026-01-11: テーマによってボタン文字が読めない（固定色 `.white` 等）
- **症状**:
  - 壁紙/テーマによってボタン文字やアイコンが背景に埋もれて読めない。
- **原因**:
  - `.foregroundStyle(.white)` などの固定色が多数残っており、背景色とコントラストが取れないテーマが存在した。
- **解決策**:
  - `ThemeManager.onColor(for:)` と `Color.relativeLuminance` を使い、背景色から自動で文字色を選択するよう置換。

### 2026-01-11: 写真壁紙でコンテナが見えない（Liquid Glassの透明度不足）
- **症状**:
  - 壁紙を写真/画像にすると、各画面のコンテナ（カード/セクション）が背景に溶けて境界が分かりにくい。
  - テキストの可読性が落ち、「表示されていない」ように見えることがある。
- **原因**:
  - `LiquidGlassModifier` の `.ultraThinMaterial` と `surface.opacity(...)` が写真背景に対して薄すぎ、背景の模様が透けてしまう。
- **解決策**:
  - `wallpaperKind == photo || bundle` のときだけ、
    - `surface` の不透明度を増加
    - ボーダー/シャドウを強化
    してコンテナの視認性を確保。

### 2026-01-11: 過去問点数登録に「大学名/学部」が保存できない
- **症状**:
  - 過去問スコア登録で「教科（科目）/学部/大学名」も一緒に記録したいが、保存項目が無く一覧や分析に出ない。
- **原因**:
  - `ExamResult` が `subject` 以外の属性（大学名/学部）を持っておらず、入力UIも未実装だった。
- **解決策**:
  - `ExamResult` に `university` / `faculty` を追加（既存データは空文字で後方互換）。
  - `ExamHistoryView` の追加フォーム/一覧/詳細に表示を追加。
  - `PastExamAnalysisView` の簡易追加フォームにも入力欄を追加し、新しい保存APIに接続。

### 2026-01-11: タイマーが0になっても通知/記録が残らない・0以降を計れない
- **症状**:
  - タイマーが0になっても通知が来ない/気づけない。
  - 0以降にどれだけ続けたか（超過時間）が分からない。
  - 終了時に「何を勉強したか」を記録できず、開始時刻のログも残らない。
- **原因**:
  - `PomodoroView` が0到達後に即停止する前提で、オーバータイム表示/ログ保存の導線がなかった。
  - 終了通知は日次リマインド用のみで、タイマー終了専用の通知スケジューリングがなかった。
- **解決策**:
  - `PomodoroView` に以下を追加:
    - 0到達時にローカル通知をスケジュール
    - 0到達後は `+mm:ss` でカウントアップ（オーバータイム）
    - 停止時に学習内容入力シートを出し、開始/終了時刻・モード・予定秒・超過秒・学習内容をUserDefaultsへ保存

### 2026-01-11: 教科別グラフが無い（学習状況を教科ごとに把握できない）
- **症状**:
  - 学習状況のグラフが全体集計しかなく、どの教科をどれだけやったかが一目で分からない。
- **原因**:
  - `LearningStats.dailyHistory` には `subjects`（教科別の語数）があるが、UI側で可視化していなかった。
- **解決策**:
  - `DashboardCharts` に「教科別（直近7日）」の棒グラフを追加し、`dailyHistory[*].subjects` を集計して表示。

### 2026-01-11: ダークモードでInputMode/カードモードの答えが背景に埋もれる
- **症状**:
  - ダークモードで `InputModeView` の意味（答え）が薄く、背景と同化して読みづらい。
  - カード表示（`FlashcardView`）で答え側のコントラストが不足し、見にくい。
- **原因**:
  - `InputModeView` の意味表示が `.secondary` などシステム寄りの薄い色指定になっていた。
  - `FlashcardView` のカード背景がダーク時に透けすぎ（`surface.opacity` が低い）で、壁紙/背景の影響を強く受けていた。
- **解決策**:
  - `InputModeView` の意味表示をテーマの `text` 色ベースに変更。
  - `FlashcardView` のカード背景不透明度を引き上げ、壁紙/ライト・ダークに依存せず常に高コントラストで読めるように調整。

### 2026-01-11: Streak/Todayが増えない・Total Masteryが見えない・Liquid Glassが効かない
- **症状**:
  - `Streak` が 1日 / `Today` が数分などに固定され、学習しても増えにくい。
  - `Total Mastery` の数字が見えない／桁数が増えると表示が崩れてダサい。
  - `Liquid Glass（コンテナ背景）` をON/OFFしても見た目が変わらず「効いていない」ように見える。
- **原因**:
  - `LearningStats.calculateStreak()` が `dailyHistory[*].words > 0` のみを活動扱いにしており、タイマー学習など「分だけ」記録される学習がStreak対象外だった。
  - `masteredCount` などの集計が `MasteryTracker` の更新に追従しておらず、UI上の表示が古い値のままになることがあった。
  - `DashboardCharts` がドーナツの各セクションに小さな数値アノテーションを重ねており、桁数が増えると読みづらい。
  - `liquidGlass()` が `ThemeManager.useLiquidGlass` の変更に追従するための監視が弱く、再描画されにくい構造だった。
- **解決策**:
  - `LearningStats` を「語数 or 分」で活動扱いに変更し、タイマー/インプットモードからも学習分を記録するようにした。
  - `MasteryTracker.saveData()` のタイミングで `LearningStats` へ集計スナップショット（mastered/learning/total/rate）を反映するようにした。
  - `DashboardCharts` はドーナツ中心に `Mastered` 合計を可変フォントで表示し、桁数でも崩れにくいUIに変更。
  - `liquidGlass()` を `ThemeManager` を監視する `AdaptiveLiquidGlassModifier` 経由に統一し、ON/OFFが即反映されるようにした。

### 2026-01-11: 写真壁紙でコンテンツが異常に拡大される
- **症状**:
  - 壁紙を写真/画像にすると、画面全体の表示が拡大されたようになりUIが崩れる。
- **原因**:
  - 壁紙画像の描画がレイアウト確定前のサイズ推論に引っ張られ、`scaledToFill` が意図しないスケールで評価されるケースがあった。
- **解決策**:
  - `ThemeManager.background` の壁紙画像描画を `GeometryReader` で画面サイズに固定し、`frame + clipped` でスケール暴れを抑制。

### 2026-01-11: モード別テーマが不要（単一プリセット + ライト/ダーク追従）
- **症状**:
  - モード別テーマのUI/設定が存在し、運用上の混乱や不整合（画面ごとの色のズレ）の原因になる。
- **原因**:
  - `useDualTheme`（ライト/ダークで別テーマ）が残っており、期待（単一プリセット内のLight/Darkを自動切替）と異なる。
- **解決策**:
  - `ThemeSettingsView` からモード別テーマUIを撤去。
  - 起動時に `useDualTheme` が有効なら無効化して単一プリセット運用に統一。

### 2026-01-11: 習熟度が「苦手」に偏る（不正解で即weak落ち）
- **症状**:
  - 4段階以上の習熟度があるのに、実運用上ほとんどが「苦手」や「ほぼ覚えた」に偏る。
- **原因**:
  - 不正解時の処理で `mastery = .weak` に強制していたため、上位グレードが維持されにくかった。
- **解決策**:
  - 不正解時は段階的に1段階だけ降格（`mastered→almost→learning→weak`）するように変更。

### 2026-01-10: 設定画面（SettingsView）のビルド失敗（型チェックタイムアウト/構文崩れ）
- **症状**:
  - `SettingsView.swift` の `var body: some View` で `the compiler is unable to type-check this expression in reasonable time` が出てビルドが失敗する。
  - 修正途中のパッチ適用で `Binding` の括弧が閉じず、構文エラーによりビルドが失敗する。
- **原因**:
  - SwiftUI `List` 内に複雑な `Binding(get:set:)`（通知時刻DatePicker）を直書きして式が肥大化し、型推論がタイムアウトした。
  - `timerLimitBinding` の `Binding(...)` が閉じられない状態に崩れていた。
- **解決策**:
  - `accountSection/studySection/appearanceSection/...` に分割し、通知時刻の `Binding` を `reminderDateBinding(for:)` に切り出して式を単純化。
  - `timerLimitBinding` の閉じ括弧を修復して構文を復旧。

### 2026-01-10: Google OAuthログイン後に「戻れない/ログインできない」ように見える
- **症状**:
  - Googleサインイン後にアプリ側がログイン状態にならず、戻れない/何も起きていないように見える。
- **原因**:
  - コールバックURLの `code` を query からしか取得しておらず、fragment（`#code=...`）で返るケースに対応できない可能性があった。
  - `AuthManager.signInWithGoogle` がエラーを握りつぶしており、失敗してもUIに何も表示されなかった。
- **解決策**:
  - `SupabaseAuthService` で `code` を query と fragment の両方から取得するようにして堅牢化。
  - `AuthManager` に `lastAuthErrorMessage` を持たせ、`AuthView/SettingsView` でアラート表示するようにして失敗理由を可視化。

### 2026-01-10: macOS互換性ビルドエラー
- **症状**: `swift build`で多数のエラー（`topBarLeading`、`NavigationView`、`#Preview`、`UIApplication`、`#if os(iOS)`入れ子など）
- **原因**:
  - `topBarLeading`や`navigationBarTitleDisplayMode`はiOS専用
  - `#Preview`マクロはPreviewsMacros必要
  - `ThemeManager.swift`の`#if os(iOS)`ブロックが入れ子で構造破壊
  - `UIApplication`はiOS専用
- **解決策**:
  - `NavigationView`を`NavigationStack`に置換
  - `navigationBarTitleDisplayMode`を`#if os(iOS)`でラップ
  - `#Preview`マクロをコメントアウト
  - `ThemeManager.swift`の`#if os(iOS)`ブロックを正しく整理
  - `UIApplication`参照を`#if os(iOS)`でラップ

### 2026-01-08: Quiz Navigation Reset Bug
- **症状**: クイズで一問回答後、セクション選択画面に戻ってしまう
- **原因**: `ChapterSelectionView.Chapter` の `id = UUID()` が View 再評価ごとに新しい ID を生成し、NavigationLink の destination が変更されたと判断されて QuizView が pop されていた
- **解決策**: `id` を `title` ベースの固定値に変更（`ChapterSelectionView.swift`）

### 2026-01-08: QuizView 学習アルゴリズム未接続/政経穴埋め不整合
- **症状**:
  - セッション履歴除外（前回正解+高速の単語除外/遅延出題）が効かない
  - 回答時間が反映されず、即答力/昇格ロジックが実態とズレる
  - 政経（憲法）穴埋めが実質「4択の正解=『穴埋め問題』」になり得る／同カテゴリ誤答が作れない
  - 政経チャプター選択が効かないケースがある
- **原因**:
  - `QuizView` が `LearningManager.selectQuestionsWithHistory` を呼ばず、`MasteryTracker.sessionHistory` も保存していなかった
  - `QuizView` から `MasteryTracker.recordAnswer` に `responseTime` を渡しておらずデフォルト値固定になっていた
  - 政経データは `meaning` がプレースホルダのため、通常の「meaning=答え」前提の出題生成が崩れていた
  - チャプター絞り込みで `Chapter ...` の数値パースが先に走り、政経の `category` 一致フィルタが使われない分岐があった
- **解決策**:
  - `QuizView` でセッションカウントを進め、`sessionId` と `responseTime` を `recordAnswer` に渡すよう修正
  - `MasteryTracker.recordAnswer` に `sessionId` を追加し、`sessionHistory`（最大20件）を保存するよう修正
  - `LearningManager.selectQuestionsWithHistory` を `QuizView.generateQuestions` の最終選定に組み込み
  - 政経（穴埋め）は `allAnswers` から「1穴=1問」を生成し、誤答は同カテゴリから抽出するよう修正
  - 政経チャプターは `category` 完全一致を優先するよう分岐を修正

### 2026-01-08: Models.swift のビルド破壊（関数の混入）
- **症状**: ビルドが通らない（`Vocabulary` 内で `currentUser` / `isInvited` / `saveUser()` 等が参照される）
- **原因**: `AuthManager.restoreSessionIfPossible()` を追加するパッチが誤って `Vocabulary` struct の中に挿入され、スコープが崩れた
- **解決策**: `restoreSessionIfPossible()` を `AuthManager` 内へ移動し、`Vocabulary` から混入分を削除

### 2026-01-08: 同期（デバウンス/レート制限）の仕様ズレ
- **症状**: 仕様v2の `storage.js` にある `DEBOUNCE_MS=2000` / `MIN_LOAD_INTERVAL=30000` 相当の挙動がiOS側に無く、短時間に同期を連打できてしまう
- **原因**: `SyncManager` が「即時同期」前提の実装だった
- **解決策**: `SyncManager.syncAllDebounced()`（2秒デバウンス）と `loadAll(force:)`（30秒レート制限）を実装し、UIの同期ボタン呼び出しもデバウンス版へ統一

### 2026-01-08: study.app_id の `stats` 名称不一致（互換対応）
- **症状**: 仕様では `app_id='stats'` だが、旧実装で `learning_stats` を使っていたため、クラウド側にデータが分散/ロードできない可能性がある
- **原因**: iOS側の `SyncManager.AppID.stats` が仕様と異なる文字列を使っていた
- **解決策**: 書き込みは `stats` に統一しつつ、読み込みは `stats` が無い場合に `learning_stats` をフォールバックで読むようにして後方互換を確保

### 2026-01-08: 紙単語帳同期がサンプル固定データ
- **症状**: `PaperWordbookSyncView` が固定サンプル（1-10）しか同期できず、実際の単語帳番号と一致しない
- **原因**: 実データ（`vocab1900.tsv`）とのマッピング未実装
- **解決策**: `VocabularyData.shared.getVocabulary(for: .english)` を番号（TSVのID）で索引化し、入力番号→単語を実データから取得するように修正

### 2026-01-08: テーマ/壁紙/習熟度色の保存・同期が未実装
- **症状**:
  - 壁紙ギャラリーで選んでも反映/保存されない
  - 習熟度カラー編集が保存されず、再起動や同期で反映されない
- **原因**: `WallpaperGalleryView` / `MasteryColorEditorView` が `ThemeManager` の永続化APIに接続されていなかった
- **解決策**:
  - `ThemeManager.applyWallpaper` / `ThemeManager.applyMasteryColors` を実装し、`SyncManager` の `theme` 同期に `wallpaperKind/wallpaperValue/masteryColors` を含める
  - `WallpaperGalleryView` と `MasteryColorEditorView` を上記APIに接続し、変更時に自動同期を発火

### 2026-01-08: 仕様v1の eiken 教科がアプリに存在しない
- **症状**: 仕様の同期対象に `eiken` があるが、アプリ側で教科選択/習熟度/同期が扱えない
- **原因**: `Subject` / `VocabularyData` / 各画面・同期ループに `eiken` を追加していなかった
- **解決策**:
  - `Subject.eiken` を追加し、`VocabularyData`/`ChapterSelectionView`/`WeakWordsView`/`Dashboard`/`SyncManager`/`RankUpManager`/`QuizView(読み上げ)` を `eiken` 対応
  - データは暫定で `english` を流用（リソース追加が必要なら別途差し替え可能）

### 2026-01-08: 3日集中（FocusedMemorization）が古文固定
- **症状**: 英単語/英検から「3日集中」を開いても古文の語彙で動く、学習結果が `kobun` に保存される
- **原因**: `FocusedMemorizationView` が `VocabularyData.getVocabulary(for: .kobun)` と `masteryTracker.recordAnswer(subject: "kobun")` を固定で使用していた
- **解決策**: 起動教科を受け取り、画面内でも教科切替できるようにして、語彙ロード/ブロック計算/保存キー/習熟度更新をすべて選択教科に紐付け

### 2026-01-08: 3日集中（FocusedMemorization）のデフォルト秒数
- **症状**: 仕様v2の Day2 は 1.5秒/語だが、iOS側のデフォルトが異なる
- **原因**: 初期値が仕様からズレていた
- **解決策**: Day2のデフォルトを 1.5秒、Day3のデフォルトを 1.0秒に調整

### 2026-01-08: OCR（TextRecognitionService）がビルド失敗
- **症状**: `TextRecognitionService.swift` で `request.results` の扱いが原因でコンパイルエラー
- **原因**: `request.results as? [VNRecognizedTextObservation]` が Optional なのに `compactMap` を直接呼んでいた
- **解決策**: `((...) ?? [])` で空配列フォールバックしてから `compactMap` するよう修正

### 2026-01-08: 誤答通報（QuizView）がビルド失敗
- **症状**: `QuizView.swift` で `currentChosenAnswerText` / `submitMistakeReport` などが見つからずコンパイルエラー
- **原因**:
  - 誤答通報用のヘルパー関数が誤って `OverlayFeedbackView` のスコープ内に入っていた
  - `SupabaseMistakeReportService.swift` が Xcode ターゲット（Sources）に入っていなかった
- **解決策**: ヘルパー関数を `QuizView` に移動し、`SupabaseMistakeReportService.swift` をターゲットへ追加

### 2026-01-08: チャプター進捗が常に0%（ChapterSelectionView）
- **症状**: チャプター選択画面の進捗リングが常に 0.0 のまま、政経のロック解除も進まない
- **原因**: `ChapterSelectionView.getProgress` が placeholder 実装（常に 0.0）だった
- **解決策**: `VocabularyData` のチャプター範囲と `MasteryTracker` の習熟度（almost/mastered）から進捗率を計算するよう実装

### 2026-01-08: テーマ一覧のプレビュー取得が不完全
- **症状**: テーマ選択カードが選択前のパレットを取得できず、プレビュー色が不安定
- **原因**: `ThemeManager` がプリセットパレット参照APIを公開していなかった
- **解決策**: `ThemeManager.getPalette(id:)` を追加して、テーマ一覧/プレビューが状態を変えずにパレット取得できるようにした

### 2026-01-08: 政経（憲法）穴埋めの意味が固定文言
- **症状**: 政経の穴埋め問題データ（`questionType="blank"`）の `meaning` が常に「穴埋め問題」になり、一覧/エクスポートで情報量が少ない
- **原因**: `DataParser.parseConstitutionData` が placeholder の固定文字列を入れていた
- **解決策**: `meaning` を「穴埋め（N箇所）」のように、実際の穴埋め数に基づく文字列に変更

### 2026-01-08: 漢文のチャプター選択が出題に反映されない
- **症状**: `ChapterSelectionView` で漢文の章（基本句形/否定形…）を選んでも、出題が全範囲のまま
- **原因**: `QuizView.filterVocabByChapter` が `subject == .kanbun` の場合に絞り込みをせず全件返していた
- **解決策**: `Vocabulary.category == chapter` でフィルタして、選択章が出題に反映されるよう修正

### 2026-01-08: 政経（憲法）穴埋めで前に埋めた穴が次の問題で消える
- **症状**: 同一条文の複数穴を順番に解く際、前に正解して開示した穴が次の穴の問題でリセットされることがある
- **原因**: `SeikeiWebView` が `updateUIView` のたびに HTML を再ロードし、DOM上の開示状態が消えていた
- **解決策**: `content/blankMap` が変わらない限り WKWebView のHTMLを再ロードしないようにし、開示状態を保持する

### 2026-01-08: QuizCaptureView がビルド失敗（未定義変数）
- **症状**: `QuizCaptureView.swift` のコンパイルで `cannot find 'extractedText' in scope`
- **原因**: リファクタ後に `extractedText` というStateが存在しないのにリセット処理だけ残っていた
- **解決策**: `recognizedText` / `extractedWords` をリセットし、`showResults` を戻すよう修正

### 2026-01-08: OCR/QuizCapture/QuizView 経由の単語帳更新が自動同期されない
- **症状**: OCRやクイズキャプチャ、クイズ画面の「単語帳に追加」で追加した単語がクラウドに反映されないことがある
- **原因**: `UserDefaults` 保存後に `SyncManager.requestAutoSync()` を呼ばない経路があった
- **解決策**: 保存直後に `Task { @MainActor in SyncManager.shared.requestAutoSync() }` を呼ぶようにして自動同期を統一

### 2026-01-08: 政経（憲法）穴埋めの revealAll が動かない
- **症状**: `revealAll()` 呼び出しで全穴開示が動作しない
- **原因**: HTML上のボタンに `id` 属性が無く、JSが `element.id` を参照していた
- **解決策**: `className` から `blank-<id>` を抽出する方式に変更（Swift文字列中のバックスラッシュも適切にエスケープ）

### 2026-01-08: PDF（25古文単語p.pdf）から古文単語を全件クイズ化してデータを交換
- **症状**: 古文の単語データがサンプル/旧データのままで、本番のPDF内容をそのままクイズにできない
- **原因**: iOS側は `Resources/kobun.json`（または `RawData.kobunJSON`）を読むだけで、PDFを直接データ化する経路が無かった
- **解決策**: `25古文単語p.pdf` を `PDFKit` でテキスト抽出→改行/空白を正規化→ `【単語】...` ブロックを全件抽出して `kobun_pdf.json` を生成し、`Resources/kobun.json` をPDF由来データで置換してアプリの古文データを交換（抽出: 442件）

### 2026-01-08: 全教科でクイズが1問で終了する
- **症状**: 「問題開始」を押しても1問で結果画面に遷移し、選択した問題数を解けない
- **原因**: `selectQuestionsWithHistory` が履歴除外で候補が減った際に、要求数に満たないまま返してしまい、`questions` が1件になっていた
- **解決策**: `immediate + delayed` が要求数未満のときは `excludedWords` から重複を避けて補充し、常に `count` 件近く返すよう修正

### 2026-01-08: Input Mode のチャプター数が固定で期待とズレる
- **症状**: 入力モードで単語数に応じたチャプター（50語単位）が選べず、想定（例: 350語→7チャプター）通りに運用できない
- **原因**: iOS側Input Modeが「ブロック(50語)」概念を持たず、全単語を一括で対象にしていた
- **解決策**: Input Modeにチャプターピッカー（50語/ブロック）を追加し、選択ブロックのみに対してDay1-3を回すよう修正

### 2026-01-08: カラーセレクトが他ページの背景に反映されない
- **症状**: テーマ変更後も一部画面の背景が更新されない
- **原因**: `ThemeManager.shared.backgroundGradient` を参照しているだけで、Viewが `ThemeManager` を監視しておらず再描画されないケースがあった
- **解決策**: `applyAppTheme()` を付与してテーマ更新で再描画されるよう統一

### 2026-01-08: 政経（憲法）で本文が表示されない（モード依存）
- **症状**: 政経でタイピング/カードモードだと本文（条文テキスト）が表示されない
- **原因**: `SeikeiWebView` を4択モードのみに表示していた
- **解決策**: タイピング/カードモードにも `SeikeiWebView` を表示して、どのモードでも本文が見えるよう修正

### 2026-01-09: 政経（憲法）で本文が「表示されない」ように見える（テーマ/配色の不一致）
- **症状**: テーマをダーク寄りにしたとき、政経の本文がほぼ読めず「表示されていない」ように見える
- **原因**: `SeikeiWebView` のHTMLが `prefers-color-scheme` 依存で、アプリ側のテーマ（`ThemeManager`）による配色と同期しない場合があり、WebView文字色が背景と同系色になっていた
- **解決策**: `WKWebView.overrideUserInterfaceStyle` を `ThemeManager` に合わせて設定し、HTML/CSSの文字色・ボタン色もテーマに合わせて明示的に指定して、どのテーマでも本文が必ず読めるよう修正

### 2026-01-09: SeikeiWebViewのテーマ変更非追従
- **症状**: テーマを変更しても、政経（憲法）本文のWebViewスタイルが更新されない（再度画面を開くまで）
- **原因**: 
  1. `isDarkTheme` がハードコードされたテーマリストで判定しており、`ThemeManager` の変更を監視していない
  2. `makeSignature` にテーマが含まれていないため、テーマ変更時にHTMLが再生成されない
- **解決策**: 
  1. `Theme` enum に `isDark` プロパティを追加して一元管理（新テーマ追加時の更新漏れ防止）
  2. `SeikeiWebView.isDarkTheme` を `ThemeManager.shared.currentTheme.isDark` を使用するように変更
  3. `makeSignature` にテーマキーを含めて、テーマ変更時にHTMLが再描画されるようにした

### 2026-01-08: iOS26 本番運用のためサンプル問題（RawData）を破棄し、本番データ(Resources)のみを使用
- **症状**: iOS側がサンプル/簡易データ（`RawData`）にフォールバックしてしまい、本番運用時に問題内容や件数がWeb版と一致しない可能性がある
- **原因**: `VocabularyData` が `Resources` 読み込み失敗時に `RawData.*` を読み込む設計になっていた
- **解決策**: `ANKI-HUBのコピー2/*.js` から `Resources` を生成して本番データ化（例: `kanbun-data.js`→`Resources/kanbun.json`, `constitution-data.js`→`Resources/constitution.json`, `vocab1900-data.js`→`Resources/vocab1900.tsv`, `grammar-data.js`→`Resources/grammar.json`）。あわせて `VocabularyData` の `RawData` フォールバックを全教科で無効化し、`Resources` が無い場合は空配列にしてサンプル問題を完全に排除

### 2026-01-08: 「何日後にしっかり覚えていたいか」(目標定着日数) に応じた自動スケジューリング
- **症状**: 忘却曲線の設定が固定で、ユーザーが「○日後に定着させたい」に合わせた復習ペース調整や復習待ち(期限到来)の自動優先ができない
- **原因**: 復習間隔と優先度計算が固定値（WEAK=1h, LEARNING=4h, ALMOST=1d, MASTERED=7d + 固定の忘却曲線ブースト）になっていた
- **解決策**: `SettingsView` に目標定着日数（3/7/14/30日）を追加し `UserDefaults: anki_hub_retention_target_days_v1` に保存。`MasteryTracker` の忘却曲線ブースト閾値と SpacedRepetition 間隔を目標日数でスケールし、期限到来(due)を最優先に並べ替え。ダッシュボードに「復習待ち（期限到来）」導線を追加し、`DueReviewView` から期限到来のみの復習セッションを開始できるようにした。設定値は `SyncManager` 経由でクラウド同期対象にも追加

### 2026-01-09: 目標定着日数に合わせて「テスト日までに回数をこなせる」よう出題を担保
- **症状**: 目標定着日数を短く設定しても、厳密に due(期限到来) だけで出題すると候補が少なく、テスト直前に十分な回数を回せないことがある
- **原因**: due判定を満たす問題だけに限定すると、学習状況によっては「期限直前」や「弱いがまだ期限前」の問題が除外され、セッションが薄くなる
- **解決策**: `MasteryTracker` の優先度を `due(期限到来) > dueSoon(期限直前: 経過/間隔>=0.8) > urgency(経過/間隔が大きい順)` に変更し、`DueReviewView/QuizView(dueOnly)` は dueSoon も含めた候補から出題。さらに候補不足時は優先度順にバックフィルして、選んだ問題数を満たすようにした

### 2026-01-09: 古文インプットモードを「350語固定」または「全単語」で選べるようにした
- **症状**: `kobun_pdf.json` に442語ある場合でも、インプットモードが先頭350語（7チャプター）に固定されていて全件を回せない
- **原因**: 仕様（350語を50語×7チャプターとして扱う）に合わせて `prefix(350)` で固定していた
- **解決策**: 設定に「古文インプットモードを全単語で行う」を追加し、ONのときは全語彙数に応じたチャプター数で出題するようにした（OFFのときは従来通り350語固定）

### 2026-01-09: 古文助詞クイズの表形式UIを仕様通りに実装
- **症状**: 古文助詞クイズが簡略表示で、仕様書にある「種類/助詞/意味/接続/結び」の表形式UIになっていない
- **原因**: 初期実装が「活用フォームを1マス隠して自己採点」方式で、仕様の助詞表（穴埋め）UIと異なっていた
- **解決策**: `ParticleConjugationTableView` を利用し、`種類/助詞/意味/接続/結び` の表で「意味/接続/結び」のいずれかを穴埋めする4択クイズに変更。問題生成は `ParticleQuizGenerator` に統一

### 2026-01-09: 「スタート」を押してもクイズが始まらない
- **症状**: Quiz画面で「スタート」を押しても、問題が始まらず設定画面のまま変化しない
- **原因**: `VocabularyData` が `Bundle` から `vocab1900.tsv` / `kobun_pdf.json` / `constitution.json` 等を読み込む設計だが、Xcodeプロジェクトの `Resources` ビルドフェーズに入っておらず、実行時に語彙が0件になって `questions` が生成されなかった
- **解決策**: `project.pbxproj` を修正して各リソースファイルを `Resources` ビルドフェーズに追加し、さらに `QuizView.startQuiz()` で `questions.isEmpty` の場合にアラートを出して原因が分かるようにした

### 2026-01-09: 助詞クイズが開始できない
- **症状**: 古文の「助詞クイズ」で「スタート」を押しても「Loading Particles...」のまま始まらない
- **原因**: `VocabularyData` の古文データに `particleData` が含まれていなかったため、`allVocab.compactMap { $0.particleData }` が空配列を返していた
- **解決策**: `ParticleQuizViewModel.loadData()` にサンプル助詞データ（8件）を追加し、`particleData` が空の場合はサンプルを使用してクイズが開始できるようにした

### 2026-01-09: 修正が「適用されていない」ように見える
- **症状**: タイマー設定など、実装済みの機能がアプリ上で見つからず「修正が反映されていない」ように見える
- **原因**: アプリの起動ルートが `MainTabView` なのに、設定UIの本体である `SettingsView` がタブ/導線に存在せず到達不能だった（旧 `ContentView` 側にのみ設定タブが存在していた）
- **解決策**: `MainTabView` に `SettingsView` のタブを追加し、設定（タイマー/定着目標/古文インプット/テーマ等）へ確実に到達できるようにした

### 2026-01-09: 学習リマインド（定期通知）の追加
- **症状**: 毎日の学習リマインド通知を設定できない
- **原因**: 通知スケジューリング（`UNUserNotificationCenter`）と設定UIが未実装
- **解決策**: `NotificationScheduler` を追加し、`SettingsView` に「学習リマインド（毎日）」のON/OFFと通知時刻設定を追加

### 2026-01-09: サインイン後にWebサイトへ飛ぶ
- **症状**: Googleサインイン後、アプリに戻らずブラウザ側（Webページ）が表示されてしまう
- **原因**: `SupabaseAuthService.startWebAuth` の `ASWebAuthenticationSession` をローカル変数で生成しており、強参照が維持されず認証フローが不安定になっていた
- **解決策**: `SupabaseAuthService` に `ASWebAuthenticationSession` の強参照プロパティを持たせ、完了時に解放するよう修正（あわせて ephemeral セッションを使用）

### 2026-01-09: クイズが次へ進まない / 正解を連打すると正解数が増える（多重採点）
- **症状**:
  - 回答後に次の問題へ進まないことがある
  - 正解の選択肢を連打すると正解数だけが増えていく
- **原因**:
  - 古文助詞クイズ（`KobunParticleQuizView`）で回答入力のロックがなく、回答後のディレイ中に `handleAnswer` が複数回走って `submitAnswer` が多重実行されていた
  - `QuizView.cardView` のUIが一部崩れており、カードモードの状態遷移（表示/採点/次へ）が不安定になっていた
  - 4択/カードで採点処理中にUIレベルのタップ抑止が弱く、連打が入り得た
- **解決策**:
  - `KobunParticleQuizView` に `isAnswerLocked` を追加し、1問につき1回しか回答を受け付けないようにして、次問に進んだときだけ解除するよう修正
  - `QuizView.cardView` のレイアウトを正常な構造（未表示→タップ→表示→わからない/わかった→次へ）に復元
  - `QuizView` の4択/カード/スキップを `isProcessingAnswer` 中はタップ不可にして多重入力を遮断

### 2026-01-09: 設定画面のタイマー設定追加でビルド失敗
- **症状**:
  - `SettingsView.swift` の `var body: some View` で `the compiler is unable to type-check this expression in reasonable time` が出てビルド失敗。
  - `ThemePalette.color` 呼び出しの引数ラベル不一致でコンパイルエラー。
- **原因**:
  - `Slider(value: Binding(get:set:), ...)` を `Section` 内に直書きして式が複雑になり、SwiftUI の型推論が重くなって type-check がタイムアウト。
  - `themeManager.currentPalette.color(.primary, scheme: colorScheme)` のように、`ThemePalette.color(_:isDark:)` に存在しない引数ラベルで呼び出していた。
- **解決策**:
  - タイマー設定UIを `timerSettingRow` / `timerLimitBinding` に分離して式を単純化。
  - `accentColor` は `themeManager.color(.primary, scheme: colorScheme)` を使用して引数型を一致させた。

### 2026-01-09: 政経（憲法）で答えが見えてしまう / 4択に不正な選択肢が混入
- **症状**:
  - 政経（憲法）穴埋めで、次の問題に進んだ後も答えが見えてしまうことがある。
  - 4択の中に「穴埋め（N箇所）」など本来答え候補にならない文字列が混入することがある。
- **原因**:
  - `QuizView.nextQuestion()` で `showResult` などの状態をリセットしておらず、`SeikeiWebView(isAllRevealed: redSheetMode || showResult)` が次問でも有効になって答えが開示されていた。
  - 政経 `questionType == "number"` の誤答プールが全語彙の `meaning` をフォールバックに使い、穴埋め問題の `meaning`（例: 「穴埋め（N箇所）」）が混入し得た。
- **解決策**:
  - `nextQuestion()` で `showResult/selectedAnswer/typingAnswer/isCorrect/showFeedbackOverlay/showAnswer/lastChosenAnswerText` をリセットして、次問に状態を持ち越さないよう修正。
  - 政経の選択肢生成で不正文字列を除外するフィルタ（数値問題は「前文」または「第N条」のみ許可）を追加。

### 2026-01-10: 実機ビルドで署名エラー（Development Team 未設定）
- **症状**:
  - `Signing for "ANKI-HUB-iOS" requires a development team.`
  - `Signing for "ANKI-HUB-iOS-Widget" requires a development team.`
  - `ANKI-HUB-iOS.xcodeproj Update to recommended settings`
- **原因**:
  - XcodeGen の `project.yml` に `DEVELOPMENT_TEAM` が明示されておらず、生成された `.xcodeproj` でターゲット（App/Widget）の署名チームが未設定として扱われた。
- **解決策**:
  - `project.yml` の App/Widget 両ターゲットに `DEVELOPMENT_TEAM` を追加して恒久化。
  - Simulator 向けビルドでは署名を不要化（`CODE_SIGNING_ALLOWED/REQUIRED/IDENTITY` を `sdk=iphonesimulator*` で無効化）し、開発中のビルドが詰まらないようにした。
  - `xcodegen generate` で再生成して反映。

### 2026-01-10: 苦手復習（Recommended）で英検だけ「何を間違えたか」が出ない
- **症状**:
  - 苦手復習一覧で、英検だけ誤答履歴（`あなた: ... / 正解: ...`）が表示されず「機能が適用されていない」ように見える。
- **原因**:
  - `WeakWordsView` の対象科目リストに `.eiken` が含まれておらず、英検の苦手復習セッション/一覧が生成されていなかった。
- **解決策**:
  - `WeakWordsView` の `subjects` に `.eiken` を追加して、他科目と同様に誤答履歴を確認できるようにした。

### 2026-01-10: 実機にインストールできない（Widget拡張の MissingBundleExecutable）
- **症状**:
  - 実機実行で `Failed to install the app on the device` / `Missing or invalid CFBundleExecutable in its Info.plist` が発生してインストールできない。
- **原因**:
  - Widget拡張（`sugwrAnkiWidget.appex`）の `Info.plist` に `CFBundleExecutable` が無く、iOS のインストール検証で `MissingBundleExecutable` として弾かれていた。
- **解決策**:
  - `Sources/ANKI-HUB-iOS-Widget/Info.plist` に `CFBundleExecutable = $(EXECUTABLE_NAME)` を追加して、拡張バンドルの検証要件を満たすようにした。

### 2026-01-10: 実機にインストールできない（WidgetKit拡張の AppexBundleContainsClassOrStoryboard）
- **症状**:
  - 実機実行で `defines either an NSExtensionMainStoryboard or NSExtensionPrincipalClass key, which is not allowed for the extension point com.apple.widgetkit-extension` が発生してインストールできない。
- **原因**:
  - WidgetKit拡張（`com.apple.widgetkit-extension`）の `Info.plist` に `NSExtensionPrincipalClass` が含まれており、iOS 26 のインストール検証で `AppexBundleContainsClassOrStoryboard` として弾かれていた。
- **解決策**:
  - `Sources/ANKI-HUB-iOS-Widget/Info.plist` から `NSExtensionPrincipalClass` を削除し、WidgetKit拡張の要件に合わせた。

### 2026-01-10: Widget拡張ビルドで CodeSign 失敗（resource fork / Finder info）
- **症状**:
  - `xcodebuild -target ANKI-HUB-iOS-Widget ... build` で `resource fork, Finder information, or similar detritus not allowed` により `CodeSign failed with a nonzero exit code` で失敗する。
- **原因**:
  - 生成物（`.appex`）がプロジェクト直下の `build/` に出力され、`com.apple.FinderInfo` などの拡張属性（xattr）が付与されて CodeSign に拒否されていた。
  - 特に iCloud/ファイルプロバイダ配下のフォルダや Finder 経由コピーを挟むと、拡張属性が付くことがある。
- **解決策**:
  - `project.yml` で `SYMROOT/OBJROOT` を `~/Library/Developer/Xcode/DerivedData/...` 側に固定して、生成物がプロジェクト直下に出ないようにした。
  - `xcodegen generate` で `.xcodeproj` を再生成。
  - 既に作られた `build/` が残っている場合は削除（または xattr 除去）してから再ビルドする。

### 2026-01-10: 漢文の問題が出ない（データが無いように見える）
- **症状**:
  - 漢文を選んでも問題が生成されず、開始できない/0件になる。
- **原因**:
  - `kanbun.json` のアイテムには `category` が無いのに、`QuizView.filterVocabByChapter` が `category == chapter` でフィルタしており、チャプター選択時に常に0件になっていた。
- **解決策**:
  - 漢文は `category` フィルタではなく、全語彙を4分割（基本/否定/疑問/使役）してチャプターを決める方式に修正。

### 2026-01-10: 古文/漢文でヒントが見れない
- **症状**:
  - 古文で「ヒントを見る」ボタンが出ない/漢字表記を見れない。
  - 漢文で「ふりがなを見る」ボタンが出ないことがある。
- **原因**:
  - `QuizView` は `question.hint` がある時だけヒントボタンを表示する。
  - 古文は `kobun_pdf.json` を優先ロードしていたが、`kobun.json` にある `hint`（漢字表記）が PDF 版に欠けている項目があり、結果として `question.hint == nil` が増えてボタンが出なかった。
  - 漢文はヒントとして `reading`（ふりがな）を使うが、データ差異に備えて `reading` が無い場合があり得る。
- **解決策**:
  - 古文ロード時に `kobun_pdf.json` の内容を基本にしつつ、`kobun.json` から `hint/example` を id で補完するように修正。
  - 漢文のヒントは `reading ?? hint` を `Question.hint` に設定して、ボタンが出るようにした。

### 2026-01-10: 壁紙が「くっきり」表示されない（テーマ設定画面など）
- **症状**:
  - 壁紙を設定しているのに、画面によっては単色背景で壁紙が見えず「くっきり表示」にならない。
- **原因**:
  - 一部画面が `ThemeManager.shared.background` を使わず、`color(.background, ...)` の単色背景を敷いて壁紙を覆っていた。
- **解決策**:
  - `ThemeSettingsView` を `ThemeManager.shared.background` を背面に敷く構成に統一し、前面コンテナのみ `.liquidGlass()` で表現するよう修正。

### 2026-01-10: デュアルテーマON直後にテーマが切り替わらない
- **症状**:
  - 「モード別テーマ」をONにしても、その瞬間にライト/ダークのテーマが即反映されず、次回の外観変化まで反映が遅れることがある。
- **原因**:
  - テーマ切替は `updateSystemColorScheme` の呼び出し時にのみ発火しており、`useDualTheme` のON直後は切替処理が走らないケースがあった。
- **解決策**:
  - `useDualTheme` の変更時に、現在の `systemColorScheme` に応じたテーマを即 `applyTheme` するように修正。

### 2026-01-10: 学習時間が「5分で止まる」ように見える
- **症状**:
  - 学習しても「今日の学習時間」が 5 分から増えない/増え方が不自然に見える。
- **原因**:
  - `QuizView` のクイズ完了時に `LearningStats.recordStudySession(..., minutes: 5)` を固定値で記録していた。
- **解決策**:
  - クイズ開始時刻を保持し、完了時に経過時間から分数を算出して `recordStudySession` に渡すように修正。

### 2026-01-10: ウィジェットの反映が遅い
- **症状**:
  - アプリで学習してもウィジェットの「今日の学習時間」等の反映が遅い。
- **原因**:
  - Widget の Timeline 更新間隔が長く（15分）、アプリ側から `WidgetCenter.reloadTimelines` を呼んでいなかった。
- **解決策**:
  - Widgetの更新間隔を短縮し、`LearningStats.saveStats()` と直近ミス保存時に `WidgetCenter.reloadTimelines(ofKind:)` を呼ぶように修正。

### 2026-01-10: ダークモードで一部チャート色がテーマに合わない
- **症状**:
  - ダークモード時にチャート色が明るい/テーマと合わない。
- **原因**:
  - `CalendarView` が `theme.currentPalette.primary` の hex を直接参照しており、Dark側の色に切り替わっていなかった。
- **解決策**:
  - `ThemePalette.color(.primary, isDark: theme.effectiveIsDark)` を使うように修正。

ネイティブ SwiftUI で構築された iOS 向け単語学習アプリケーション。

## 概要

このプロジェクトは ANKI-HUB の完全ネイティブ iOS 版です。SwiftUI を使用して構築されており、iOS のネイティブ UI/UX を完全に再現しています。

## 機能

### 学習機能
- **4択クイズモード**: 英単語・古文・漢文・政経の4択問題
- **カードモード**: フラッシュカード形式の学習
- **習熟度トラッキング**: 5段階の習熟度管理
- **学習統計**: 連続学習日数、学習時間、習熟率の追跡

### ツール
- **ポモドーロタイマー**: 集中・休憩・長休憩の3モード対応
- **カレンダー**: 月間学習記録の可視化
- **レポート**: 週間推移チャート、習熟度分布、科目別進捗
- **マイ単語**: カスタム単語帳の作成・管理

### 科目
- 英単語（ターゲット1900対応）
- 古文単語・文法
- 漢文句法・語彙
- 政経用語

## 技術スタック

- **言語**: Swift 5.9
- **UI**: SwiftUI
- **最小 iOS バージョン**: iOS 17.0
- **データ永続化**: UserDefaults
- **チャート**: Swift Charts

## プロジェクト構成

```
ANKI-HUB-iOS/
├── ANKI-HUB-iOS.xcodeproj/    # Xcode プロジェクト
├── Sources/
│   └── ANKI-HUB-iOS/
│       ├── ANKIHUBApp.swift   # アプリエントリーポイント
│       ├── Views/
│       │   ├── ContentView.swift      # メインTabView
│       │   ├── HomeView.swift         # ダッシュボード
│       │   ├── LibraryView.swift      # ライブラリ
│       │   ├── SettingsView.swift     # 設定
│       │   ├── ManagementView.swift   # 管理
│       │   ├── QuizView.swift         # クイズ画面
│       │   ├── PomodoroView.swift     # ポモドーロ
│       │   ├── CalendarView.swift     # カレンダー
│       │   ├── ReportView.swift       # レポート
│       │   └── CustomVocabView.swift  # マイ単語
│       ├── Models/
│       │   └── Models.swift           # データモデル
│       ├── Data/
│       │   └── VocabularyData.swift   # 語彙データ
│       ├── Assets.xcassets/           # アセット
│       └── Info.plist                 # 設定
├── Package.swift                      # Swift Package
├── project.yml                        # XcodeGen設定
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
# XcodeGen をインストール（未インストールの場合）
brew install xcodegen

# プロジェクトを生成
cd ANKI-HUB-iOS
xcodegen generate
open ANKI-HUB-iOS.xcodeproj
```

## ビルド要件

- macOS 14.0 以上
- Xcode 15.0 以上
- iOS 17.0 以上のシミュレータまたは実機

## 開発状況

### 完了済み ✅
- [x] プロジェクト基盤構築
- [x] タブベースナビゲーション
- [x] ホーム画面（統計カード、クイックアクション）
- [x] ライブラリ画面（科目・ツール一覧）
- [x] 設定画面（アカウント、外観、同期）
- [x] 管理画面（データ管理）
- [x] クイズ機能（4択・カード両モード）
- [x] ポモドーロタイマー
- [x] カレンダー表示
- [x] レポート画面（チャート付き）
- [x] カスタム単語帳
- [x] データモデル（AuthManager、LearningStats、MasteryTracker）
- [x] サンプル語彙データ（200語）

### 今後の予定
- [ ] Supabase 認証連携
- [ ] クラウド同期機能
- [ ] プッシュ通知
- [ ] ウィジェット対応
- [ ] Apple Watch 対応

## トラブルシューティング

### SIGTERM エラーが発生する場合

1. **Xcode を完全に終了**してから再度開く
2. **Product > Clean Build Folder** (⌘⇧K) を実行
3. **DerivedData を削除**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. プロジェクトを再度開いてビルド

### ビルドエラーが発生する場合

1. iOS Deployment Target が **17.0** になっているか確認
2. **Signing & Capabilities** で Team を選択
3. シミュレータを **iPhone 15 Pro** などの iOS 17 対応機種に変更

---

## ライセンス

Private - All rights reserved

## 作者

ANKI-HUB Team
