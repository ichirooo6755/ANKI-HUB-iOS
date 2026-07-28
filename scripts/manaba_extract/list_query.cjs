#!/usr/bin/env node
/**
 * course_*_query ページからドリル／小テスト一覧を取得し、(月)/(木) を分類する。
 * 提出はしない。storageState を再利用。
 *
 * Usage:
 *   node scripts/manaba_extract/list_query.cjs
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname);
const STORAGE_STATE = path.join(ROOT, 'storage', 'storageState.json');
const OUT_DIR = path.join(ROOT, 'out');
const DEFAULT_URL = 'https://room.chuo-u.ac.jp/ct/course_6089558_query';

function parseArgs(argv) {
  const opts = { url: process.env.MANABA_QUERY_URL || DEFAULT_URL, headless: true };
  for (const a of argv) {
    if (a === '--headed') opts.headless = false;
    else if (a.startsWith('--url=')) opts.url = a.slice('--url='.length);
  }
  return opts;
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

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(STORAGE_STATE)) {
    console.error('[error] storageState がありません:', STORAGE_STATE);
    process.exit(2);
  }

  const browser = await chromium.launch({ headless: opts.headless });
  const context = await browser.newContext({
    storageState: STORAGE_STATE,
    viewport: { width: 1280, height: 900 },
    locale: 'ja-JP',
  });
  const page = await context.newPage();

  try {
    await page.goto(opts.url, { waitUntil: 'domcontentloaded', timeout: 60_000 });
    await page.waitForTimeout(1500);

    const url = page.url();
    const body = await page.evaluate(() => (document.body ? document.body.innerText : ''));
    if (isLoginPage(url, body)) {
      console.error('[error] SSO ログインが必要です。headed で manaba:extract を再実行してください。');
      process.exit(3);
    }

    const items = await page.evaluate(() => {
      const norm = (s) =>
        String(s || '')
          .replace(/\s+/g, ' ')
          .trim();
      const out = [];
      for (const a of document.querySelectorAll('a[href]')) {
        const href = a.href || '';
        if (!/\/ct\/course_\d+_(drill|query)_\d+/.test(href)) continue;
        const title = norm(a.innerText || a.textContent || '');
        if (!title || title.length < 2) continue;
        const row = a.closest('tr, li, div, td') || a.parentElement;
        const rowText = norm(row ? row.innerText : title);
        const gradedHints = /採点|成績|試験|examination|小テスト/.test(rowText + title);
        const ungraded = /採点外|練習|ドリル|セルフ/.test(rowText + title);
        let weekday = null;
        if (/[（(]月[）)]/.test(title + rowText)) weekday = 'mon';
        else if (/[（(]木[）)]/.test(title + rowText)) weekday = 'thu';
        const idMatch = href.match(/course_(\d+)_(drill|query)_(\d+)/);
        out.push({
          title,
          href,
          weekday,
          kind: idMatch ? idMatch[2] : null,
          courseId: idMatch ? idMatch[1] : null,
          contentId: idMatch ? idMatch[3] : null,
          gradedHints,
          ungraded,
          rowPreview: rowText.slice(0, 200),
        });
      }
      const seen = new Set();
      return out.filter((x) => {
        if (seen.has(x.href)) return false;
        seen.add(x.href);
        return true;
      });
    });

    fs.mkdirSync(OUT_DIR, { recursive: true });
    const payload = {
      meta: { url: opts.url, fetchedAt: new Date().toISOString(), pageUrl: page.url(), count: items.length },
      items,
      mon: items.filter((x) => x.weekday === 'mon'),
      thu: items.filter((x) => x.weekday === 'thu'),
      unmarked: items.filter((x) => !x.weekday),
    };
    const outPath = path.join(OUT_DIR, 'query_list.json');
    fs.writeFileSync(outPath, JSON.stringify(payload, null, 2) + '\n', 'utf8');
    console.log('[count]', items.length, 'mon=', payload.mon.length, 'thu=', payload.thu.length);
    for (const x of payload.mon) console.log('[月]', x.title, x.href);
    for (const x of payload.thu) console.log('[木]', x.title, x.href);
    console.log('[out]', outPath);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('[error]', err.message || err);
  process.exit(1);
});
