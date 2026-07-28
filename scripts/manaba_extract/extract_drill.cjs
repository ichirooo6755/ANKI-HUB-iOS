#!/usr/bin/env node
/**
 * Manaba 採点外ドリル抽出（Playwright / Node CommonJS）
 *
 * - MCP の browser_run_code_unsafe では require('fs') が使えないため、
 *   リポジトリ内の通常 Playwright スクリプトとして fs / path を利用する。
 * - 対象は採点外ドリルのみ。採点対象小テストには遷移・提出しない。
 * - パスワードはコードに書かない。初回は headed ブラウザで SSO ログインを待つ。
 *
 * Usage:
 *   npm i
 *   npx playwright install chromium
 *   npm run manaba:extract
 *   npm run manaba:extract:dry   # ログイン待ちまで起動して終了（提出しない）
 *
 * Env / flags:
 *   --dry-run              ログイン待ち確認のみ（提出・抽出ループなし）
 *   --max-rounds=N         ドリル周回数（デフォルト 40）
 *   --stable-rounds=N      新規0件が連続 N 回で早期終了（デフォルト 8）
 *   --login-timeout-ms=N   ログイン待ち上限（デフォルト 600000 = 10分）
 *   --headless             headed をやめる（storageState がある場合のみ推奨）
 *   MANABA_DRILL_URL       上書き用 URL（デフォルトは採点外ドリル）
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname);
const OUT_DIR = path.join(ROOT, 'out');
const STORAGE_DIR = path.join(ROOT, 'storage');
const STORAGE_STATE = path.join(STORAGE_DIR, 'storageState.json');
const POOL_PATH = path.join(OUT_DIR, 'pool.json');

/** 採点外ドリルのみ。採点対象小テストの URL に変更しないこと。 */
const DEFAULT_DRILL_URL =
  'https://room.chuo-u.ac.jp/ct/course_6089558_drill_6812813';

const FORBIDDEN_URL_HINTS = [
  'examination',
  'exam_',
  '_test_',
  '小テスト',
];

function parseArgs(argv) {
  const opts = {
    dryRun: false,
    maxRounds: 40,
    stableRounds: 8,
    loginTimeoutMs: 600_000,
    headless: false,
    drillUrl: process.env.MANABA_DRILL_URL || DEFAULT_DRILL_URL,
  };
  for (const a of argv) {
    if (a === '--dry-run') opts.dryRun = true;
    else if (a === '--headless') opts.headless = true;
    else if (a.startsWith('--max-rounds=')) opts.maxRounds = Number(a.split('=')[1]) || opts.maxRounds;
    else if (a.startsWith('--stable-rounds='))
      opts.stableRounds = Number(a.split('=')[1]) || opts.stableRounds;
    else if (a.startsWith('--login-timeout-ms='))
      opts.loginTimeoutMs = Number(a.split('=')[1]) || opts.loginTimeoutMs;
    else if (a.startsWith('--url=')) opts.drillUrl = a.slice('--url='.length);
  }
  return opts;
}

function ensureDirs() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.mkdirSync(STORAGE_DIR, { recursive: true });
}

function assertAllowedDrillUrl(url) {
  const u = String(url || '');
  if (!u.includes('course_6089558_drill_6812813') && !process.env.MANABA_ALLOW_OTHER_DRILL) {
    throw new Error(
      `拒否: 採点外ドリル以外の URL です: ${u}\n` +
        `既定は ${DEFAULT_DRILL_URL} のみ。別ドリルを使う場合は MANABA_ALLOW_OTHER_DRILL=1`
    );
  }
  for (const hint of FORBIDDEN_URL_HINTS) {
    if (u.toLowerCase().includes(hint.toLowerCase()) && !u.includes('drill_6812813')) {
      throw new Error(`拒否: 採点対象っぽい URL ヒント "${hint}": ${u}`);
    }
  }
}

