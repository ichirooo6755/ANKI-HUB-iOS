#!/usr/bin/env node
/**
 * 月曜(月) 財務会計小テストを「正解はこちら」から抽出（提出しない）。
 * 受付終了・正解公開済みのもののみ対象。
 *
 * Usage:
 *   node scripts/manaba_extract/extract_mon_quizzes.cjs
 *   node scripts/manaba_extract/extract_mon_quizzes.cjs --limit=2
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname);
const STORAGE_STATE = path.join(ROOT, 'storage', 'storageState.json');
const OUT_DIR = path.join(ROOT, 'out');
const LIST = path.join(OUT_DIR, 'query_list.json');
const POOL_MON = path.join(OUT_DIR, 'pool_mon.json');
const SOURCES_MON = path.join(OUT_DIR, 'sources_mon.json');

function parseArgs(argv) {
  const opts = { limit: 0, headless: true };
  for (const a of argv) {
    if (a === '--headed') opts.headless = false;
    else if (a.startsWith('--limit=')) opts.limit = Number(a.split('=')[1]) || 0;
  }
  return opts;
}

function norm(s) {
  return String(s || '')
    .replace(/\s+/g, ' ')
    .trim();
}

function sourceKey(entry) {
  const parts = [
    ...(entry.wrong || []),
    ...(entry.correct || []),
    entry.answer || '',
    entry.prompt || '',
    ...(entry.options || []),
    entry.blankId || '',
  ]
    .map(norm)
    .filter(Boolean)
    .filter((p) => !/^[①-⑳❶-❿\d]+$/.test(p));
  return [...new Set(parts)].sort().join('||');
}

function uniqTexts(list) {
  const out = [];
  const seen = new Set();
  for (const raw of list || []) {
    const t = norm(raw);
    if (!t || seen.has(t)) continue;
    if (/^[①-⑳❶-❿\d]+$/.test(t)) continue;
    seen.add(t);
    out.push(t);
  }
  return out;
}

async function extractAnswerPage(page) {
  return page.evaluate(() => {
    const norm = (s) =>
      String(s || '')
        .replace(/\s+/g, ' ')
        .trim();
    const blocks = [];

    function classifyPrompt(prompt) {
      const p = prompt || '';
      if (/正し/.test(p) && (/全て|すべて|全部/.test(p) || /チェック/.test(p))) return 'correct_multi';
      if (/誤/.test(p) && /選/.test(p)) return 'wrong_multi';
      if (/空欄|当てはまる|語句を答え/.test(p)) return 'fill_blank';
      return 'single';
    }

    function promptNear(el) {
      const paper = el.closest('.querypaper, .queryv4, .querybody, td, form') || document.body;
      const lines = (paper.innerText || '')
        .split('\n')
        .map((l) => norm(l))
        .filter(Boolean);
      return (
        lines.find((l) => /正し|誤|空欄|当てはまる|次の|選択必須/.test(l) && l.length > 10) ||
        lines.find((l) => /^設問/.test(l)) ||
        ''
      );
    }

    const choiceInputs = [
      ...document.querySelectorAll('input[type=checkbox], input[type=radio]'),
    ];
    const byName = {};
    for (const inp of choiceInputs) {
      const name = inp.name || inp.id || 'x';
      if (!byName[name]) byName[name] = [];
      byName[name].push(inp);
    }

    for (const [name, list] of Object.entries(byName)) {
      const options = [];
      const wrong = [];
      const correct = [];
      for (const inp of list) {
        let label =
          (inp.id && document.querySelector(`label[for="${inp.id}"]`)) ||
          inp.closest('label') ||
          inp.parentElement;
        let t = norm(label ? label.innerText : '');
        t = t.replace(/^[①-⑳❶-❿\d]+[\.．、\s]*/, '').trim();
        if (!t || t.length < 2) continue;
        if (options.includes(t)) continue;
        options.push(t);
        const row = inp.closest('li, tr, div, label') || label;
        const isChecked =
          inp.checked || (row && /\bchecked\b/i.test(row.className || ''));
        if (isChecked) correct.push(t);
        else wrong.push(t);
      }
      if (options.length < 2) continue;
      const prompt = promptNear(list[0]);
      let type = classifyPrompt(prompt);
      if (type === 'single' && correct.length >= 2 && /正し/.test(prompt)) type = 'correct_multi';
      if (type === 'wrong_multi') {
        blocks.push({
          type: 'wrong_multi',
          name,
          prompt,
          options,
          wrong: [...correct],
          correct: [...wrong],
        });
      } else if (type === 'correct_multi') {
        blocks.push({
          type: 'correct_multi',
          name,
          prompt,
          options,
          correct: [...correct],
          wrong: [...wrong],
        });
      } else {
        blocks.push({
          type: 'single',
          name,
          prompt,
          options,
          correct: correct.slice(0, 1),
          wrong: options.filter((o) => o !== correct[0]),
          answer: correct[0],
        });
      }
    }

    const blanks = [...document.querySelectorAll('input.queryinput, input[type=text].queryinput')].filter(
      (el) => el.name && /^qid/i.test(el.name) && el.value
    );
    if (blanks.length) {
      const prompt = promptNear(blanks[0]);
      const answers = blanks.map((el) => {
        const raw = el.value || '';
        const alts = raw.split(/[;；]/).map((x) => x.trim()).filter(Boolean);
        return { name: el.name, raw, primary: alts[0] || '', alts };
      });
      const optionPool = [...new Set(answers.map((a) => a.primary).filter(Boolean))];
      for (const a of answers) {
        if (!a.primary) continue;
        const options =
          optionPool.length >= 2
            ? optionPool.slice()
            : [a.primary, ...a.alts.filter((x) => x !== a.primary)];
        if (options.length < 2) continue;
        blocks.push({
          type: 'fill_blank',
          name: a.name,
          blankId: a.name,
          prompt: prompt || '次の空欄に当てはまる語句はどれか。',
          options: [...new Set(options)],
          correct: [a.primary],
          wrong: options.filter((o) => o !== a.primary),
          answer: a.primary,
          answerAlts: a.alts,
        });
      }
    }

    return {
      bodyPreview: (document.body ? document.body.innerText : '').slice(0, 2500),
      blocks,
      choiceInputCount: choiceInputs.length,
      blankCount: blanks.length,
    };
  });
}

