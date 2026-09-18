import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

// L161 (카라멜 광산 · 길 열기) 데이터 수정.
// 원본 보드는 런타임 규칙(순서 체인 + 일방통행 + 성격 젤리) 기준으로 풀 수 없음이
// 전수 탐색으로 확인됐다: 빨간 젤리 (4,7)이 노란 H4 블록을 8행에 가두고, 노란 젤리
// (3,4)(3,5)가 빨간 V4 블록의 3열 통과를 막아 서로 영원히 풀리지 않는다.
// 수정: 빨간 젤리 (4,7) → (1,4). 젤리 수·색·수용량·체인·일방통행은 그대로다.
// 다른 바이트는 모두 보존하고 청크 해시만 갱신한다. 실행: node tools/patch_level_161.mjs [--write]
const write = process.argv.includes('--write');
const root = new URL('../assets/data/', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');
const NUMBER = 161;
const NAME = '카라멜 광산 · 길 열기';
const BEFORE_GRID = ['_.______', '_.__..B_', '_...BB__', '_G.GBGB.', 'O.OYOGO.', '_R.YBR.R', '_R.R..RG', '....RY._', '__......'];
const AFTER_GRID = ['_.______', '_.__..B_', '_...BB__', '_G.GBGB.', 'OROYOGO.', '_R.YBR.R', '_R.R..RG', '.....Y._', '__......'];
const ROW_EDITS = [['O.OYOGO.', 'OROYOGO.'], ['....RY._', '.....Y._']];

const indexText = read('levels/index.json');
const index = JSON.parse(indexText);
const original = JSON.parse(read('levels.json'));
const expected = structuredClone(original);
const level = expected[NUMBER - 1];
assert.equal(level.name, NAME, 'L161 name');
const alreadyPatched = JSON.stringify(level.grid) === JSON.stringify(AFTER_GRID);
if (!alreadyPatched) assert.deepEqual(level.grid, BEFORE_GRID, 'L161 original grid');
level.grid = AFTER_GRID;

function patchText(path, text, target) {
  if (alreadyPatched) {
    assert.deepEqual(JSON.parse(text), target, `${path}: already patched`);
    return text;
  }
  const nameAt = text.indexOf(JSON.stringify(NAME));
  assert.ok(nameAt > 0, `${path}: L161 name not found`);
  assert.equal(text.indexOf(JSON.stringify(NAME), nameAt + 1), -1, `${path}: L161 name unique`);
  const gridAt = text.lastIndexOf('"grid"', nameAt);
  assert.ok(gridAt > 0, `${path}: grid before name`);
  const gridEnd = text.indexOf(']', gridAt);
  let segment = text.slice(gridAt, gridEnd);
  for (const [from, to] of ROW_EDITS) {
    const q = `"${from}"`;
    assert.equal(segment.split(q).length, 2, `${path}: row "${from}" appears once in L161 grid`);
    segment = segment.replace(q, `"${to}"`);
  }
  const after = text.slice(0, gridAt) + segment + text.slice(gridEnd);
  assert.deepEqual(JSON.parse(after), target, `${path}: only the L161 grid changed`);
  return after;
}

const updates = new Map();
updates.set('levels.json', patchText('levels.json', read('levels.json'), expected));
let nextIndexText = indexText;
for (const chunk of index.chunks) {
  if (NUMBER < chunk.start || NUMBER > chunk.end) continue;
  const path = `levels/${chunk.file}`;
  const before = read(path);
  assert.deepEqual(JSON.parse(before), original.slice(chunk.start - 1, chunk.end), `${path}: matches levels.json`);
  assert.equal(createHash('sha256').update(before).digest('hex'), chunk.sha256, `${path}: index hash`);
  const after = patchText(path, before, expected.slice(chunk.start - 1, chunk.end));
  const hash = createHash('sha256').update(after).digest('hex');
  nextIndexText = nextIndexText.replace(chunk.sha256, hash);
  updates.set(path, after);
}
updates.set('levels/index.json', nextIndexText);
if (write) for (const [path, data] of updates) writeFileSync(new URL(path, root), data);
console.log(`${write ? 'Updated' : 'Verified'} L${NUMBER} ${alreadyPatched ? '(already patched)' : ''}`);
console.log(AFTER_GRID.join('\n'));
