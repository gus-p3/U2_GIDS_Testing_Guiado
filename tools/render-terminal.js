'use strict';
/**
 * Turns a REAL command log (evidence/logs/*.txt) into a terminal-style PNG using
 * headless Chrome, so test runs can be shown as images in the README.
 * The text is not edited: only ANSI colour codes are removed and, optionally,
 * a line range is selected.
 *
 * Usage:
 *   node tools/render-terminal.js <log.txt> <out.png> "<title>" [fromRegex] [toRegex]
 */
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const CHROME = process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const [, , input, output, title = path.basename(input), from, to] = process.argv;
if (!input || !output) {
  console.error('Usage: node tools/render-terminal.js <log.txt> <out.png> "<title>" [fromRegex] [toRegex]');
  process.exit(1);
}

let lines = fs
  .readFileSync(input, 'utf8')
  .replace(/\x1b\[[0-9;]*[A-Za-z]/g, '')
  .replace(/\r/g, '')
  .split('\n');
if (from) {
  const start = lines.findIndex((line) => new RegExp(from).test(line));
  if (start >= 0) lines = lines.slice(start);
}
if (to) {
  const end = lines.findIndex((line) => new RegExp(to).test(line));
  if (end >= 0) lines = lines.slice(0, end + 1);
}
while (lines.length && !lines[lines.length - 1].trim()) lines.pop();

const escape = (text) => text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const colour = (line) => {
  const safe = escape(line);
  if (/✕|✗|\[E\]|FAIL|[1-9]\d* failed|Some tests failed|Expected:|Error:|Bad state|level=error|overflowed/.test(line)) return `<span class="bad">${safe}</span>`;
  if (/✓|✔|PASS|All tests passed|passed,|exit=0/.test(line)) return `<span class="ok">${safe}</span>`;
  if (/^\s*(Received|Actual|Which):/.test(line)) return `<span class="warn">${safe}</span>`;
  return safe;
};

const lineHeight = 18;
const height = Math.min(16000, 70 + lines.length * lineHeight + 30);
const html = `<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{margin:0;background:#0d1117}
  .win{font:13px/18px Consolas,"Cascadia Mono",monospace;color:#c9d1d9}
  .bar{background:#161b22;padding:9px 14px;color:#8b949e;font:13px Segoe UI,sans-serif;border-bottom:1px solid #30363d}
  .dot{display:inline-block;width:11px;height:11px;border-radius:50%;margin-right:6px}
  pre{margin:0;padding:12px 16px;white-space:pre-wrap;word-break:break-all}
  .ok{color:#3fb950}.bad{color:#f85149}.warn{color:#d29922}
</style></head><body><div class="win"><div class="bar">
  <span class="dot" style="background:#f85149"></span><span class="dot" style="background:#d29922"></span><span class="dot" style="background:#3fb950"></span>
  &nbsp;${escape(title)}</div><pre>${lines.map(colour).join('\n')}</pre></div></body></html>`;

const htmlFile = path.join(os.tmpdir(), `render-terminal-${process.pid}.html`);
fs.writeFileSync(htmlFile, html);
fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });
execFileSync(CHROME, [
  '--headless=new',
  '--disable-gpu',
  '--hide-scrollbars',
  `--window-size=1100,${height}`,
  `--screenshot=${path.resolve(output)}`,
  `file:///${htmlFile.replace(/\\/g, '/')}`,
], { stdio: 'ignore' });
fs.unlinkSync(htmlFile);
console.log(`${output} (${lines.length} lines)`);
