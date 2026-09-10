import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const catalog = JSON.parse(fs.readFileSync(path.join(root, "assets/localization/ko.json"), "utf8"));
const files = ["Title.gd", "HUD.gd", "Map.gd", "Game.gd", "StoryScreen.gd", "TutorialGuide.gd"];
const write = process.argv.includes("--write");
const escapeRegex = value => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
let remaining = 0;
let changed = 0;

for (const filename of files) {
  const fullPath = path.join(root, "scripts", filename);
  let source = fs.readFileSync(fullPath, "utf8");
  const before = source;
  for (const key of Object.keys(catalog).sort((a, b) => b.length - a.length)) {
    if (key.includes("\n") || key.includes('"')) continue;
    const quoted = `"${key}"`;
    const escaped = escapeRegex(key);
    source = source.replace(
      new RegExp(`((?:\\.text|tooltip_text|placeholder_text)\\s*=\\s*)"${escaped}"`, "g"),
      `$1tr(${quoted})`,
    );
    source = source.replace(
      new RegExp(`(_(?:button|big_button|result_button|title_label)\\()"${escaped}"`, "g"),
      `$1tr(${quoted})`,
    );
  }
  for (const key of Object.keys(catalog)) {
    const escaped = escapeRegex(key);
    const rawPattern = new RegExp(`(?:\\.text|tooltip_text|placeholder_text)\\s*=\\s*"${escaped}"`);
    if (rawPattern.test(source)) remaining += 1;
  }
  if (source !== before) {
    changed += 1;
    if (write) fs.writeFileSync(fullPath, source);
  }
}

console.log(JSON.stringify({ changed_files: changed, remaining_catalog_literals: remaining, mode: write ? "write" : "check" }));
if (!write && (changed > 0 || remaining > 0)) process.exitCode = 1;