function norm(s) {
  return String(s || '')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * 重複キーはラジオ value（"1","2"）ではなく選択肢本文テキストで作る。
 * Manaba は出題ごとに選択肢番号が入れ替わるため、番号紐づけは不可。
 */
function sourceKey(entry) {
  const parts = [
    ...(entry.wrong || []),
    ...(entry.correct || []),
    entry.answer || '',
    entry.prompt || '',
    ...(entry.options || []),
  ]
    .map(norm)
    .filter(Boolean)
    // ①② や単独数字だけの残骸はキーに使わない
    .filter((p) => !/^[①-⑳❶-❿\d]+$/.test(p));
  return [...new Set(parts)].sort().join('||');
}

function uniqTexts(list) {
  const out = [];
  const seen = new Set();
  for (const raw of list || []) {
    const t = norm(raw);
    if (!t || seen.has(t)) continue;
    // 番号だけのラベルは捨て、本文のみ保持
    if (/^[①-⑳❶-❿\d]+$/.test(t)) continue;
    seen.add(t);
    out.push(t);
  }
  return out;
}

/** 穴埋め数値（約500 等）は短いので、長文説明より緩い下限を使う */
function isKeepableOptionText(t) {
  if (!t) return false;
  if (/^約[\d,]+/.test(t) || /（億円）|％|兆円/.test(t)) return t.length >= 2;
  return t.length >= 4;
}

function loadPool() {
  if (!fs.existsSync(POOL_PATH)) return [];
  try {
    const data = JSON.parse(fs.readFileSync(POOL_PATH, 'utf8'));
    return Array.isArray(data) ? data : data.sources || [];
  } catch {
    return [];
  }
}

function savePool(sources) {
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
  const payload = {
    meta: {
      drillUrl: DEFAULT_DRILL_URL,
      updatedAt: new Date().toISOString(),
      count: deduped.length,
      note: '採点外ドリルのみ。select 変換は npm run manaba:merge',
    },
    sources: deduped,
  };
  fs.writeFileSync(POOL_PATH, JSON.stringify(payload, null, 2) + '\n', 'utf8');
  // マージ互換: sources 配列だけも出す
  fs.writeFileSync(
    path.join(OUT_DIR, 'sources.json'),
    JSON.stringify(deduped, null, 2) + '\n',
    'utf8'
  );
  console.log(`[save] ${deduped.length} sources → ${POOL_PATH}`);
  return deduped;
}

function isLoginPage(url, bodyText) {
  const u = (url || '').toLowerCase();
  const t = bodyText || '';
  return (
    u.includes('sso') ||
    u.includes('login') ||
    u.includes('auth') ||
    /Web Single Sign On/i.test(t) ||
    /統合認証/i.test(t) ||
    (/User Name/i.test(t) && /Password/i.test(t))
  );
}

function isDrillReady(bodyText) {
  const t = bodyText || '';
  return (
    /スタート/.test(t) ||
    /提出/.test(t) ||
    /Q[０-９0-9]+[．.]/.test(t) ||
    /選択必須/.test(t) ||
    /ドリル/.test(t)
  );
}

/**
 * 1ラウンドのページ/設問カウント仮説用メトリクス
 * （「25」=ページ数? 実設問数? を実測）
 */
async function collectRoundMetrics(page) {
  return page.evaluate(() => {
    const body = document.body ? document.body.innerText : '';
    const qMarks = body.match(/Q[０-９0-9]+/g) || [];
    const monMarks = body.match(/問[１-９1-9]/g) || [];
    const answerCount = (body.match(/回答数\s*(\d+)\s*\/\s*(\d+)/) || []).slice(1);
    const questionCount = (body.match(/設問数\s*[：:]?\s*(\d+)/) || [])[1] || null;
    const pageHints = [];
    for (const m of body.matchAll(/(?:ページ|page)\s*[：:]?\s*(\d+)\s*\/\s*(\d+)/gi)) {
      pageHints.push({ cur: m[1], total: m[2] });
    }
    const twentyFive = [...body.matchAll(/25\s*問|（25問）|25問/g)].map((m) => m[0]);
    const scoreLine = (body.match(/得点[^\n]{0,40}/) || [])[0] || null;
    const inputs = document.querySelectorAll(
      'input[type=checkbox], input[type=radio]'
    ).length;
    return {
      url: location.href,
      bodyLen: body.length,
      qMarks: [...new Set(qMarks)],
      monMarks: [...new Set(monMarks)],
      answerCountNum: answerCount[0] ? Number(answerCount[0]) : null,
      answerCountDen: answerCount[1] ? Number(answerCount[1]) : null,
      questionCount: questionCount ? Number(questionCount) : null,
      pageHints,
      twentyFiveMentions: twentyFive,
      scoreLine,
      inputCount: inputs,
      preview: body.slice(0, 900),
    };
  });
}

async function extractFromPage(page) {
  return page.evaluate(() => {
    const norm = (s) =>
      String(s || '')
        .replace(/\s+/g, ' ')
        .trim();

    const body = document.body ? document.body.innerText : '';

    // 結果画面: 正解 / 不正解 マーク付き選択肢
    const resultBlocks = [];
    const queryRoots = [
      ...document.querySelectorAll(
        '.query, .queryframe, .queryv4, [class*="query"], form, .contents'
      ),
    ];
    const roots = queryRoots.length ? queryRoots : [document.body];

    function parseBlock(root) {
      const text = root.innerText || '';
      if (!/Q[０-９0-9]+/.test(text) && !/選択必須/.test(text) && !/問[１-９1-9]/.test(text))
        return null;

      const promptLine =
        (text.match(/Q[０-９0-9]+[．.]\s*[^\n]+/) || [])[0] ||
        (text.match(/問[１-９1-9][．.\s]*[^\n]+/) || [])[0] ||
        (text.match(/明らかに誤[^\n]+/) || [])[0] ||
        '';

      const options = [];
      const wrong = [];
      const correct = [];

      // checkbox/radio + label本文（value 番号は使わない。出題ごとに番号が変わるため）
      const inputs = [...root.querySelectorAll('input[type=checkbox], input[type=radio]')];
      if (inputs.length >= 2) {
        for (const inp of inputs) {
          let label =
            (inp.id && document.querySelector(`label[for="${inp.id}"]`)) ||
            inp.closest('label') ||
            inp.parentElement;
          let t = norm(label ? label.innerText : '');
          t = t.replace(/^[①-⑳❶-❿\d]+[\.．、\s]*/, '').trim();
          // 穴埋め数値は短い。ダミー番号のみは除外。
          const keepShort = /^約[\d,]+/.test(t) || /（億円）|％|兆円|株式会社/.test(t);
          if (!t || (!keepShort && t.length < 4)) continue;
          if (keepShort && t.length < 2) continue;
          if (options.some((o) => o === t)) continue; // 本文重複は1つに
          options.push(t);

          const row = inp.closest('tr, li, div, label') || label;
          const rowText = (row && row.innerText) || '';
          const cls = `${inp.className} ${row ? row.className : ''} ${label ? label.className : ''}`;
          const markedWrong =
            /不正解|誤り|×|wrong/i.test(rowText) ||
            /incorrect|wrong|ng/i.test(cls) ||
            (row && row.querySelector && row.querySelector('.incorrect, .wrong, .ng, .false'));
          const markedCorrect =
            /正解|○|correct/i.test(rowText) ||
            /correct|ok|right/i.test(cls) ||
            (row && row.querySelector && row.querySelector('.correct, .right, .ok, .true'));

          // checked on answerlog = 正解本文
          if (inp.checked && !markedWrong) correct.push(t);
          if (markedWrong) wrong.push(t);
          else if (markedCorrect) correct.push(t);
        }
      }

      // テキストベース fallback（結果ページの「正解は…」等）
      if (!options.length) {
        const lines = text
          .split('\n')
          .map((l) => norm(l))
          .filter(Boolean);
        for (const l of lines) {
          if (l.includes('選択必須') || l.includes('設問数') || l.includes('経過')) continue;
          if (/^Q[０-９0-9]+/.test(l)) continue;
          if (l.length < 12 || l.length > 500) continue;
          if (/^(提出|次へ|戻る|中断|スタート)/.test(l)) continue;
          if (!options.some((o) => o.slice(0, 40) === l.slice(0, 40))) options.push(l);
        }
      }

      if (!promptLine && options.length < 2) return null;

      const isWrongType = /誤/.test(promptLine) && /選/.test(promptLine);
      return {
        type: isWrongType ? 'wrong_multi' : 'single',
        name: '',
        prompt: norm(promptLine),
        options,
        wrong: [...new Set(wrong)],
        correct: [...new Set(correct)],
        rawSnippet: text.slice(0, 400),
      };
    }

    /** Q1/Q2 を別ブロックに分割（同一 form に複数設問があるため） */
    function splitByQuestion(root) {
      const html = root.innerHTML || '';
      const text = root.innerText || '';
      // 設問見出しで DOM を切るのが難しい場合、input name グループ単位で分割
      const inputs = [...root.querySelectorAll('input[type=checkbox], input[type=radio]')];
      if (inputs.length < 2) return [parseBlock(root)].filter(Boolean);

      const byName = {};
      for (const inp of inputs) {
        const name = inp.name || inp.id || 'x';
        if (!byName[name]) byName[name] = [];
        byName[name].push(inp);
      }
      const names = Object.keys(byName);
      if (names.length <= 1) {
        const one = parseBlock(root);
        return one ? [one] : [];
      }

      const blocks = [];
      const qHeads = [...text.matchAll(/Q[０-９0-9]+[．.][^\n]*/g)].map((m) => m[0]);
      const monHeads = [...text.matchAll(/問[１-９1-9][．.\s]?[^\n]*/g)].map((m) => m[0]);
      const heads = qHeads.length ? qHeads : monHeads;

      names.forEach((name, idx) => {
        const list = byName[name];
        const options = [];
        const checkedOpts = [];
        const wrong = [];
        const correct = [];
        for (const inp of list) {
          let label =
            (inp.id && document.querySelector(`label[for="${inp.id}"]`)) ||
            inp.closest('label') ||
            inp.parentElement;
          let t = norm(label ? label.innerText : '');
          t = t.replace(/^[①-⑳❶-❿\d]+[\.．、\s]*/, '').trim();
          const keepShort = /^約[\d,]+/.test(t) || /（億円）|％|兆円|株式会社/.test(t);
          if (!t || (!keepShort && t.length < 4)) continue;
          if (options.includes(t)) continue;
          options.push(t);
          const row = inp.closest('tr, li, div, label') || label;
          const rowText = (row && row.innerText) || '';
          const cls = `${inp.className} ${row ? row.className : ''} ${label ? label.className : ''}`;
          const markedWrong =
            /不正解|誤り|×|wrong/i.test(rowText) ||
            /incorrect|wrong|ng/i.test(cls) ||
            (row && row.querySelector && row.querySelector('.incorrect, .wrong, .ng, .false'));
          const markedCorrect =
            /正解|○|correct/i.test(rowText) ||
            /correct|ok|right/i.test(cls) ||
            (row && row.querySelector && row.querySelector('.correct, .right, .ok, .true'));
          const isChecked =
            inp.checked || (row && /\bchecked\b/i.test(row.className || ''));
          if (isChecked) checkedOpts.push(t);
          if (markedWrong) wrong.push(t);
          else if (markedCorrect) correct.push(t);
        }
        if (options.length < 2) return;
        const prompt = heads[idx] || heads[0] || '';
        const isWrongType = (/誤/.test(prompt) && /選/.test(prompt)) || (/誤/.test(text) && /選/.test(text) && /Q[０-９0-9]+/.test(prompt || text));
        // answerlog: li.checked = 正解選択肢。wrong_multi では「選ぶべき誤り文」が入る
        let wrongOut = [...new Set(wrong)];
        let correctOut = [...new Set(correct)];
        if (checkedOpts.length) {
          if (isWrongType) {
            wrongOut = [...new Set([...wrongOut, ...checkedOpts])];
            correctOut = options.filter((o) => !wrongOut.includes(o));
          } else {
            correctOut = [...new Set([...correctOut, ...checkedOpts])];
          }
        }
        blocks.push({
          type: isWrongType ? 'wrong_multi' : 'single',
          name: name,
          prompt: norm(prompt),
          options,
          wrong: wrongOut,
          correct: correctOut,
          rawSnippet: text.slice(0, 200),
        });
      });
      return blocks.length ? blocks : [parseBlock(root)].filter(Boolean);
    }

    const seen = new Set();
    for (const root of roots) {
      const parsedList = splitByQuestion(root);
      for (const parsed of parsedList) {
        if (!parsed || parsed.options.length < 2) continue;
        const key = (parsed.prompt + '||' + parsed.options.join('||')).slice(0, 200);
        if (seen.has(key)) continue;
        seen.add(key);
        resultBlocks.push(parsed);
      }
    }

    // ページ全体を1ブロックとして再試行
    if (!resultBlocks.length) {
      const wholes = splitByQuestion(document.body);
      for (const whole of wholes) {
        if (whole && whole.options.length >= 2) resultBlocks.push(whole);
      }
    }

    return {
      bodyPreview: body.slice(0, 1200),
      blocks: resultBlocks,
      hasSubmit: !!document.querySelector(
        'input[type=submit][value*="提出"], input[value*="提出"], button'
      ),
      hasStart: !![...document.querySelectorAll('input,button,a')].find((el) =>
        /スタート/.test(el.value || el.textContent || '')
      ),
      // 「採点結果を公開」等の説明文だけでは結果画面とみなさない
      hasResult:
        (/あなたの解答|得点\s*[：:]|採点結果\s*$|正解はこちら/.test(body) ||
          !!document.querySelector('.correct, .incorrect, .right, .wrong')) &&
        !document.querySelector('input[type=checkbox]:not(:disabled), input[type=radio]:not(:disabled)'),
      hasAnswerInputs: document.querySelectorAll(
        'input[type=checkbox]:not(:disabled), input[type=radio]:not(:disabled)'
      ).length,
    };
  });
}

async function clickByText(page, patterns) {
  return page.evaluate((pats) => {
    const els = [...document.querySelectorAll('input,button,a')];
    for (const pat of pats) {
      const re = new RegExp(pat);
      const el = els.find((e) => {
        const label = (e.value || e.textContent || '').replace(/\s+/g, ' ').trim();
        // ナビの「提出記録」等は除外（ドリルの提出ボタンではない）
        if (/提出記録|提出履歴|成績|シラバス|ログアウト|設定/.test(label)) return false;
        return re.test(label);
      });
      if (el) {
        el.click();
        return el.value || el.textContent || pat;
      }
    }
    return null;
  }, patterns);
}

/** 採点外なので提出して結果を見る。答えは適当に（結果画面で正誤を取る） */
async function answerAndSubmit(page) {
  async function answerCurrent() {
    await page.evaluate(() => {
      const groups = {};
      for (const inp of document.querySelectorAll(
        'input[type=checkbox]:not(:disabled), input[type=radio]:not(:disabled)'
      )) {
        const name = inp.name || inp.id || 'x';
        if (!groups[name]) groups[name] = [];
        groups[name].push(inp);
      }
      for (const list of Object.values(groups)) {
        const n = Math.min(2, list.length);
        for (let i = 0; i < n; i++) {
          if (!list[i].checked) list[i].click();
        }
      }
    });
  }

  // 設問ページが複数ある場合: 回答 → 次へ を繰り返し、確認画面で提出
  for (let step = 0; step < 10; step++) {
    await answerCurrent();
    const state = await page.evaluate(() => {
      const labels = [...document.querySelectorAll('input,button,a')].map((e) =>
        (e.value || e.textContent || '').replace(/\s+/g, ' ').trim()
      );
      return {
        hasNext: labels.some((l) => l === '次へ'),
        hasSubmit: labels.some((l) => l === '提出' || l === '提出する'),
        hasBack: labels.some((l) => l === '戻る'),
        url: location.href,
      };
    });

    if (state.hasSubmit && (state.hasBack || /queryconfirm/.test(state.url))) {
      const clicked = await clickByText(page, ['^提出$', '^提出する$']);
      await page.waitForTimeout(1200);
      return clicked || '提出';
    }
    if (state.hasNext) {
      const clicked = await clickByText(page, ['^次へ$']);
      console.log('[nav] page step', step, clicked);
      await page.waitForTimeout(1000);
      continue;
    }
    // 提出だけある場合
    if (state.hasSubmit) {
      const clicked = await clickByText(page, ['^提出$', '^提出する$']);
      await page.waitForTimeout(1200);
      return clicked || '提出';
    }
    break;
  }
  return null;
}

/**
 * Manaba の answerlog（提出後の解答ログ）から正誤を抽出。
 * ページ構造差に備えて DOM + テキストの両系統。
 */
async function extractAnswerLog(page) {
  // answerlog リンクがあれば開く
  const href = await page.evaluate(() => {
    const a = [...document.querySelectorAll('a')].find((x) =>
      /answerlog|解答|正解|結果/.test((x.href || '') + (x.textContent || ''))
    );
    return a ? a.href : null;
  });
  if (href && /answerlog|正解|結果|解答/.test(href + 'x')) {
    try {
      await page.goto(href, { waitUntil: 'domcontentloaded', timeout: 30_000 });
      await page.waitForTimeout(800);
    } catch {
      /* ignore */
    }
  }

  return page.evaluate(() => {
    const norm = (s) =>
      String(s || '')
        .replace(/\s+/g, ' ')
        .trim();

    const blocks = [];
    // 行ごとに ○/× や「正解」「不正解」が付く形式
    const rows = [...document.querySelectorAll('tr, li, .answer, .query, div')];
    const byQ = {};

    function ensure(qid) {
      if (!byQ[qid]) {
        byQ[qid] = {
          type: 'wrong_multi',
          name: qid,
          prompt: '',
          options: [],
          wrong: [],
          correct: [],
        };
      }
      return byQ[qid];
    }

    for (const row of rows) {
      const t = norm(row.innerText || '');
      if (t.length < 10 || t.length > 800) continue;
      const qm = t.match(/Q[０-９0-9]+/);
      const qid = qm ? qm[0] : null;

      // 選択肢っぽい長文 + 正誤マーク
      const isWrong = /(?:^|\s)[×xX]|不正解|誤り/.test(t) || row.querySelector('.incorrect, .wrong');
      const isCorrect =
        /(?:^|\s)[○◯]|正解(?!率)/.test(t) || row.querySelector('.correct, .right');

      if (!isWrong && !isCorrect) continue;

      let opt = t
        .replace(/Q[０-９0-9]+[．.]?[^\n]*/g, '')
        .replace(/[×xX○◯]/g, '')
        .replace(/不正解|正解|誤り/g, '')
        .replace(/^[①-⑳\d]+[\.．、\s]*/, '')
        .trim();
      opt = norm(opt);
      // 長文説明は12文字以上、穴埋め数値は短くてよい（番号のみは不可）
      const shortOk = /^約[\d,]+/.test(opt) || /（億円）|％|兆円/.test(opt);
      if (!opt || (/^[①-⑳\d]+$/.test(opt))) continue;
      if (!shortOk && opt.length < 12) continue;
      if (shortOk && opt.length < 2) continue;

      const b = ensure(qid || 'q');
      if (!b.options.includes(opt)) b.options.push(opt);
      if (isWrong && !b.wrong.includes(opt)) b.wrong.push(opt);
      else if (isCorrect && !b.correct.includes(opt)) b.correct.push(opt);
    }

    // プロンプト拾い
    const body = document.body ? document.body.innerText : '';
    for (const m of body.matchAll(/Q[０-９0-9]+[．.]\s*([^\n]+)/g)) {
      const qid = m[0].match(/Q[０-９0-9]+/)[0];
      const b = ensure(qid);
      b.prompt = norm(m[0]);
      if (/誤/.test(b.prompt) && /選/.test(b.prompt)) b.type = 'wrong_multi';
    }

    for (const b of Object.values(byQ)) {
      if (b.options.length >= 2 || b.wrong.length || b.correct.length) blocks.push(b);
    }
    return blocks;
  });
}

async function waitForLogin(page, timeoutMs) {
  const start = Date.now();
  console.log(
    '[login] SSO ログインが必要です。開いたブラウザで中央大学統合認証にログインしてください。'
  );
  console.log('[login] パスワードはコードに保存されません。ログイン完了まで待機中…');
  while (Date.now() - start < timeoutMs) {
    const url = page.url();
    let body = '';
    try {
      body = await page.evaluate(() => (document.body ? document.body.innerText : ''));
    } catch {
      /* navigation mid-flight */
    }
    if (!isLoginPage(url, body) && isDrillReady(body)) {
      console.log('[login] ドリル画面を検出。storageState を保存します。');
      return true;
    }
    if (!isLoginPage(url, body) && /manaba|room\.chuo-u\.ac\.jp\/ct\//i.test(url)) {
      // manaba 内だがスタート前の説明ページ等
      if (/スタート|ドリル|設問/.test(body)) {
        console.log('[login] Manaba 画面を検出。storageState を保存します。');
        return true;
      }
    }
    await page.waitForTimeout(1500);
  }
  return false;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  assertAllowedDrillUrl(opts.drillUrl);
  ensureDirs();

  console.log('[config]', {
    drillUrl: opts.drillUrl,
    dryRun: opts.dryRun,
    maxRounds: opts.maxRounds,
    stableRounds: opts.stableRounds,
    headless: opts.headless,
    storageState: fs.existsSync(STORAGE_STATE) ? STORAGE_STATE : '(none)',
  });

  const launchOpts = {
    headless: opts.headless,
    channel: undefined,
  };

  const contextOpts = {
    viewport: { width: 1280, height: 900 },
    locale: 'ja-JP',
  };
  if (fs.existsSync(STORAGE_STATE)) {
    contextOpts.storageState = STORAGE_STATE;
    console.log('[auth] 既存 storageState を再利用:', STORAGE_STATE);
  }

  const browser = await chromium.launch(launchOpts);
  const context = await browser.newContext(contextOpts);
  const page = await context.newPage();

  try {
    await page.goto(opts.drillUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
    await page.waitForTimeout(1000);

    let body = await page.evaluate(() => (document.body ? document.body.innerText : ''));
    let url = page.url();

    if (isLoginPage(url, body)) {
      if (opts.headless) {
        throw new Error(
          'ログインが必要ですが --headless です。headed で再実行し、ブラウザで SSO ログインしてください。'
        );
      }
      const ok = await waitForLogin(page, opts.loginTimeoutMs);
      if (!ok) throw new Error('ログイン待ちタイムアウト');
      await context.storageState({ path: STORAGE_STATE });
      console.log('[auth] storageState 保存:', STORAGE_STATE);
      // ドリル URL へ再ナビ
      await page.goto(opts.drillUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
    } else if (!fs.existsSync(STORAGE_STATE)) {
      // すでにセッションあり（稀）→ 保存
      await context.storageState({ path: STORAGE_STATE });
      console.log('[auth] storageState 保存:', STORAGE_STATE);
    }

    body = await page.evaluate(() => (document.body ? document.body.innerText : ''));
    console.log('[page] preview:\n', body.slice(0, 400));

    if (opts.dryRun) {
      console.log('[dry-run] ログイン後（またはセッション再利用後）まで到達。提出・抽出は行いません。');
      console.log('[dry-run] OK');
      return;
    }

    let pool = loadPool();
    console.log(`[pool] 既存 ${pool.length} 件`);
    const metricsPath = path.join(OUT_DIR, 'round_metrics.json');
    const roundMetrics = [];
    let stableStreak = 0;

    for (let round = 1; round <= opts.maxRounds; round++) {
      console.log(`\n===== round ${round}/${opts.maxRounds} =====`);
      const beforeCount = savePool(pool).length;
      await page.goto(opts.drillUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
      await page.waitForTimeout(800);

      // 採点対象に飛ばされていないか確認
      const cur = page.url();
      assertAllowedDrillUrl(cur);

      // スタート前の説明文に「25問」があるか
      const introMetrics = await collectRoundMetrics(page);

      const started = await clickByText(page, ['^スタート$', 'スタート']);
      if (started) {
        console.log('[nav] clicked', started);
        await page.waitForTimeout(1200);
      }

      const beforeSubmitMetrics = await collectRoundMetrics(page);
      let snap = await extractFromPage(page);
      console.log(
        '[extract] blocks=',
        snap.blocks.length,
        'hasResult=',
        snap.hasResult,
        'answerInputs=',
        snap.hasAnswerInputs
      );
      console.log(
        '[metrics before]',
        JSON.stringify({
          answer: `${beforeSubmitMetrics.answerCountNum}/${beforeSubmitMetrics.answerCountDen}`,
          questionCount: beforeSubmitMetrics.questionCount,
          qMarks: beforeSubmitMetrics.qMarks,
          monMarks: beforeSubmitMetrics.monMarks,
          pageHints: beforeSubmitMetrics.pageHints,
          twentyFive: beforeSubmitMetrics.twentyFiveMentions,
          inputs: beforeSubmitMetrics.inputCount,
        })
      );

      // 問題画面 → 次へ → 確認 → 提出 → 結果
      const needsSubmit = (snap.hasAnswerInputs || 0) > 0 || !snap.hasResult;
      if (needsSubmit) {
        const sub = await answerAndSubmit(page);
        console.log('[submit] clicked', sub);
        await page.waitForTimeout(1000);
        snap = await extractFromPage(page);
        console.log(
          '[extract after submit] blocks=',
          snap.blocks.length,
          'hasResult=',
          snap.hasResult,
          'answerInputs=',
          snap.hasAnswerInputs
        );
      }

      // 「正解はこちら」 / answerlog
      const opened = await clickByText(page, ['正解はこちら', '正解', '結果', '解答', 'answerlog']);
      if (opened) {
        console.log('[nav] result', opened);
        await page.waitForTimeout(1200);
        snap = await extractFromPage(page);
      }

      let answerBlocks = [];
      if (!snap.blocks.some((b) => b.wrong.length || b.correct.length)) {
        answerBlocks = await extractAnswerLog(page);
        console.log('[answerlog] blocks=', answerBlocks.length);
      } else {
        console.log(
          '[extract result] withMarks=',
          snap.blocks.filter((b) => b.wrong.length || b.correct.length).length
        );
      }

      const afterMetrics = await collectRoundMetrics(page);

      const toSave = [
        ...snap.blocks,
        ...answerBlocks.filter(
          (a) =>
            !snap.blocks.some(
              (b) => sourceKey(b) === sourceKey(a) || (a.prompt && a.prompt === b.prompt)
            )
        ),
      ];

      for (const b of toSave) {
        // wrong_multi: 結果で wrong/correct が取れない場合は options のみ保存（後で人手 or 再実行）
        // 正解・選択肢は常に本文テキスト。ラジオ value 番号は使わない。
        const entry = {
          type: b.type,
          name: b.name || `qid-r${round}`,
          prompt: b.prompt,
          options: uniqTexts(b.options),
          wrong: uniqTexts(b.wrong),
          correct: uniqTexts(b.correct),
          answer: b.correct && b.correct[0] ? norm(b.correct[0]) : undefined,
          _key: sourceKey(b),
          _round: round,
        };
        // answer がある single は distractors も本文で
        if (entry.type === 'single' && entry.answer) {
          entry.distractors = entry.options.filter((o) => o !== entry.answer);
        }
        // 正誤が取れないブロックはプールを汚さない
        if (
          !(entry.wrong && entry.wrong.length) &&
          !(entry.correct && entry.correct.length) &&
          !entry.answer
        ) {
          continue;
        }
        pool.push(entry);
      }

      pool = savePool(pool);
      const afterCount = pool.length;
      const newCount = afterCount - beforeCount;
      if (newCount === 0) stableStreak += 1;
      else stableStreak = 0;

      const metricRow = {
        round,
        beforeCount,
        afterCount,
        newCount,
        stableStreak,
        blocksSaved: toSave.length,
        introTwentyFive: introMetrics.twentyFiveMentions,
        beforeSubmit: {
          answerCountNum: beforeSubmitMetrics.answerCountNum,
          answerCountDen: beforeSubmitMetrics.answerCountDen,
          questionCount: beforeSubmitMetrics.questionCount,
          qMarks: beforeSubmitMetrics.qMarks,
          monMarks: beforeSubmitMetrics.monMarks,
          pageHints: beforeSubmitMetrics.pageHints,
          inputCount: beforeSubmitMetrics.inputCount,
          twentyFive: beforeSubmitMetrics.twentyFiveMentions,
        },
        after: {
          answerCountNum: afterMetrics.answerCountNum,
          answerCountDen: afterMetrics.answerCountDen,
          questionCount: afterMetrics.questionCount,
          qMarks: afterMetrics.qMarks,
          monMarks: afterMetrics.monMarks,
          pageHints: afterMetrics.pageHints,
          scoreLine: afterMetrics.scoreLine,
          twentyFive: afterMetrics.twentyFiveMentions,
          preview: afterMetrics.preview,
        },
      };
      roundMetrics.push(metricRow);
      fs.writeFileSync(metricsPath, JSON.stringify(roundMetrics, null, 2) + '\n', 'utf8');
      console.log(`[pool] ${afterCount} (+${newCount}) stable=${stableStreak}/${opts.stableRounds}`);

      // 「もう一度」や一覧へ
      const again = await clickByText(page, ['もう一度', '再挑戦', 'スタート', 'ドリル']);
      if (again) console.log('[nav] again', again);
      await page.waitForTimeout(500);

      if (stableStreak >= opts.stableRounds) {
        console.log(
          `\n[stable] 新規0が ${opts.stableRounds} 連続。収束と判断して終了（pool=${afterCount}）`
        );
        break;
      }
    }

    console.log('\n[done] unique sources:', loadPool().length);
    console.log('[metrics]', metricsPath);
    console.log('[next] npm run manaba:merge で accounting.json 形式に変換');
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('[error]', err.message || err);
  process.exit(1);
});
