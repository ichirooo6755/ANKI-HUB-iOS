# sugwrAnki 完全仕様書

このドキュメントは、sugwrAnki（ANKI-HUB）を**ゼロから再構築**するために必要な全情報を記載しています。

---

## 目次

1. [プロジェクト概要](#1-プロジェクト概要)
2. [コア設計思想](#2-コア設計思想)
3. [技術スタック](#3-技術スタック)
4. [ファイル構成](#4-ファイル構成)
5. [データ構造](#5-データ構造)
6. [学習アルゴリズム（最重要）](#6-学習アルゴリズム最重要)
7. [クイズシステム](#7-クイズシステム)
8. [テーマシステム](#8-テーマシステム)
9. [認証・クラウド同期](#9-認証クラウド同期)
10. [各ページの機能詳細](#10-各ページの機能詳細)
11. [UI/UXこだわりポイント](#11-uiuxこだわりポイント)
12. [既知の課題と解決策](#12-既知の課題と解決策)

---

## 1. プロジェクト概要

### 1.1 何のアプリか
**受験生向けの暗記学習アプリ**。英単語、古文単語、漢文、政経（憲法条文）を効率的に学習できる。

### 1.2 対象ユーザー
- 高校生・受験生
- ADHD傾向のあるユーザー（短時間集中に最適化）
- スマートフォンでの学習がメイン

### 1.3 競合との差別化
| 特徴 | sugwrAnki | 一般的なアプリ |
|------|-----------|---------------|
| 習熟度管理 | 5段階+即答力スコア | 2-3段階 |
| 昇格条件 | 回答時間を考慮 | 正解数のみ |
| 降格ルール | 1回間違えたら即「苦手」 | 複数回ミスで降格 |
| オフライン | 完全対応（PWA） | クラウド依存が多い |
| テーマ | 完全カスタマイズ可能 | 固定テーマ |

---

## 2. コア設計思想

### 2.1 オフラインファースト
```
学習データ → localStorage（即座に保存）
         ↓ 
         → Supabase（オンライン時に自動同期）
```
- ネット接続なしでも100%の機能を使用可能
- 複数デバイス間で進捗を同期

### 2.2 分散学習（エビングハウスの忘却曲線）
人間の記憶は時間とともに減衰する。最適なタイミングで復習することで定着率を最大化。

```
記憶保持率
100% │ ● 学習直後
     │   ╲
 45% │    ● 1日後 ← ここで復習すると効果的
     │     ╲
 30% │      ● 2日後
     │       ╲
 25% │        ● 7日後
     └──────────────────→ 時間
```

### 2.3 ゲーミフィケーション
- **ストリーク**: 連続学習日数を表示（モチベーション維持）
- **ランクアップテスト**: チャプターごとに解放していく達成感
- **進捗バー**: 視覚的な達成度表示

### 2.4 ADHD最適化
- 短いセッション（10問程度）で完結
- 即座のフィードバック（正解/不正解表示）
- 視覚的に分かりやすいUI

---

## 3. 技術スタック

### 3.1 フロントエンド
| 技術 | 用途 |
|------|------|
| Vanilla JavaScript | ロジック全般 |
| Tailwind CSS (CDN) | スタイリング |
| Lucide Icons | アイコン |
| Chart.js / ApexCharts | グラフ表示 |

**React版も並行開発中** (`ANKI-HUB-React/`)

### 3.2 バックエンド
| 技術 | 用途 |
|------|------|
| Supabase | 認証、データベース、ストレージ |
| Netlify | ホスティング |

### 3.3 PWA
- `manifest.json`: アプリ情報
- `sw.js`: Service Worker（オフラインキャッシュ）

---

## 4. ファイル構成

```
ANKI-HUB/
├── 📄 HTMLページ
│   ├── index.html          # ダッシュボード（ホーム）
│   ├── quiz.html           # メインクイズ機能 ★最重要（166KB）
│   ├── profile.html        # 設定・テーマ管理
│   ├── calendar.html       # 学習履歴カレンダー
│   ├── pomodoro.html       # ポモドーロタイマー
│   ├── custom_vocab.html   # カスタム単語帳
│   ├── scan.html           # 問題集スキャン取り込み
│   ├── learning-report.html # 学習統計レポート
│   └── past-exam-analysis.html # 過去問分析
│
├── 📜 コアJavaScript
│   ├── learning-core.js    # 学習アルゴリズム ★最重要（45KB）
│   ├── theme-system.js     # テーマ管理（58KB）
│   ├── auth.js             # Supabase認証
│   └── storage.js          # クラウド同期
│
├── 📚 データファイル
│   ├── vocab1900-data.js   # 英単語1900語
│   ├── kobun-data.js       # 古文単語417語+助詞
│   ├── kanbun-data.js      # 漢文単語100語
│   └── constitution-data.js # 政経（憲法条文）
│
├── 🎨 スタイル
│   ├── v0-style.css        # グローバルCSS変数
│   ├── apple-style.css     # Apple風UIコンポーネント
│   └── kanbun.css          # 漢文縦書き用
│
└── ⚙️ 設定
    ├── manifest.json       # PWA設定
    └── sw.js               # Service Worker
```

---

## 5. データ構造

### 5.1 単語データ形式

#### 英語 (vocab1900-data.js)
```javascript
{
  id: 1,
  word: "abandon",
  meaning: "を捨てる、を断念する",
  hint: null,      // オプション
  example: null    // オプション
}
```

#### 古文 (kobun-data.js)
```javascript
// 通常単語
{
  id: 1,
  word: "あはれ",
  meaning: "しみじみとした情趣",
  hint: "哀れ",    // 漢字表記
  example: null
}

// 助詞（活用表用）
{
  id: "p1",
  type: "接続助詞",
  particle: "ば",
  meaning: "〜ならば（仮定）/ 〜ので（確定）",
  conjugations: {
    desc: "接続: 未然形・已然形に接続",
    forms: ["未然形+ば = 仮定条件", "已然形+ば = 確定条件"]
  },
  examples: ["行かば（行くならば）", "行けば（行ったので）"]
}
```

#### 政経 (constitution-data.js)
```javascript
{
  id: "seikei-1",
  source: "SEIKEI",
  number: "第1条",
  text: "天皇は、日本国の象徴であり日本国民統合の象徴であつて、この地位は、主権の存する日本国民の【総意】に基く。"
  // 【】で囲まれた部分が穴埋め箇所
}
```

### 5.2 習熟度データ（localStorage）

キー: `anki_hub_mastery_{教科名}`

```javascript
{
  "1": {
    correct: 5,           // 連続正解数
    wrong: 2,             // 累計不正解数
    totalAttempts: 10,    // 総回答数
    mastery: "learning",  // 習熟度ステータス
    lastSeen: 1704067200000, // 最終回答時刻（Unix ms）
    avgResponseTime: 2.5, // 平均回答時間（秒）
    fastestTime: 1.2,     // 最速回答時間
    fluencyScore: 75,     // 即答力スコア（0-100）
    consecutiveFast: 2,   // 連続即答回数
    firstStudiedDate: "2024-01-01",
    sessionHistory: [...]  // セッション履歴（最大20件）
  }
}
```

### 5.3 学習統計データ

キー: `anki_hub_stats`

```javascript
{
  streak: 7,              // 連続学習日数
  lastStudyDate: "Mon Jan 06 2025",
  totalTime: 36000,       // 累計学習時間（秒）
  todayTime: 1800,        // 今日の学習時間（秒）
  todayWords: 50,         // 今日の学習単語数
  wordsLearned: 500,      // 累計覚えた単語数
  totalSessions: 100,     // 累計セッション数
  todayDate: "Mon Jan 06 2025"
}
```

---

## 6. 学習アルゴリズム（最重要）

### 6.1 習熟度5段階システム

```
┌─────────────────────────────────────────────────────────┐
│                    習熟度レベル                          │
├────────────┬─────────┬─────────────────────────────────┤
│ ステータス │ 優先度  │ 説明                             │
├────────────┼─────────┼─────────────────────────────────┤
│ WEAK       │ 0（最高）│ 苦手。間違えた直後に設定        │
│ NEW        │ 1       │ 未学習。まだ一度も回答していない │
│ LEARNING   │ 2       │ うろ覚え。正解し始めた段階      │
│ ALMOST     │ 3       │ ほぼ覚えた。あと少しで完了      │
│ MASTERED   │ 4（最低）│ 覚えた。復習間隔が長くなる      │
└────────────┴─────────┴─────────────────────────────────┘
```

### 6.2 昇格ロジック

```javascript
// 正解時の昇格条件（回答時間も考慮）

NEW → LEARNING
  条件: 1回正解

WEAK → LEARNING
  条件: 2回連続正解（苦手は昇格しにくい）

LEARNING → ALMOST
  条件: 
    - 即答（<3秒）: 1回正解で昇格
    - 普通: 2回連続正解
    - 遅い（>8秒）: 4回連続正解

ALMOST → MASTERED
  条件（いずれか）:
    - 超即答（<1.5秒）を3回連続
    - 即答力スコア80以上 + 2回連続正解
    - 通常: 4回連続正解
```

### 6.3 降格ロジック

```javascript
// 不正解時: 即座に WEAK（苦手）へ降格
// ※どのステータスからでも1回間違えたら苦手になる
```

### 6.4 即答力スコア（Fluency Score）

回答時間に基づいて0-100のスコアを計算：

```javascript
回答時間    → スコア加算
--------------------------
<2秒        → +100点
2-5秒       → +70点
5-10秒      → +40点
>10秒       → +10点

// 新しい回答 = 40%、過去の平均 = 60% の加重平均
fluencyScore = 過去スコア × 0.6 + 新スコア × 0.4
```

### 6.5 忘却曲線ブースト

時間経過により復習優先度を上げる補助スコア：

```javascript
MASTERED:
  14日以上経過 → 優先度 +0.5
  7日以上経過  → 優先度 +0.4
  3日以上経過  → 優先度 +0.2

ALMOST/LEARNING:
  3日以上経過  → 優先度 +0.8
  1日以上経過  → 優先度 +0.5
  12時間以上   → 優先度 +0.3
```

### 6.6 出題アルゴリズム（quiz.html）

```javascript
// 1. 対象チャプターの単語を取得
const chunkWords = getChapterWords(selectedChapters);

// 2. 習熟度別に分類
const newWords = chunkWords.filter(w => mastery === 'new');
const reviewWords = chunkWords.filter(w => mastery !== 'new');

// 3. 復習単語を優先度順にソート（忘却曲線考慮）
const sortedReview = masteryTracker.sortByPriority(reviewWords);

// 4. 未学習単語を50%以上保証（最低5問）
const forceNewCount = Math.max(5, Math.floor(questionCount * 0.5));
const priorityNew = newWords.slice(0, forceNewCount);

// 5. 最終キュー構築
// [強制NEW] + [優先度ソート済REVIEW] + [残りNEW]
finalQueue = [...priorityNew, ...sortedReview, ...restNew];

// 6. セッション履歴による除外
// - 前回正解+5秒未満 → 今回除外
// - 前回正解+5秒以上 → 2セッション後に再出題
```

### 6.7 間隔反復（Spaced Repetition）

習熟度に応じた復習間隔：

```javascript
WEAK:     1時間後
LEARNING: 4時間後
ALMOST:   1日後
MASTERED: 7日後
```

---

## 7. クイズシステム

### 7.1 出題モード

| モード | 説明 |
|--------|------|
| 4択 (choice) | 4つの選択肢から正解を選ぶ |
| タイピング (typing) | 答えを直接入力 |
| カード (card) | 赤シート方式（自己評価） |
| 穴埋め (cloze) | 【】で囲まれた部分を答える |

### 7.2 政経（憲法条文）の穴埋め問題

```javascript
// 元データ
text: "天皇は、日本国の象徴であり...【総意】に基く。"

// 処理
1. 【】内のテキストを抽出 → ["総意"]
2. 穴埋め表示: "天皇は...【１】に基く。"
3. 4択生成: 正解 + 誤答3つ（同じカテゴリから選出）
```

複数穴埋めの場合：
- 1つずつ順番に回答
- 同じ番号の穴（【１】【１】）は1回の回答で両方埋まる
- 全て正解で「覚えた」、1つでも間違えると「苦手」

### 7.3 古文助詞活用表クイズ

表形式で穴埋め：

```
┌─────────┬──────┬──────────────────┬──────────┬────────┐
│ 種類    │ 助詞 │ 意味             │ 接続     │ 結び   │
├─────────┼──────┼──────────────────┼──────────┼────────┤
│ 係助詞  │ こそ │ 強調（最強）     │ ？       │ 已然形 │
└─────────┴──────┴──────────────────┴──────────┴────────┘
```

ランダムに1セルを穴（？）にして、4択で回答。

### 7.4 タイマー機能

```javascript
// タイムスタンプベース（スリープ対応）
timerStartTime = Date.now();
timeRemaining = timeLimit - Math.floor((Date.now() - timerStartTime) / 1000);
```

---

## 8. テーマシステム

### 8.1 CSS変数

```css
/* 基本カラー */
--color-primary      /* ナビ、ボタン */
--color-accent       /* ストリーク、警告 */
--color-background   /* 背景色 */
--color-surface      /* カード背景 */
--color-text         /* テキスト色 */
--color-border       /* ボーダー色 */

/* 習熟度カラー */
--color-mastered     /* 覚えた (緑) */
--color-almost       /* ほぼ (黄) */
--color-learning     /* うろ覚え (橙) */
--color-weak         /* 苦手 (赤) */
--color-new          /* 未学習 (灰) */
```

### 8.2 自動コントラスト計算

WCAGガイドラインに基づき、背景色からテキスト色を自動計算：

```javascript
getLuminance(hex) {
  // 相対輝度を計算
  const r = R / 255, g = G / 255, b = B / 255;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

getContrastColor(backgroundColor) {
  const lum = getLuminance(backgroundColor);
  return lum > 0.5 ? '#1f2937' : '#ffffff';
  // 明るい背景 → 暗いテキスト
  // 暗い背景   → 白いテキスト
}
```

### 8.3 プリセット

Ocean、Sakura、Forest、Sunset など複数のカラーパレットをプリセットとして提供。
カスタムプリセットの保存・読み込みも可能。

---

## 9. 認証・クラウド同期

### 9.1 Supabase設定

```javascript
// auth.js
const SUPABASE_URL = 'https://xxx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJ...';
```

### 9.2 Google OAuth

1. Googleでログイン
2. 招待コード確認（`invitations`テーブル）
3. ユーザー作成（`users`テーブル）
4. 学習データ同期開始

### 9.3 同期タイミング

- ログイン時: クラウドからローカルへロード
- 回答時: ローカル保存 → 即座にクラウドへプッシュ
- 手動同期ボタン: 強制的に同期

---

## 10. 各ページの機能詳細

### 10.1 ダッシュボード (index.html)
- ストリーク表示
- 習熟度円グラフ
- 教科選択（英語/古文/漢文/政経）
- クイックアクセスボタン

### 10.2 クイズ (quiz.html)
- チャプター選択
- 出題モード選択
- 問題数設定
- 制限時間設定
- ランクアップテスト

### 10.3 プロフィール (profile.html)
- テーマカラー設定
- 壁紙設定
- プリセット管理
- 学習データエクスポート

### 10.4 カレンダー (calendar.html)
- 日別学習履歴
- 月間ストリーク表示
- 手動記録追加

### 10.5 ポモドーロ (pomodoro.html)
- Swiss Modern風デザイン
- カスタムタイマー
- 壁紙対応

---

## 11. UI/UXこだわりポイント

### 11.1 アニメーション
- 正解/不正解時のフィードバック（色変化、チェックマーク）
- ページ遷移のフェード
- ボタンのホバー効果

### 11.2 レスポンシブデザイン
- モバイルファースト
- タップ領域を大きく確保
- スワイプジェスチャー対応（一部）

### 11.3 ダークモード
- システム設定に連動
- 手動切り替えも可能
- 全ページで統一されたダークテーマ

### 11.4 オフライン対応
- Service Workerでアセットをキャッシュ
- ネットワークエラー時も学習継続可能

---

## 12. 既知の課題と解決策

### 12.1 ID形式の統一
| 教科 | ID形式 | 例 |
|------|--------|-----|
| 英語 | 数値 | `1`, `1900` |
| 古文 | 数値 | `1`, `417` |
| 漢文 | 数値 | `1`, `100` |
| 政経 | 接頭辞+数値 | `seikei-1`, `j-9` |

> `getMastery()` 呼び出し時は `String(id)` で統一

### 12.2 政経チャプター範囲

| チャプター | 範囲 | 内容 |
|-----------|------|------|
| 1 | 1-25 | 天皇・戦争放棄・基本的人権 |
| 2 | 26-50 | 国民の権利義務・国会 |
| 3 | 51-75 | 国会・内閣 |
| 4 | 76-100 | 司法・財政・地方自治 |
| 5 | 101-125 | 改正・最高法規 |
| 6-8 | 126-200 | 経済・政治・国際関係 |

### 12.3 トラブルシューティング

詳細は [README.md](file:///Users/sugawaraichirou/Documents/ANKI-HUB/README.md) を参照。

---

## 付録: 再構築手順

### 1. 環境構築
```bash
# リポジトリをクローン
git clone https://github.com/xxx/sugwrAnki.git

# ローカルサーバー起動
npx serve .
```

### 2. Supabase設定
1. プロジェクト作成
2. Google OAuth有効化
3. 以下のテーブル作成:
   - `users`: ユーザー情報
   - `invitations`: 招待コード
   - `learning_progress`: 学習データ

### 3. 必須ファイル
最低限必要なファイル:
- `index.html` + `quiz.html`
- `learning-core.js`（アルゴリズム）
- `theme-system.js`（テーマ）
- `auth.js` + `storage.js`（認証・同期）
- 各教科のデータファイル

---

*この仕様書は 2026年1月7日 時点の内容です。*

---

## 13. 追加システム詳細

### 13.1 InputModeManager（3日間学習システム）

**ファイル**: `input_mode.js` (307行)

古文単語用の**インプット特化モード**。quiz.htmlとは独立したデータ管理。

```
Day 1: 初接触 (Initial Contact)
  - 単語を見て意味を確認
  - 時間制限なし
  - ブロック単位（50語/ブロック）で学習

Day 2: 高速判定 (Quick Judgment)
  - 知っている/知らないを即座に判定
  - 単語ごとにタイマー設定
  - 知らない単語は苦手マーク

Day 3: 音読固定化 (Voice & Fixation)
  - 音読しながら最終確認
  - 復習対象の絞り込み
```

### 13.2 kanbun.js（漢文縦書きレンダラー）

**ファイル**: `kanbun.js` (105行)

外部ライブラリ [kanbunHTML](https://github.com/untunt/kanbunHTML) を元にした漢文レンダリング。

#### 記法
```
原文:     未(いま)ダ[レ]嘗(かつ)テ見(み)ザル
結果HTML: ルビ + 送り仮名 + 返り点の正しい配置
```

#### ブラケット記法
| 記号 | 用途 |
|------|------|
| `()` | 振り仮名（ふりがな） |
| `{}` | 送り仮名 |
| `[]` | 返り点（レ、一二点など） |
| `‹›` | 再読文字の振り仮名 |
| `«»` | 再読文字の送り仮名 |

### 13.3 ポモドーロタイマー（Swiss Modern）

**ファイル**: `pomodoro.html` (2633行)

#### こだわりポイント

1. **iOS Clock専用フォント**
   - SF Numeric, SF Stencil Numeric, SF Rail Numeric
   - New York Numeric (セリフ体)
   - ADT Slab Numeric

2. **ダイヤル操作**
   - 円形UIをドラッグして時間設定
   - タッチ対応、ドラッグヒント表示

3. **壁紙対応**
   - 12種類のプリセット壁紙
   - パンアニメーション
   - 省電力モード（画面暗転 + 大きな時計表示）

4. **カスタムインターバル**
   - 作業時間、休憩時間、長休憩を自由に設定
   - セット回数の管理

### 13.4 QuizCapture（スキャン機能）

**ファイル**: `scan.html` (3236行)

問題集をカメラで撮影し、クイズデータに変換する機能。

#### ワークフロー
```
1. 画像選択/撮影
2. 領域選択（Crop Tool）
   - 問題領域（緑）
   - 解答領域（デフォルト）
3. 問題スロット作成
4. 選択肢入力（キーボードUI付き）
5. JSONエクスポート or 直接クイズ
```

#### 特殊機能
- **マーカー穴抜き**: 青マーカー部分を自動検出して穴埋め
- **長文分割**: 長い問題を複数ページに分割
- **Supabaseストレージ**: 画像をクラウド保存

### 13.5 storage.js（クラウド同期）

**デバウンス機能**付きの自動同期システム。

```javascript
const DEBOUNCE_MS = 2000; // 2秒待機
const MIN_LOAD_INTERVAL = 30000; // 最低30秒間隔

// 同期対象
const SYNC_APP_IDS = [
  'stats',      // LearningStats
  'english',    // MasteryTracker
  'kobun',
  'kanbun', 
  'seikei',
  'eiken',
  'wordlist'    // カスタム単語帳
];
```

### 13.6 auth.js（認証・招待システム）

#### 招待コードフロー
```
1. Googleログイン
2. invitationsテーブルでメール確認
3. 招待コード未使用の場合 → 入力要求
4. コード検証成功 → ユーザー作成
5. データ同期開始
```

#### Safari対応
```javascript
// Safari Private Browsing対策
function isStorageAvailable() {
  try {
    localStorage.setItem('test', 'test');
    localStorage.removeItem('test');
    return true;
  } catch(e) {
    return false;
  }
}
```

---

## 14. データベーススキーマ（Supabase）

### 14.1 usersテーブル
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  last_login TIMESTAMP
);
```

### 14.2 invitationsテーブル
```sql
CREATE TABLE invitations (
  id SERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  email TEXT,
  used_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### 14.3 studyテーブル
```sql
CREATE TABLE study (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  app_id TEXT NOT NULL,
  data JSONB NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, app_id)
);
```

---

## 15. CSS設計

### 15.1 v0-style.css
グローバルCSS変数とユーティリティクラス。

```css
:root {
  /* 色 */
  --color-primary: #4f46e5;
  --color-accent: #f97316;
  --color-background: #f8fafc;
  --color-surface: #ffffff;
  --color-text: #1f2937;
  --color-border: #e5e7eb;
  
  /* 習熟度色 */
  --color-mastered: #22c55e;
  --color-almost: #eab308;
  --color-learning: #f97316;
  --color-weak: #ef4444;
  --color-new: #9ca3af;
}

.dark {
  --color-background: #0f172a;
  --color-surface: #1e293b;
  --color-text: #f8fafc;
  --color-border: #334155;
}
```

### 15.2 apple-style.css
Apple風UIコンポーネント（ボタン、カード、グラスモーフィズム）。

---

## 16. PWA設定

### 16.1 manifest.json
```json
{
  "name": "sugwrAnki",
  "short_name": "sugwrAnki",
  "start_url": "/index.html",
  "display": "standalone",
  "background_color": "#f8fafc",
  "theme_color": "#4f46e5",
  "icons": [
    { "src": "favicon.png", "sizes": "512x512" }
  ]
}
```

### 16.2 sw.js (Service Worker)
```javascript
// キャッシュ対象
const CACHE_NAME = 'sugwrAnki-v1';
const urlsToCache = [
  '/',
  '/index.html',
  '/quiz.html',
  '/v0-style.css',
  '/learning-core.js',
  // データファイル
  '/vocab1900-data.js',
  '/kobun-data.js',
  // etc.
];
```

---

## 17. 再構築チェックリスト

### 必須実装（優先度順）
- [ ] learning-core.js（習熟度アルゴリズム）
- [ ] quiz.html（クイズ基本機能）
- [ ] localStorage データ構造
- [ ] 4択/タイピングモード
- [ ] 習熟度5段階システム
- [ ] 忘却曲線ブースト

### 推奨実装
- [ ] theme-system.js（テーマ）
- [ ] クラウド同期（Supabase）
- [ ] ストリーク機能
- [ ] チャプター選択

### オプション
- [ ] ポモドーロタイマー
- [ ] スキャン機能
- [ ] InputMode（3日間学習）

