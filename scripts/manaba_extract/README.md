# Manaba 採点外ドリル抽出

Playwright（通常の Node スクリプト）で採点外ドリルだけを取得し、JSON に保存する。

## なぜ MCP ではないか

Cursor Playwright MCP の `browser_run_code_unsafe` は VM サンドボックス内で動き、`require('fs')` が使えない。  
抽出結果を `fs.writeFileSync` で確実に保存するため、このディレクトリのスクリプトを使う。

## 対象

- URL: `https://room.chuo-u.ac.jp/ct/course_6089558_drill_6812813`
- **採点外のみ**。採点対象小テストは提出しない（URL ガードあり）
- パスワードはコードに書かない（headed ブラウザで SSO ログイン）

## 手順

```bash
# リポジトリルートで
npm i
npx playwright install chromium

# 初回: ブラウザが開く → 中央大学 SSO でログイン
npm run manaba:extract

# ログイン待ちまで起動確認のみ（提出しない）
npm run manaba:extract:dry

# pool → accounting 形式（プレビュー）
npm run manaba:merge

# accounting.json に書き込み
node scripts/manaba_extract/merge_pool.cjs --write
```

## 出力

| パス | 内容 |
|------|------|
| `scripts/manaba_extract/out/pool.json` | 抽出プール（meta + sources） |
| `scripts/manaba_extract/out/sources.json` | sources 配列のみ |
| `scripts/manaba_extract/out/accounting_manaba_merged.json` | マージ結果プレビュー |
| `scripts/manaba_extract/storage/storageState.json` | SSO セッション（**gitignore・コミットしない**） |

## 変換ルール

「明らかに誤った説明を2つ選べ」→ **案A**: 各誤り文を `select[0]`（アプリ上の正解）にした択一問題に分解する。  
**選択肢は Web 元の `options` 全文を維持**（基本5択。穴埋め single は多く4択。4択へ切り捨てない）。

**重要:** Manaba は出題ごとに選択肢番号（①② / radio value）が入れ替わる。  
抽出・マージのキーと `select[0]` は必ず**選択肢本文テキスト**で保持する（番号紐づけ禁止）。

### ユニークの定義

- ソースのユニークは **問題文 stem ではなく choices セット**（順序無視）で数える。stem 文言は「明らかに誤った説明を2つ選べ」等が再利用される
- 現状: ソース50（choices セットユニーク）→ アプリ展開90（wrong×2 分解）。accounting 合計134（+非Manaba44）
- 再試験（2026-07-28）: storageState 再利用・3ラウンド。結果「正解はこちら」から正解本文取得成功

穴埋めで Manaba 側の選択肢本文が重複している場合は、ダミーを捏造せずユニーク本文のまま残す。
