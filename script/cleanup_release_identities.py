#!/usr/bin/env python3
"""Remove only the two disposable release identities, never the shipping ID."""
from pathlib import Path
import json
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
IDENTITIES = ['com.nanafox.NanaFlow.Screenshots', 'com.nanafox.NanaFlow.ReleaseTests']
LSREGISTER = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'


def registrations():
    query = '''import AppKit
import Foundation
var result: [String: String] = [:]
for id in CommandLine.arguments.dropFirst() {
    result[id] = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.path ?? ""
}
print(String(data: try JSONSerialization.data(withJSONObject: result), encoding: .utf8)!)
'''
    return json.loads(subprocess.check_output(['swift', '-e', query, *IDENTITIES], text=True))


def main():
    processes = subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True)
    apps = [
        ROOT / 'build/release-1.0.2/screenshots/DerivedData/Build/Products/Release/NanaFlowScreenshots.app',
        ROOT / 'build/release-1.0.2/isolated-tests/DerivedData/Build/Products/Debug/NanaFlow.app',
    ]
    registered_apps = registrations()
    for app, identity in zip(apps, IDENTITIES):
        if any(str(app / 'Contents/MacOS') in row for row in processes.splitlines()):
            raise SystemExit(f'Disposable host still running; no cleanup attempted: {app}')
        if app.exists():
            info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
            assert info['CFBundleIdentifier'] == identity, info['CFBundleIdentifier']
            registered = registered_apps.get(identity)
            if registered:
                assert registered == str(app), registered
                subprocess.run([LSREGISTER, '-u', str(app)], check=True)
            else:
                print('Exact fixture app already unregistered:', identity)
            widget = app / 'Contents/PlugIns/NanaFlowWidget.appex'
            if widget.exists():
                info = plistlib.loads((widget / 'Contents/Info.plist').read_bytes())
                assert info['CFBundleIdentifier'] == identity + '.Widget', info['CFBundleIdentifier']
                registered = subprocess.run(['pluginkit', '-m', '-A', '-D', '-v', '-i', identity + '.Widget'], capture_output=True, text=True)
                if identity + '.Widget' in registered.stdout:
                    subprocess.run(['pluginkit', '-r', str(widget)], check=True)
                else:
                    print('Exact fixture Widget already unregistered:', identity + '.Widget')
    for identity in IDENTITIES:
        assert identity != 'com.nanafox.NanaFlow'
        for suffix in ['', '.Widget', '.Tests']:
            bundle = identity + suffix
            for relative in [f'Library/Containers/{bundle}', f'Library/Application Scripts/{bundle}', f'Library/Preferences/{bundle}.plist']:
                path = Path.home() / relative
                if path.exists():
                    if path.is_dir():
                        shutil.rmtree(path)
                    else:
                        path.unlink()
                    print('Removed exact fixture path:', path)
                assert not path.exists(), path
        for relative in [f'Library/Group Containers/group.{identity}', f'Library/Preferences/group.{identity}.plist', f'Library/Application Scripts/group.{identity}']:
            path = Path.home() / relative
            if path.exists():
                if path.is_dir():
                    shutil.rmtree(path)
                else:
                    path.unlink()
                print('Removed exact fixture path:', path)
            assert not path.exists(), path
        result = subprocess.run(['pluginkit', '-m', '-A', '-D', '-v', '-i', identity + '.Widget'], capture_output=True, text=True)
        print('Exact Widget registration query:', identity + '.Widget', result.stdout.strip() or '(none)', 'exit', result.returncode)
        if identity + '.Widget' in result.stdout:
            raise SystemExit('Fixture Widget still registered')
    print('Both disposable identities cleaned; production identity was excluded.')
    remaining = registrations()
    print('Exact LaunchServices queries:', json.dumps(remaining, sort_keys=True))
    assert all(not path for path in remaining.values()), remaining
    # Only the disposable screenshot identity: never reset the owner's app or
    # any global privacy database. Window-list capture is not used by the fixture.
    subprocess.run(['tccutil', 'reset', 'ScreenCapture', 'com.nanafox.NanaFlow.Screenshots'], check=True)


if __name__ == '__main__':
    main()
