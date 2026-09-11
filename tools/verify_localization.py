#!/usr/bin/env python3
"""Check actual copy coverage and report locale overrides separately from English fallback."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ['ko', 'en', 'ja', 'zh_CN', 'zh_TW', 'fr', 'de', 'es']
HANGUL = re.compile('[가-힣]')
TOKENS = re.compile(r'%[0-9.]*[dsf]|\{[a-z_]+\}')
errors = []
catalogs = {locale: json.loads((ROOT / f'assets/localization/{locale}.json').read_text()) for locale in LOCALES}
english = catalogs['en']
for locale, catalog in catalogs.items():
    for key, value in catalog.items():
        if key not in english:
            errors.append(f'{locale}: unknown key {key}')
        if not isinstance(value, str) or not value.strip():
            errors.append(f'{locale}: empty translation {key}')
            continue
        if TOKENS.findall(key) != TOKENS.findall(value):
            errors.append(f'{locale}: format placeholder mismatch {key}')
        if locale != 'ko' and HANGUL.search(value):
            errors.append(f'{locale}: Korean in translated copy {key}')
    if locale in ['ko', 'en'] and set(catalog) != set(english):
        errors.append(f'{locale}: incomplete base catalog')
    print(f'{locale}: {len(catalog)} explicit entries, {len(set(english) - set(catalog))} English fallbacks')

# Literal extraction ignores comments; only explicit translation calls require UI entries.
lex = re.compile(r'#[^\n]*|"(?:\\.|[^"\\])*"')
for path in (ROOT / 'scripts').rglob('*.gd'):
    source = path.read_text()
    for match in lex.finditer(source):
        if not match[0].startswith('"') or not HANGUL.search(match[0]):
            continue
        if not re.search(r'(?:L10n\.text|\btr)\(\s*$', source[:match.start()]):
            continue
        key = json.loads(match[0])
        if key not in english:
            errors.append(f'{path.relative_to(ROOT)}: missing UI copy {key}')

# Check source data too: dynamically loaded names/hints are not visible in script-only scans.
def check_data(value, path):
    if isinstance(value, dict):
        for child in value.values():
            check_data(child, path)
    elif isinstance(value, list):
        for child in value:
            check_data(child, path)
    elif isinstance(value, str) and HANGUL.search(value) and value not in english:
        errors.append(f'{path}: untranslated data text {value}')

for path in (ROOT / 'assets/data').rglob('*.json'):
    check_data(json.loads(path.read_text()), path.relative_to(ROOT))
for error in errors:
    print('ERROR:', error)
print(f'[localization static coverage] failures={len(errors)}')
raise SystemExit(1 if errors else 0)
