#!/usr/bin/env python3
"""Run every existing XCTest with a disposable app identity and App Group.

The shipping files are copied, not edited; only the @main entry point and
shared suite in that copy change. The minimal host never constructs the live
controller, app delegate, status item or notification scheduler at launch.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'build/release-1.0.2/isolated-tests'
IDENTITY = 'com.nanafox.NanaFlow.ReleaseTests'


def prepare(work=WORK, identity=IDENTITY):
    work.mkdir(parents=True, exist_ok=True)
    for name in ('Sources', 'Tests', 'NanaFlow.xcodeproj', 'script'):
        shutil.copytree(ROOT / name, work / name, dirs_exist_ok=True)
    main = work / 'Sources/NanaFocus/NanaFocusApp.swift'
    main.write_text(main.read_text().replace('@main\n', ''))
    shared = work / 'Sources/NanaShared/NanaFlowShared.swift'
    shared.write_text(shared.read_text().replace('"group.com.nanafox.NanaFlow"', f'"group.{identity}"'))
    (work / 'TestHost.swift').write_text('''import SwiftUI
@main struct IsolatedTestHost: App {
    var body: some Scene { Settings { EmptyView() } }
}
''')
    spec = {
        'name': 'NanaFlowIsolated',
        'options': {'deploymentTarget': {'macOS': '15.0'}},
        'settings': {'base': {'SWIFT_VERSION': '6.0', 'MARKETING_VERSION': '1.0.2', 'CURRENT_PROJECT_VERSION': '5', 'CODE_SIGN_IDENTITY': '-', 'CODE_SIGN_STYLE': 'Manual'}},
        'targets': {
            'NanaFlow': {
                'type': 'application', 'platform': 'macOS',
                'sources': ['Sources/NanaFocus', 'Sources/NanaShared', 'TestHost.swift'],
                'info': {'path': 'IsolatedInfo.plist', 'properties': {'LSUIElement': True, 'CFBundleShortVersionString': '1.0.2', 'CFBundleVersion': '5'}},
                'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': identity, 'PRODUCT_NAME': 'NanaFlow', 'ENABLE_APP_SANDBOX': False, 'CODE_SIGN_ENTITLEMENTS': ''}},
                'dependencies': [{'target': 'NanaFlowWidget'}],
            },
            'NanaFlowWidget': {
                'type': 'app-extension', 'platform': 'macOS',
                'sources': ['Sources/NanaFlowWidget', 'Sources/NanaShared', {'path': 'Sources/NanaFocus', 'includes': ['**/*.lproj/Localizable.strings'], 'buildPhase': 'resources'}],
                'info': {'path': 'IsolatedWidgetInfo.plist', 'properties': {'CFBundleShortVersionString': '1.0.2', 'CFBundleVersion': '5', 'NSExtension': {'NSExtensionPointIdentifier': 'com.apple.widgetkit-extension'}}},
                'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': identity + '.Widget', 'PRODUCT_NAME': 'NanaFlowWidget', 'SKIP_INSTALL': True, 'ENABLE_APP_SANDBOX': False, 'CODE_SIGN_ENTITLEMENTS': ''}},
            },
            'NanaFlowTests': {
                'type': 'bundle.unit-test', 'platform': 'macOS',
                'sources': ['Tests/NanaFocusTests'],
                'dependencies': [{'target': 'NanaFlow'}],
                'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': identity + '.Tests', 'GENERATE_INFOPLIST_FILE': True}},
            },
        },
        'schemes': {'NanaFlowIsolated': {'build': {'targets': {'NanaFlow': 'all', 'NanaFlowTests': ['test']}}, 'test': {'targets': ['NanaFlowTests'], 'gatherCoverageData': True}}},
    }
    (work / 'project.json').write_text(json.dumps(spec, indent=2))
    return spec


def main():
    prepare()
    xcodegen = shutil.which('xcodegen') or '/opt/homebrew/bin/xcodegen'
    subprocess.run([xcodegen, 'generate', '--spec', str(WORK / 'project.json')], cwd=WORK, check=True)
    command = ['xcodebuild', 'test', '-project', str(WORK / 'NanaFlowIsolated.xcodeproj'), '-scheme', 'NanaFlowIsolated', '-destination', 'platform=macOS', '-derivedDataPath', str(WORK / 'DerivedData'), '-parallel-testing-enabled', 'NO', *sys.argv[1:]]
    print('Host identity:', IDENTITY, '; App Group:', 'group.' + IDENTITY, flush=True)
    print('Command:', ' '.join(command), flush=True)
    return subprocess.call(command, cwd=WORK)


if __name__ == '__main__':
    raise SystemExit(main())
