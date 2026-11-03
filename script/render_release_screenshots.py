#!/usr/bin/env python3
"""Compile the actual release views into a separate, in-memory demo identity."""
import json
from pathlib import Path
import shutil
import subprocess
from run_isolated_tests import prepare, ROOT

WORK = ROOT / 'build/release-1.0.2/screenshots'
IDENTITY = 'com.nanafox.NanaFlow.Screenshots'


def main():
    spec = prepare(WORK, IDENTITY)
    # Screenshot fixture does not include or register a Widget.
    spec['targets'].pop('NanaFlowTests')
    spec['targets'].pop('NanaFlowWidget')
    app = spec['targets']['NanaFlow']
    app.pop('dependencies')
    app['settings']['base']['PRODUCT_NAME'] = 'NanaFlowScreenshots'
    app['sources'].remove('TestHost.swift')
    app['sources'].append('ReleaseScreenshots.swift')
    shutil.copy2(ROOT / 'script/ReleaseScreenshots.swift', WORK / 'ReleaseScreenshots.swift')
    spec['schemes'] = {'Screenshots': {'build': {'targets': {'NanaFlow': 'all'}}}}
    (WORK / 'project.json').write_text(json.dumps(spec, indent=2))
    subprocess.run([shutil.which('xcodegen') or '/opt/homebrew/bin/xcodegen', 'generate', '--spec', str(WORK / 'project.json')], cwd=WORK, check=True)
    subprocess.run(['xcodebuild', 'build', '-project', str(WORK / 'NanaFlowIsolated.xcodeproj'), '-scheme', 'Screenshots', '-configuration', 'Release', '-derivedDataPath', str(WORK / 'DerivedData')], cwd=WORK, check=True)
    binary = WORK / 'DerivedData/Build/Products/Release/NanaFlowScreenshots.app/Contents/MacOS/NanaFlowScreenshots'
    for locale, language in [('en-US', 'en'), ('zh-Hans', 'zh-Hans')]:
        destination = WORK / locale
        destination.mkdir(exist_ok=True)
        for image in destination.glob('*.png'):
            image.unlink()
        subprocess.run([str(binary), str(WORK / locale), '-AppleLanguages', f'({language})', '-AppleLocale', locale.replace('-', '_')], check=True)
        names = ['01-focus-menu', '02-week-count', '03-month-duration', '04-completion-sounds']
        for name in names:
            image = destination / (name + '.png')
            if not image.exists():
                raise RuntimeError(f'Missing fresh image: {image}')
            target = ROOT / 'AppStore/Screenshots/1.0.2' / locale
            target.mkdir(parents=True, exist_ok=True)
            shutil.copy2(image, target / image.name)
        if locale == 'en-US':
            shutil.copy2(destination / 'A-en-timer-options.png', ROOT / 'Plans/evidence-1.0.2/A-en-timer-options.png')


if __name__ == '__main__':
    main()