async function openAnswerPage(page, item) {
  await page.goto(item.href, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  await page.waitForTimeout(800);

  const answerHref = await page.evaluate(() => {
    const a = [...document.querySelectorAll('a')].find((x) =>
      /正解はこちら/.test(x.textContent || '')
    );
    return a ? a.href : null;
  });

  const body = await page.evaluate(() => (document.body ? document.body.innerText : ''));
  if (!/受付終了|提出済|正解はこちら|採点結果|正解と配点/.test(body)) {
    return { skipped: true, reason: '結果未公開 or 受付中の可能性', url: page.url() };
  }
  if (/受付中/.test(body) && /未提出/.test(body) && !/受付終了|提出済/.test(body)) {
    return { skipped: true, reason: '受付中・未提出のため提出しない', url: page.url() };
  }

  if (answerHref) {
    await page.goto(answerHref, { waitUntil: 'domcontentloaded', timeout: 60_000 });
    await page.waitForTimeout(1000);
  }

  const snap = await extractAnswerPage(page);
  return { skipped: false, snap, url: page.url() };
}

function savePool(sources, metaExtra) {
  const byKey = new Map();
  for (const s of sources) {
    const k = s._key || sourceKey(s);
    if (!k) continue;
    const score =
      (s.wrong && s.wrong.length ? 10 : 0) +
      (s.correct && s.correct.length ? 5 : 0) +
      (s.answer ? 3 : 0) +
      ((s.options && s.options.length) || 0);
    const prev = byKey.get(k);
    if (!prev || score > prev._score) {
      byKey.set(k, { ...s, _key: k, _score: score });
    }
  }
  const deduped = [...byKey.values()].map(({ _score, ...rest }) => rest);
  const choiceSets = new Set(
    deduped.map((s) =>
      uniqTexts(s.options)
        .slice()
        .sort()
        .join('||')
    )
  );
  const payload = {
    meta: {
      weekday: 'mon',
      updatedAt: new Date().toISOString(),
      count: deduped.length,
      unique_choice_sets: choiceSets.size,
      note: '月曜小テスト。提出せず正解公開ページから取得',
      ...metaExtra,
    },
    sources: deduped,
  };
  fs.writeFileSync(POOL_MON, JSON.stringify(payload, null, 2) + '\n', 'utf8');
  fs.writeFileSync(SOURCES_MON, JSON.stringify(deduped, null, 2) + '\n', 'utf8');
  console.log(`[save] ${deduped.length} sources (choiceSets=${choiceSets.size}) → ${POOL_MON}`);
  return deduped;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(STORAGE_STATE)) {
    console.error('[error] storageState なし');
    process.exit(2);
  }
  if (!fs.existsSync(LIST)) {
    console.error('[error] query_list.json なし。先に list_query.cjs を実行');
    process.exit(2);
  }

  const list = JSON.parse(fs.readFileSync(LIST, 'utf8'));
  let mon = list.mon.filter((x) => /小テスト/.test(x.title) && x.kind === 'query');
  if (opts.limit > 0) mon = mon.slice(0, opts.limit);
  console.log('[config] Monday quizzes:', mon.length);

  const browser = await chromium.launch({ headless: opts.headless });
  const context = await browser.newContext({
    storageState: STORAGE_STATE,
    viewport: { width: 1280, height: 900 },
    locale: 'ja-JP',
  });
  const page = await context.newPage();
  const pool = [];
  const perQuiz = [];

  try {
    for (const item of mon) {
      console.log(`\n===== ${item.title} =====`);
      const res = await openAnswerPage(page, item);
      if (res.skipped) {
        console.log('[skip]', res.reason);
        perQuiz.push({ title: item.title, href: item.href, skipped: true, reason: res.reason });
        continue;
      }
      const blocks = res.snap.blocks || [];
      console.log(
        '[extract] blocks=',
        blocks.length,
        'types=',
        blocks.map((b) => b.type).join(',')
      );
      let saved = 0;
      for (const b of blocks) {
        const entry = {
          type: b.type,
          name: b.name || item.contentId,
          prompt: b.prompt,
          options: uniqTexts(b.options),
          wrong: uniqTexts(b.wrong),
          correct: uniqTexts(b.correct),
          answer: b.answer ? norm(b.answer) : b.correct && b.correct[0] ? norm(b.correct[0]) : undefined,
          answerAlts: b.answerAlts,
          blankId: b.blankId,
          sourceTitle: item.title,
          sourceUrl: item.href,
          weekday: 'mon',
          _key: sourceKey(b),
        };
        if ((entry.type === 'single' || entry.type === 'fill_blank') && entry.answer) {
          entry.distractors = entry.options.filter((o) => o !== entry.answer);
        }
        if (
          !(entry.wrong && entry.wrong.length) &&
          !(entry.correct && entry.correct.length) &&
          !entry.answer
        ) {
          continue;
        }
        pool.push(entry);
        saved += 1;
      }
      perQuiz.push({ title: item.title, href: item.href, blocks: blocks.length, saved, url: res.url });
      savePool(pool, { perQuiz });
    }
    const final = savePool(pool, { perQuiz });
    console.log('\n[done] sources=', final.length);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('[error]', err.message || err);
  process.exit(1);
});
