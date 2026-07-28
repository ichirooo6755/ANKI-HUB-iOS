# Manaba 抽出（木・月）

Playwright（通常の Node スクリプト）で Manaba から問題を取得し、JSON に保存する。

## なぜ MCP ではないか

Cursor Playwright MCP の `browser_run_code_unsafe` は VM サンドボックス内で動き、`require('fs')` が使えない。  
抽出結果を `fs.writeFileSync` で確実に保存するため、このディレクトリのスクリプトを使う。

## 対象と分離

| 曜日 | ソース | 章名（accounting.json category） | 提出 |
|------|--------|--------------------------------|------|
| **木** | 採点外ドリル `course_6089558_drill_6812813` | `管理会計・経理実務（Manaba・木）` | 採点外のみ提出可（結果取得） |
| **月** | `(月)` 財務会計小テスト（`course_*_query_*`） | `管理会計・経理実務（Manaba・月）` | **提出しない**。受付終了後の「正解はこちら」のみ |

Subject はどちらも `accounting`。ChapterSelection で章（月/木）を選ぶ。  
**同時に複数 Manaba 提出プロセスを動かさない**（1プロセスのみ）。

## 手順

```bash
npm i
npx playwright install chromium

npm run manaba:extract          # 木・採点外
npm run manaba:extract:dry      # ログイン待ち確認のみ
npm run manaba:list             # (月)/(木) 一覧
npm run manaba:extract:mon      # 月・正解公開のみ（提出なし）
npm run manaba:merge
node scripts/manaba_extract/merge_pool.cjs --write
```

## 出力

| パス | 内容 |
|------|------|
| `out/pool.json` / `sources.json` | 木曜 |
| `out/pool_mon.json` / `sources_mon.json` | 月曜 |
| `out/query_list.json` | course query 一覧 |
| `storage/storageState.json` | SSO（**gitignore・コミットしない**） |

## ユニーク（2026-07-28）

| | choicesユニーク | ソース | アプリ展開 |
|--|-----------------|--------|------------|
| 木 | 60 | 67 | 115 |
| 月 | 23 | 56 | 62 |
| 合計 accounting | — | — | 221（+非Manaba44） |
