#!/usr/bin/env python3
"""Remove only the two disposable release identities, never the shipping ID."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
IDENTITIES = ['com.nanafox.NanaFlow.Screenshots', 'com.nanafox.NanaFlow.ReleaseTests']
LSREGISTER = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'


def main():
    processes = subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True)
    apps = [
        ROOT / 'build/release-1.0.2/screenshots/DerivedData/Build/Products/Release/NanaFlowScreenshots.app',
        ROOT / 'build/release-1.0.2/isolated-tests/DerivedData/Build/Products/Debug/NanaFlow.app',
    ]
    for app in apps:
        if any(str(app / 'Contents/MacOS') in row for row in processes.splitlines()):
            raise SystemExit(f'Disposable host still running; no cleanup attempted: {app}')
        if app.exists():
            subprocess.run([LSREGISTER, '-u', str(app)], check=True)
            widget = app / 'Contents/PlugIns/NanaFlowWidget.appex'
            if widget.exists():
                subprocess.run(['pluginkit', '-r', str(widget)], check=True)
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


if __name__ == '__main__':
    main()
