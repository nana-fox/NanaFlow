#!/usr/bin/env python3
"""Read-only path/mtime/SHA-256 receipt; never decode production data."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path

ROOTS = [
    'Library/Containers/com.nanafox.NanaFlow',
    'Library/Containers/com.nanafox.NanaFlow.Widget',
    'Library/Group Containers/group.com.nanafox.NanaFlow',
    'Library/Preferences/com.nanafox.NanaFlow.plist',
]


def snapshot():
    rows = []
    for relative in ROOTS:
        path = Path.home() / relative
        if not path.exists():
            rows.append({'path': str(path), 'missing': True})
            continue
        for entry in sorted([path] if path.is_file() else path.rglob('*')):
            if entry.is_symlink():
                rows.append({'path': str(entry), 'symlink': os.readlink(entry)})
                continue
            if entry.is_file():
                stat = entry.stat()
                digest = hashlib.sha256()
                with entry.open('rb') as stream:
                    for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                        digest.update(chunk)
                rows.append({'path': str(entry), 'size': stat.st_size, 'mtime_ns': stat.st_mtime_ns, 'sha256': digest.hexdigest()})
    return {'created': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'files': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--compare', type=Path)
    args = parser.parse_args()
    after = snapshot()
    args.output.write_text(json.dumps(after, indent=2))
    print('Read-only receipt:', len(after['files']), 'entries;', args.output)
    if args.compare:
        before = json.loads(args.compare.read_text())
        previous = {row['path']: row for row in before['files']}
        current = {row['path']: row for row in after['files']}
        changes = []
        for path in sorted(previous.keys() | current.keys()):
            a, b = previous.get(path), current.get(path)
            if a != b:
                changes.append({'path': path, 'before': a, 'after': b})
        report = {'identical': not changes, 'before_count': len(previous), 'after_count': len(current), 'changes': changes}
        args.output.with_name('production-comparison.json').write_text(json.dumps(report, indent=2))
        print('IDENTICAL' if not changes else f'DIFFERENT: {len(changes)} files (paths, mtimes and hashes only; do not inspect contents)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
