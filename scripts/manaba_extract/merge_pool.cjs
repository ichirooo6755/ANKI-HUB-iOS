#!/usr/bin/env node
/**
 * pool.json / pool_mon.json → accounting.json 形式へマージ
 *
 * 章分け:
 * - 木曜採点外ドリル → 「管理会計・経理実務（Manaba・木・25）」（公式の「25問」ドリル）
 * - 月曜小テスト     → 「管理会計・経理実務（Manaba・月）」
 * - 旧カテゴリ「管理会計・経理実務（Manaba）」は木に移行
 *
 * ルール（案A: Web と同じ選択肢数を維持）:
 * - 正解・重複キーは選択肢本文テキスト（番号依存禁止）
 * - wrong_multi: 各誤り文につき1問（select[0]=誤り本文）
 * - correct_multi: 各正解文につき1問（select[0]=正しい本文）
 * - fill_blank / single: select[0]=正解本文、options 全文維持
 *
 * Usage:
 *   npm run manaba:merge
 *   node scripts/manaba_extract/merge_pool.cjs --write
 */
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '../..');
const OUT_DIR = path.join(__dirname, 'out');
const POOL_THU = path.join(OUT_DIR, 'pool.json');
const SOURCES_THU = path.join(OUT_DIR, 'sources.json');
const POOL_MON = path.join(OUT_DIR, 'pool_mon.json');
const SOURCES_MON = path.join(OUT_DIR, 'sources_mon.json');
const FALLBACK_SOURCES = path.join(ROOT, '.tmp-manaba/sources.json');
const ACC_PATH = path.join(ROOT, 'Sources/ANKI-HUB-iOS/Resources/accounting.json');
const MERGED_OUT = path.join(OUT_DIR, 'accounting_manaba_merged.json');

const CAT_THU = '管理会計・経理実務（Manaba・木・25）';
const CAT_MON = '管理会計・経理実務（Manaba・月）';
const CAT_LEGACY = '管理会計・経理実務（Manaba）';

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

function isCorrectMultiType(prompt, type) {
  if (type === 'correct_multi') return true;
  const p = prompt || '';
  return /正し/.test(p) && (/全て|すべて|全部/.test(p) || /チェック/.test(p));
}

function loadSourcesFrom(paths, label) {
  for (const p of paths) {
    if (!fs.existsSync(p)) continue;
    const raw = JSON.parse(fs.readFileSync(p, 'utf8'));
    const list = Array.isArray(raw) ? raw : raw.sources || [];
    if (list.length) {
      console.log(`[load] ${label}: ${list.length} sources from ${p}`);
      return list;
    }
  }
  console.warn(`[load] ${label}: no sources found`);
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
    if (isNumberOnlyLabel(x)) continue;
    seen.add(x);
    out.push(x);
  }
  return out;
}

function toItems(sources, category) {
  const items = [];
  sources.forEach((src, i) => {
    const prompt = norm(src.prompt || '');
    const wrong = (src.wrong || []).map(norm).filter(Boolean);
    const correct = (src.correct || []).map(norm).filter(Boolean);
    const options = uniquePreserveOrder((src.options || []).map(norm).filter(Boolean));
    const qtype = src.type || (wrong.length ? 'wrong_multi' : 'single');
    const idx = i + 1;

    if (qtype === 'wrong_multi' || (wrong.length && isWrongType(prompt))) {
      wrong.forEach((w, j) => {
        const fromOptions = options.filter((o) => o !== w);
        const fallback = correct.filter((d) => d !== w);
        const others = fromOptions.length ? fromOptions : fallback;
        const sel = uniquePreserveOrder([w, ...others]);
        if (sel.length < 2) return;
        items.push({
          id: `acc-manaba-${idx}-${j + 1}`,
          category,
          text: isWrongType(prompt)
            ? '次のうち、明らかに誤っている説明はどれか。'
            : prompt.replace(/\(選択必須\)/g, '').trim() ||
              '次のうち正しいものはどれか。',
          select: sel,
        });
      });
      return;
    }

    if (qtype === 'correct_multi' || isCorrectMultiType(prompt, qtype)) {
      correct.forEach((c, j) => {
        const fromOptions = options.filter((o) => o !== c);
        const fallback = wrong.filter((d) => d !== c);
        const others = fromOptions.length ? fromOptions : fallback;
        const sel = uniquePreserveOrder([c, ...others]);
        if (sel.length < 2) return;
        items.push({
          id: `acc-manaba-${idx}-${j + 1}`,
          category,
          text: '次のうち、正しいものはどれか。',
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
    } else if (correct.length) {
      answer = correct[0];
      distractors = options.filter((x) => x !== answer);
      if (!distractors.length) distractors = correct.slice(1);
    }
    if (!answer || isNumberOnlyLabel(answer)) return;
    const sel = uniquePreserveOrder([answer, ...distractors].filter(Boolean));
    if (sel.length < 2) return;

    let text =
      prompt.replace(/\(選択必須\)/g, '').trim() || '次のうち正しいものはどれか。';
    if (qtype === 'fill_blank') {
      if (!/空欄|当てはまる|語句/.test(text)) {
        text = '次の空欄に当てはまる語句はどれか。';
      }
    }

    items.push({
      id: `acc-manaba-${idx}-1`,
      category,
      text,
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

function finalizeManaba(items, category, idPrefix) {
  const seen = new Set();
  const merged = [];
  const selectLenDist = {};
  for (const x of items) {
    const k = dedupeKey(x);
    if (!k || seen.has(k)) continue;
    if ((x.select || []).length < 2) continue;
    seen.add(k);
    const h = crypto.createHash('md5').update(idPrefix + k).digest('hex').slice(0, 8);
    const select = Array.isArray(x.select) ? x.select.slice() : [];
    selectLenDist[select.length] = (selectLenDist[select.length] || 0) + 1;
    merged.push({
      id: `${idPrefix}${h}`,
      category,
      text: x.text,
      select,
    });
  }
  return { merged, selectLenDist };
}

function uniqueChoiceSets(sources) {
  return new Set(
    sources.map((s) =>
      uniquePreserveOrder((s.options || []).map(norm).filter(Boolean))
        .slice()
        .sort()
        .join('||')
    )
  );
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const thuSources = loadSourcesFrom([SOURCES_THU, POOL_THU, FALLBACK_SOURCES], 'thu');
  const monSources = loadSourcesFrom([SOURCES_MON, POOL_MON], 'mon');

  const existing = JSON.parse(fs.readFileSync(ACC_PATH, 'utf8'));
  const nonManaba = existing.filter((x) => {
    const c = String(x.category || '');
    return !c.includes('Manaba');
  });

  const thu = finalizeManaba(toItems(thuSources, CAT_THU), CAT_THU, 'acc-manaba-thu-');
  const mon = finalizeManaba(toItems(monSources, CAT_MON), CAT_MON, 'acc-manaba-mon-');

  const out = [...nonManaba, ...thu.merged, ...mon.merged];
  const summary = {
    thu: {
      sources: thuSources.length,
      unique_source_choice_sets: uniqueChoiceSets(thuSources).size,
      items: thu.merged.length,
      select_length_dist: thu.selectLenDist,
      category: CAT_THU,
    },
    mon: {
      sources: monSources.length,
      unique_source_choice_sets: uniqueChoiceSets(monSources).size,
      items: mon.merged.length,
      select_length_dist: mon.selectLenDist,
      category: CAT_MON,
    },
    legacy_category_removed: CAT_LEGACY,
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
