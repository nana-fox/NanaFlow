#!/usr/bin/env python3
"""Conservative source-key audit, including literals passed through runtime helpers.

Every Chinese Swift literal in the three shipping source trees is a UI key.
Scanning literals rather than just Text()/String(localized:) also catches ternary
branches and title/unit arguments forwarded to LocalizedStringKey/LocalizationValue.
Interpolations are normalized to the format key SwiftUI uses for String values.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
TOKEN = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"', re.S)


def source_keys():
    keys = {}
    for tree in ("NanaFocus", "NanaShared", "NanaFlowWidget"):
        for path in sorted((ROOT / "Sources" / tree).rglob("*.swift")):
            source = path.read_text()
            for match in TOKEN.finditer(source):
                token = match[0]
                if not token.startswith('"'):
                    continue
                # Chinese source literals are intentionally audited regardless of
                # their call site; new dynamic UI helpers cannot silently escape.
                if not re.search(r'[\u3400-\u9fff]', token):
                    continue
                key = token[1:-1].replace(r'\"', '"').replace(r'\n', '\n')
                key = re.sub(r'\\\([^)]*\)', '%@', key)
                line = source.count('\n', 0, match.start()) + 1
                keys.setdefault(key, []).append(f"{path.relative_to(ROOT)}:{line}")
    # Explicit non-Chinese localization calls are checked too.
    for path in sorted((ROOT / 'Sources').rglob('*.swift')):
        source = path.read_text()
        for match in re.finditer(r'String\(localized:\s*"([^"\\]*)"', source):
            key = match[1]
            location = f"{path.relative_to(ROOT)}:{source.count(chr(10), 0, match.start()) + 1}"
            if location not in keys.get(key, []):
                keys.setdefault(key, []).append(location)
    return keys


def translations():
    result = {}
    for name in ('Localizable.strings', 'Localizable.stringsdict'):
        path = ROOT / 'Sources/NanaFocus/en.lproj' / name
        result.update(json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)])))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit', type=Path, help='Write the full key/file/translation Markdown table')
    args = parser.parse_args()
    keys, english = source_keys(), translations()
    missing = sorted(k for k in keys if k not in english)
    invalid = sorted(k for k in keys if isinstance(english.get(k), str) and re.search(r'[\u3400-\u9fff]', english[k]))
    if args.audit:
        def cell(value):
            return str(value).replace('|', r'\|').replace('\n', '<br>')
        rows = ['| Key | Source | English |', '|---|---|---|']
        for key in sorted(keys):
            value = english.get(key, '**MISSING**')
            rows.append(f"| {cell(key)} | {'<br>'.join(keys[key])} | {cell(value)} |")
        args.audit.write_text('\n'.join(rows) + '\n')
    for key in missing:
        print(f"MISSING {key!r}: {', '.join(keys[key])}")
    for key in invalid:
        print(f"NON-ENGLISH {key!r}: {english[key]}")
    print(f"Audited {len(keys)} source keys; {len(missing)} missing English entries; {len(invalid)} non-English translations.")
    return 1 if missing or invalid else 0


if __name__ == '__main__':
    raise SystemExit(main())
