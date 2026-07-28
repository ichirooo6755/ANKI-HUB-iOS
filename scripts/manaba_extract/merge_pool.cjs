#!/usr/bin/env node
/**
 * pool.json / sources.json → accounting.json 形式へマージ
 *
 * ルール（案A: Web と同じ選択肢数を維持）:
 * - 正解・重複キーはラジオ value（"1","2"）ではなく選択肢本文テキスト
 *   （Manaba は出題ごとに選択肢番号が入れ替わる）
 * - 「誤っている説明を2つ選べ」系: 各誤り文につき1問に分解
 *   - select[0] = その誤りの本文（アプリ上の単一正解）
 *   - 残りの選択肢は Web 元の options をすべて維持（基本5択。4/6もそのまま）
 * - 穴埋め single: Web の options を本文で重複除去して維持（多くは4択）
 *   - Manaba 側で本文重複がある場合はダミーを捏造せず短い select のまま
 * - 既存 accounting.json の非 Manaba 項目は保持し、Manaba カテゴリは完全差し替え
 *
 * Usage:
 *   npm run manaba:merge
 *   node scripts/manaba_extract/merge_pool.cjs --write
 *   node scripts/manaba_extract/merge_pool.cjs --dry-run
 */

'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '../..');
const OUT_DIR = path.join(__dirname, 'out');
const POOL_PATH = path.join(OUT_DIR, 'pool.json');
const SOURCES_PATH = path.join(OUT_DIR, 'sources.json');
const FALLBACK_SOURCES = path.join(ROOT, '.tmp-manaba/sources.json');
const ACC_PATH = path.join(ROOT, 'Sources/ANKI-HUB-iOS/Resources/accounting.json');
const MERGED_OUT = path.join(OUT_DIR, 'accounting_manaba_merged.json');

function parseArgs(argv) {
  return {
    write: argv.includes('--write'),
    dryRun: argv.includes('--dry-run') || !argv.includes('--write'),
  };
}

function norm(s) {
  return String(s || '')
    .replace(/\s+/g, ' ')
    .trim();
}

function isWrongType(prompt) {
  const p = prompt || '';
  return p.includes('誤') && p.includes('選');
}

function loadSources() {
  for (const p of [SOURCES_PATH, POOL_PATH, FALLBACK_SOURCES]) {
    if (!fs.existsSync(p)) continue;
    const raw = JSON.parse(fs.readFileSync(p, 'utf8'));
    const list = Array.isArray(raw) ? raw : raw.sources || [];
    if (list.length) {
      console.log(`[load] ${list.length} sources from ${p}`);
      return list;
    }
  }
  console.warn('[load] no sources found');
  return [];
}

function isNumberOnlyLabel(s) {
  return /^[①-⑳❶-❿\d]+$/.test(String(s || '').trim());
}

function uniquePreserveOrder(list) {
  const seen = new Set();
  const out = [];
  for (const x of list) {
    if (!x || seen.has(x)) continue;
    if (isNumberOnlyLabel(x)) continue; // 番号ラベルは捨て、本文のみ
    seen.add(x);
    out.push(x);
  }
  return out;
}

