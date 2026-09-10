import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

// Mechanical migration: preserve every byte except time values and chunk hashes.
const write = process.argv.includes('--write');
const root = new URL('../assets/data/', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');
const indexText = read('levels/index.json');
const index = JSON.parse(indexText);
const original = JSON.parse(read('levels.json'));
const expected = structuredClone(original);
let changed = 0;
for (let i = 69; i < expected.length; i++) {
  if (expected[i].time < 90) {
    expected[i].time = 90;
    changed++;
  }
}
const updates = new Map();
function migrate(path, start, target) {
  const before = read(path);
  let offset = 0;
  const after = before.replace(/("time"\s*:\s*)([\d.]+)/g, (match, prefix, value) => {
    const number = start + offset++;
    return number >= 70 && Number(value) < 90 ? `${prefix}90.0` : match;
  });
  assert.equal(offset, target.length, `${path}: time field count`);
  assert.deepEqual(JSON.parse(after), target, `${path}: only intended time changes`);
  if (!write) assert.equal(after, before, `${path}: migration required`);
  updates.set(path, after);
  return after;
}
migrate('levels.json', 1, expected);
let nextIndexText = indexText;
for (const chunk of index.chunks) {
  const path = `levels/${chunk.file}`;
  const before = read(path);
  assert.deepEqual(JSON.parse(before), original.slice(chunk.start - 1, chunk.end));
  assert.equal(createHash('sha256').update(before).digest('hex'), chunk.sha256);
  const after = migrate(path, chunk.start, expected.slice(chunk.start - 1, chunk.end));
  const hash = createHash('sha256').update(after).digest('hex');
  nextIndexText = nextIndexText.replace(chunk.sha256, hash);
}
updates.set('levels/index.json', nextIndexText);
if (write) for (const [path, data] of updates) writeFileSync(new URL(path, root), data);
console.log(`${write ? 'Updated' : 'Verified'} ${expected.length} levels; raised ${changed} timers; boards, rules and existing longer timers preserved.`);
for (const number of [69, 70, 71, 100, 1000]) console.log(`Level ${number}: ${expected[number - 1].time}s`);
