import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const macGodot = '/Applications/Godot_mono.app/Contents/MacOS/Godot';
const godot = process.env.JELLYMON_GODOT_BIN || (existsSync(macGodot) ? macGodot : 'godot');
const args = process.argv.slice(2);
const tests = args.includes('--shutdown-only')
  ? Array.from({ length: 3 }, () => ['--validate-shutdown'])
  : [
      ['--validate-localization'],
      ['--validate-story-localization'],
      ['--validate-story-typing'],
      ['--validate-story-overlay'],
      ['--validate-delayed-trap'],
      ['--validate-shutdown'],
      ...args.includes('--quick') ? [] : [[], ['--validate-levels'], ['--validate-late-play'], ['--validate-endgame']],
    ];

let failures = 0;
const logDir = mkdtempSync(join(tmpdir(), 'jellymon-verify-'));
console.log(`Logs: ${logDir}`);
let testIndex = 0;
for (const flags of tests) {
  const label = flags.join(' ') || 'smoke';
  const result = await new Promise(resolve => {
    const child = spawn(godot, ['--headless', '--path', root, '--log-file', join(logDir, `${++testIndex}.log`), ...(flags.length ? ['--', ...flags] : [])], {
      cwd: root,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let output = '';
    let timedOut = false;
    const timeout = setTimeout(() => {
      timedOut = true;
      child.kill('SIGTERM');
    }, 300_000);
    child.stdout.on('data', data => { output += data; });
    child.stderr.on('data', data => { output += data; });
    child.on('error', error => { output += `${error}\n`; });
    child.on('close', code => {
      clearTimeout(timeout);
      resolve({ code, output, timedOut });
    });
  });
  // Godot can return 0 even when shutdown leaks resources or a script reports an error.
  const badLog = /(?:SCRIPT ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use|Leaked instance:)/i.test(result.output);
  const passed = result.code === 0 && !result.timedOut && !badLog;
  console.log(`${passed ? 'PASS' : 'FAIL'} ${label}`);
  if (!passed) {
    failures++;
    console.error(result.output.trim());
    if (result.timedOut) console.error('Test exceeded 300 seconds.');
  }
}
process.exitCode = failures ? 1 : 0;