function toItems(sources) {
  const items = [];
  sources.forEach((src, i) => {
    const prompt = norm(src.prompt || '');
    const wrong = (src.wrong || []).map(norm).filter(Boolean);
    const correct = (src.correct || []).map(norm).filter(Boolean);
    const options = uniquePreserveOrder((src.options || []).map(norm).filter(Boolean));
    const qtype = src.type || (wrong.length ? 'wrong_multi' : 'single');
    const idx = i + 1;

    if (qtype === 'wrong_multi' || (wrong.length && isWrongType(prompt))) {
      // 案A: 元の options 全文を維持し、誤り1つを select[0] にする
      wrong.forEach((w, j) => {
        const fromOptions = options.filter((o) => o !== w);
        const fallback = correct.filter((d) => d !== w);
        const others = fromOptions.length ? fromOptions : fallback;
        const sel = uniquePreserveOrder([w, ...others]);
        if (sel.length < 2) return;
        items.push({
          id: `acc-manaba-${idx}-${j + 1}`,
          category: '管理会計・経理実務（Manaba）',
          text: isWrongType(prompt)
            ? '次のうち、明らかに誤っている説明はどれか。'
            : prompt.replace(/\(選択必須\)/g, '').trim() ||
              '次のうち正しいものはどれか。',
          select: sel,
        });
      });
      return;
    }

    let answer = null;
    let distractors = [];
    if (src.answer) {
      answer = norm(src.answer);
      distractors = (src.distractors || options).map(norm).filter((x) => x && x !== answer);
    } else if (src.checked) {
      answer = Array.isArray(src.checked) ? norm(src.checked[0]) : norm(src.checked);
      distractors = options.filter((x) => x !== answer);
    } else if (correct.length) {
      answer = correct[0];
      distractors = options.filter((x) => x !== answer);
      if (!distractors.length) distractors = correct.slice(1);
    }
    // 番号だけの正解は拒否（本文テキスト必須）
    if (!answer || isNumberOnlyLabel(answer)) return;
    // Web と同じ選択肢数を維持（slice しない）。本文重複は除去のみ（ダミー追加なし）
    const sel = uniquePreserveOrder([answer, ...distractors].filter(Boolean));
    if (sel.length < 2) return;
    items.push({
      id: `acc-manaba-${idx}-1`,
      category: '管理会計・経理実務（Manaba）',
      text:
        prompt.replace(/\(選択必須\)/g, '').trim() || '次のうち正しいものはどれか。',
      select: sel,
    });
  });
  return items;
}

function dedupeKey(item) {
  const sel = (item.select || []).map(norm);
  if (!sel.length) return '';
  return sel[0] + '||' + sel.slice(1).sort().join('||');
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const sources = loadSources();
  const existing = JSON.parse(fs.readFileSync(ACC_PATH, 'utf8'));
  const newItems = toItems(sources);

  const nonManaba = existing.filter((x) => !String(x.category || '').includes('Manaba'));

  // Manaba は完全差し替え（旧4択を残さない）
  const seen = new Set();
  const mergedManaba = [];
  const selectLenDist = {};
  for (const x of newItems) {
    const k = dedupeKey(x);
    if (!k || seen.has(k)) continue;
    if ((x.select || []).length < 2) continue;
    seen.add(k);
    const h = crypto.createHash('md5').update(k).digest('hex').slice(0, 8);
    const select = Array.isArray(x.select) ? x.select.slice() : [];
    selectLenDist[select.length] = (selectLenDist[select.length] || 0) + 1;
    mergedManaba.push({
      id: `acc-manaba-${h}`,
      category: x.category || '管理会計・経理実務（Manaba）',
      text: x.text,
      select,
    });
  }

  const out = [...nonManaba, ...mergedManaba];
  const uniqueSourceChoiceSets = new Set(
    sources.map((s) =>
      uniquePreserveOrder((s.options || []).map(norm).filter(Boolean))
        .slice()
        .sort()
        .join('||')
    )
  );
  const summary = {
    sources: sources.length,
    unique_source_choice_sets: uniqueSourceChoiceSets.size,
    manaba_items: mergedManaba.length,
    manaba_select_length_dist: selectLenDist,
    non_manaba: nonManaba.length,
    total_accounting: out.length,
    write: opts.write,
  };
  console.log(JSON.stringify(summary, null, 2));

  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.writeFileSync(MERGED_OUT, JSON.stringify(out, null, 2) + '\n', 'utf8');
  console.log(`[out] preview written: ${MERGED_OUT}`);

  if (opts.write) {
    fs.writeFileSync(ACC_PATH, JSON.stringify(out, null, 2) + '\n', 'utf8');
    console.log(`[write] updated ${ACC_PATH}`);
  } else {
    console.log('[dry-run] accounting.json は未更新。反映するには --write を付けて再実行');
  }
}

main();
