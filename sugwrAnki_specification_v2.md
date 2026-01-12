# sugwrAnki システム完全仕様書 v3.0

## 1. システム概要

本ドキュメントは、sugwrAnkiの再構築・運用に必要な**全機能、全アルゴリズム、Webページ構成、データロジック**を網羅した完全仕様書である。

### 1.1 技術スタック
- **Frontend**: Vanilla JS, Tailwind CSS (CDN), Lucide Icons
- **Backend/Storage**: Supabase (Auth, Database, Storage)
- **Architecture**: PWA (Offline-first), SPA-like navigation within pages

### 1.2 ファイル構成と役割

| ファイル名 | 分類 | 役割・責務 |
|------------|------|------------|
| **index.html** | Page | ダッシュボード、ナビゲーション、全体統括 |
| **quiz.html** | Page | **【最重要】** クイズ実行、問題選択、結果表示 |
| **learning-core.js** | Logic | **【最重要】** 習熟度計算、間隔反復、ランク管理 |
| **storage.js** | Logic | クラウド同期、デバウンス保存、データ統合 |
| **auth.js** | Logic | 認証(Google OAuth)、招待コード管理 |
| **theme-system.js** | Logic | テーマカラー、壁紙、フォント管理 |
| **pomodoro.html** | Page | ポモドーロタイマー（スイスモダンUI） |
| **calendar.html** | Page | 学習履歴カレンダー、手動記録 |
| **scan.html** | Page | 問題集スキャン、穴埋め作成ツール |
| **custom_vocab.html** | Page | オリジナル単語帳、苦手単語一覧 |
| **past-exam-analysis.html** | Page | 共通テスト/模試スコア管理、分析 |
| **input_mode.html** | Page | 短期集中3日間学習モード |
| **learning-report.html** | Page | 詳細分析レポート（グラフ・チャート） |
| **profile.html** | Page | 設定、データ管理 |
| **data/*.js** | Data | 政経(constitution)、英単語(vocab1900)、古文(kobun) |

---

## 2. Webページ構成 (Sitemap & Hierarchy)

```mermaid
graph TD
    Index[index.html (Dashboard)] -->|Subject Select| Quiz[quiz.html (Quiz)]
    Index -->|Nav| Calendar[calendar.html]
    Index -->|Nav| Report[learning-report.html]
    Index -->|Nav| Profile[profile.html]
    Index -->|Tool| Scan[scan.html]
    Index -->|Tool| Pomodoro[pomodoro.html]
    Index -->|Tool| Custom[custom_vocab.html]
    Index -->|Tool| PastExam[past-exam-analysis.html]
    
    Quiz -->|End| ResultView(Result Screen)
    Quiz -->|Retry| Quiz
    Quiz -->|Home| Index
    
    subgraph "Logic Layer"
        Core[learning-core.js]
        Store[storage.js]
        Auth[auth.js]
        Theme[theme-system.js]
    end
    
    Quiz -.-> Core
    Quiz -.-> Store
    Index -.-> Store
    InputMode -.-> Core
```

---

## 3. 詳細ページ仕様 & ロジックマッピング

### 3.1 index.html (ダッシュボード)

**役割**: アプリの玄関口。学習状況のサマリー表示と各機能へのアクセス。

| 機能 | 効果 | ロジックの場所 (File:Function/Event) | 必要なデータ |
|------|------|--------------------------------------|--------------|
| **ストリーク表示** | 継続意欲の維持 | `learning-core.js: LearningStats.calculateStreak` | `localStorage:anki_hub_stats` |
| **習熟度グラフ** | 全体進捗の可視化 | `index.html: updateDashboard -> Chart.js` | `MasteryTracker.getStats()` |
| **教科選択** | クイズ開始 | `onclick="switchTab"` (URLパラメータ付加なし、SPA的切替) | `subject`変数 |
| **同期ボタン** | 手動クラウド同期 | `onclick="manualSync"` -> `storage.js: saveProgress` | Supabase Session |
| **誤答通報** | 問題ミス報告 | `onclick="openPaperMistakeModal"` | `mistake_reports`テーブル |

**ユーザーフロー**:
1. ログイン確認 (`auth.js: checkUser`)
2. `LearningStats`初期化、日付変更チェック
3. `loadAllData` でクラウドから最新データ取得（デバウンスあり）
4. UI描画（ストリーク、今日のアクティビティ）

---

### 3.2 quiz.html (クイズ画面) ★Core

**役割**: 学習実行。アルゴリズムに基づき出題し、結果を習熟度に反映する。

| 機能 | 効果 | ロジックの場所 | ロジック詳細 |
|------|------|----------------|--------------|
| **問題選択** | 最適な学習順序 | `quiz.html: startQuiz` -> `search selectedQuestionsWithHistory` | 優先度ソート + 忘却曲線 |
| **回答判定** | 正誤・速度記録 | `quiz.html: checkAnswer` | 完全一致/選択肢インデックス比較 |
| **習熟度更新** | レベル昇降格 | `learning-core.js: MasteryTracker.recordAnswer` | 5段階遷移アルゴリズム |
| **CSVエクスポート** | Anki互換性 | `downloadCSV()` | Blob生成 |
| **苦手一括復習** | 弱点克服 | `startMistakesSession()` | `WEAK`アイテムのみ抽出 |
| **音声読み上げ** | リスニング強化 | `Web Speech API: SpeechSynthesisUtterance` | ブラウザ標準機能 |

**DOM階層**:
- `#setup-view`: 開始前設定（Slidrs for count/passRate）
- `#quiz-view`: 問題表示エリア（動的生成: `.choice-container`, `#typing-input`）
- `#result-view`: 結果グラフ、スコア表示

---

### 3.3 learning-core.js (アルゴリズム詳細) ★Deep Dive

**場所**: 全ページから読み込まれる中核ロジック。

#### A. 5段階習熟度システム
| レベル | 内部値 | 説明 | 復習間隔(目安) |
|--------|--------|------|----------------|
| **WEAK** | 0 | 苦手。即時復習対象 | 1時間 |
| **NEW** | 1 | 未学習 | - |
| **LEARNING**| 2 | 学習中 | 4時間 |
| **ALMOST** | 3 | ほぼ覚えた | 24時間 |
| **MASTERED**| 4 | 覚えた | 7日 |

#### B. 昇格・降格アルゴリズム (recordAnswer)

**回答時間閾値**:
- `Fast`: 3秒未満（穴埋めの場合 +1.5秒/穴）
- `Slow`: 8秒以上（穴埋めの場合 +3.0秒/穴）
- `VeryFast`: 1.5秒未満

**昇格ルール**:
1. **NEW → LEARNING**: 1回正解
2. **WEAK → LEARNING**: 2回連続正解
3. **LEARNING → ALMOST**: `Fast`なら1回、`Normal`なら2回、`Slow`なら4回正解
4. **ALMOST → MASTERED**:
    - `VeryFast` × 3回連続正解（確実記憶）
    - または `FluencyScore` ≥ 80 かつ 2回正解
    - 通常ルート: `Fast`2回 / `Normal`4回 / `Slow`6回

**降格ルール**:
- **不正解**: 即座に `WEAK` へ降格（連続正解リセット）
- **スキップ**: `WEAK` へ降格
- **ヒント使用**: 正解しても `WEAK` 扱い

#### C. 即答力スコア (Fluency Score)
- **計算式**: `NewScore = OldScore * 0.6 + CurrentScore * 0.4` （加重平均）
- **CurrentScore**:
    - <2秒: 100点
    - 2-5秒: 70点
    - 5-10秒: 40点
    - >10秒: 10点

#### D. 問題選択アルゴリズム (selectQuestionsWithHistory)
1. **履歴チェック**: 直近のセッションでの正解/不正解を確認。
2. **除外**: 「前回正解かつ5秒未満」の単語は、短期記憶にあるとして除外。
3. **遅延出題**: 「前回正解だが5秒以上」の単語は、2セッション空けて再出題。
4. **優先度ソート**: 残った単語を `Mastery` の低い順 (WEAK > NEW > ...) にソート。
5. **忘却曲線ブースト**: 時間経過（`Date.now() - lastSeen`）に応じて優先度を加算。
    - MASTEREDでも14日経てば優先度+0.5（ALMOST並みに出題）

---

### 3.4 storage.js (クラウド同期)

**同期ロジック**:
- **Debounce**: `saveProgress` 呼び出し後、2秒(`DEBOUNCE_MS`)待ってから実際に通信。
- **Rate Limit**: `loadAllData` は前回のロードから30秒(`MIN_LOAD_INTERVAL`)以内ならスキップ。
- **データ構造**:
```sql
TABLE "study" (
  user_id UUID,
  app_id VARCHAR, -- 'english', 'kobun', 'stats' 等
  data JSONB,     -- 圧縮されたJSONデータ
  updated_at TIMESTAMP
)
```

---

### 3.5 theme-system.js (デザインシステム)

**構成**:
- `ThemeSystem.presets`: カラープリセット定義（Ocean, Midnight, 名画シリーズ等）
- `ThemeSystem.apply()`: `:root` のCSS変数を書き換え。

**主なCSS変数**:
- `--color-surface`: カード背景色
- `--color-primary`: ボタン、強調色
- `--color-mastered` / `weak` 等: 習熟度バッジ色
- `getContrastColor()`: 背景色から明度を計算し、文字色（黒/白）を自動決定。

---

### 3.6 scan.html (QuizCapture)

**独自機能**:
- **Canvas Crop**: 画像上のドラッグ操作(`mousedown`, `mousemove`)で座標を取得し、`drawImage`で切り出し。
- **マーカー検出**: 画像ピクセルデータを走査し、特定の色相（青/緑マーカー）領域を透明化or文字認識（現状は座標記録のみ）。

---

### 3.7 pomodoro.html (タイマー)

**UXロジック**:
- **ダイアル操作**: マウス/タッチ座標(`atan2`)から角度を計算し、時間を設定。
- **Worker**: バックグラウンドでも時間がズレないよう、`Date.now()`との差分で残り時間を計算。

---

### 3.8 input_mode.html (3Days Learning)

**コンセプト**: 1つの単語ブロック(50語)を3日間かけて定着させる特別モード。
- **Day 1**: 眺めるだけ（自動再生）
- **Day 2**: 1.5秒以内の即答仕分け（知ってる/知らない）
- **Day 3**: 音声入力/発音確認（Web Speech API）

---

## 4. ユーザー体験フロー (UX Flow)

### 新規ユーザーのフロー
1. `index.html` アクセス
2. ログイン -> 招待コード入力 (`auth.verifyInviteCode`)
3. `LearningStats` が新規作成される
4. `quiz.html` へ移動 -> 好きな教科を選択
5. 初回クイズ実行 -> `Mastery` が `NEW` から `LEARNING` へ変化
6. `index.html` に戻るとグラフとストリークが更新
7. `theme-system` で好みの色設定

### 継続ユーザーのフロー
1. アプリを開く -> `storage.js` が自動同期
2. 「復習待ち」のアラートを確認
3. 復習クイズ実行（`Mastery` に応じて出題）
4. 苦手な単語があれば `custom_vocab.html` でリスト化
5. 週末に `past-exam-analysis.html` で模試結果を入力

---

## 5. 再構築・開発時の注意点

1. **認証依存**: ほぼ全ての機能が `window.auth.currentUser` を必要とする。ローカル開発時はダミーユーザーが必要になる場合がある。
2. **Supabase RLS**: テーブルごとのRow Level Security設定が必須（`user_id` 一致のみ許可）。
3. **PWAキャッシュ**: `sw.js` が強力にキャッシュするため、更新時はキャッシュクリアが必要。
4. **イベント伝播**: モーダル等の `onclick="event.stopPropagation()"` が多用されているため、安易にHTML構造を変えたりイベントハンドラを削除しないこと。

*作成日: 2026-01-08*
