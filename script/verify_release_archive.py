#!/usr/bin/env python3
"""Inspect local release artifacts without launching or installing an app."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--previous', type=Path, required=True)
    parser.add_argument('--export-app', type=Path, required=True)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    app = args.archive / 'Products/Applications/NanaFlow.app'
    report = {'archive_path': str(args.archive), 'bundles': {}}
    for name, bundle in [('app', app), ('widget', app / 'Contents/PlugIns/NanaFlowWidget.appex')]:
        info = plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
        assert info['CFBundleShortVersionString'] == '1.0.2', info
        assert info['CFBundleVersion'] == '5', info
        expected_id = 'com.nanafox.NanaFlow' + ('.Widget' if name == 'widget' else '')
        assert info['CFBundleIdentifier'] == expected_id, info
        subprocess.run(['codesign', '--verify', '--strict', str(bundle)], check=True)
        signature = subprocess.check_output(['codesign', '-dvv', str(bundle)], stderr=subprocess.STDOUT, text=True)
        assert 'TeamIdentifier=LTLULSL8A2' in signature
        assert 'Authority=Apple Development: Nio D (SA88DN9S45)' in signature
        report['bundles'][name] = {key: info[key] for key in ['CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion']}
        report['bundles'][name]['signature'] = signature
    current = plistlib.loads((args.archive / 'Info.plist').read_bytes())['ApplicationProperties']
    previous = plistlib.loads((args.previous / 'Info.plist').read_bytes())['ApplicationProperties']
    for key in ['SigningIdentity', 'Team']:
        assert current[key] == previous[key], (key, current[key], previous[key])
    report['matching_signing_identity'] = current['SigningIdentity']
    report['team'] = current['Team']
    executable = app / 'Contents/MacOS/NanaFlow'
    report['executable_sha256'] = hashlib.sha256(executable.read_bytes()).hexdigest()
    report['architecture'] = subprocess.check_output(['lipo', '-archs', str(executable)], text=True).strip()
    assert set(report['architecture'].split()) == {'arm64', 'x86_64'}
    report['export'] = {'package': str(args.package), 'signatures': []}
    for bundle in [args.export_app, args.export_app / 'Contents/PlugIns/NanaFlowWidget.appex']:
        subprocess.run(['codesign', '--verify', '--strict', str(bundle)], check=True)
        signature = subprocess.check_output(['codesign', '-dvv', str(bundle)], stderr=subprocess.STDOUT, text=True)
        assert 'Authority=Apple Distribution: Nio D (LTLULSL8A2)' in signature
        report['export']['signatures'].append(signature)
    report['export']['package_signature'] = subprocess.check_output(['pkgutil', '--check-signature', str(args.package)], text=True)
    report['export']['package_bytes'] = args.package.stat().st_size
    report['export']['package_sha256'] = hashlib.sha256(args.package.read_bytes()).hexdigest()
    args.output.write_text(json.dumps(report, indent=2))
    print('Archive app + Widget: 1.0.2 (5), strict signatures valid; signing identity and Team match 1.0.1.')
    print('Executable SHA256:', report['executable_sha256'])
    print('Export app + Widget: Apple Distribution / LTLULSL8A2; signed local package:', args.package)


if __name__ == '__main__':
    main()
