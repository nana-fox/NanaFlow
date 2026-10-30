#!/usr/bin/env python3
"""Prepare an isolated, current-source Xcode test project; never install it.

The original source/entitlement contracts remain available to source-based tests.
Only the compiled shared suite, test host bundle identity and launch registrations
are adapted. Release analysis does not launch or provision an app.
"""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DESKTOP_UNIT_TESTS = [
    'NanaFlowTests/ProUnlockedParityTests/testNativeProWindowMatchesFlowOuterFrame',
    'NanaFlowTests/ViewRenderingTests/testHideTimerWindowLeavesVisibleAuxiliaryWindowAlone',
    'NanaFlowTests/ViewRenderingTests/testSettingsVolumeControlRendersAtFlowsCompactRowSize',
    'NanaFlowTests/ViewRenderingTests/testCycleCelebrationRendersWhiteParticlesOverTheLongBreak',
    'NanaFlowTests/ViewRenderingTests/testWelcomeNativeWindowBlendsTitlebarWithoutChangingContentLayout',
    'NanaFlowTests/ViewRenderingTests/testFullscreenBreakUsesDedicatedWindowInsteadOfMutatingMainWindow',
    'NanaFlowTests/ViewRenderingTests/testMainToolbarVisualRendersAtFlowSize',
    'NanaFlowTests/ViewRenderingTests/testMainTimerRenders',
    'NanaFlowTests/ViewRenderingTests/testRunningFocusUsesAccentPauseIconAndStableCyclePill',
    'NanaFlowTests/ViewRenderingTests/testLongBreakKeepsLocalizedTitleAndSharedBreakBackground',
]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--stage', required=True)
parser.add_argument('--developer-dir', type=Path)
parser.add_argument('--derived-data', type=Path)
parser.add_argument('--run', choices=['test', 'desktop-test', 'ui-test', 'analyze'])
parser.add_argument('--prepare-only', action='store_true',
                    help='Generate the selected run mode for review without executing Xcode.')
parser.add_argument('--allow-desktop-ui', action='store_true',
                    help='Explicitly allow pointer/window tests in an available test desktop.')
args = parser.parse_args()
if args.run in ('desktop-test', 'ui-test') and not args.prepare_only and not args.allow_desktop_ui:
    parser.error('Native UI tests use the desktop. Use a dedicated test desktop and --allow-desktop-ui; unit tests and analysis run in the background.')
if not args.stage.replace('-', '').isalnum():
    parser.error('Use a simple fresh stage name.')
stage = ROOT / 'build/r1-completion' / args.stage
if stage.exists():
    parser.error('Stage exists; choose a new name.')
project = stage / 'project'
project.mkdir(parents=True)
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
manifest = {'schemaVersion': 1, 'sourceRoot': str(ROOT), 'inputs': {},
            'adaptations': [], 'commands': [], 'result': 'prepared_not_executed',
            'toolSHA256': digest(Path(__file__)), 'requestedRunMode': args.run}
for folder in ['Sources', 'Tests', 'NanaFlow.xcodeproj']:
    for source in sorted((ROOT / folder).rglob('*')):
        if not source.is_file() or 'xcuserdata' in source.parts:
            continue
        relative = source.relative_to(ROOT)
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        manifest['inputs'][str(relative)] = digest(source)
for relative in [Path('References/acceptance-2026-10-26-r1/sessions-fixture.json')]:
    source = ROOT / relative
    target = project / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    manifest['inputs'][str(relative)] = digest(source)

shared = project / 'Sources/NanaShared/NanaFlowShared.swift'
text = shared.read_text()
old = 'static let suiteName = "group.com.nanafox.NanaFlow"'
assert text.count(old) == 1
shared.write_text(text.replace(old, 'static let suiteName = "group.com.nanafox.NanaFlow.R1XCTest"'))
manifest['adaptations'].append('Compiled shared suite uses R1XCTest; production domain is never used.')

if args.run == 'test':
    compiled_sources = project / 'R1UnitHostSources'
    shutil.copytree(project / 'Sources', compiled_sources)
    app_source = compiled_sources / 'NanaFocus/NanaFocusApp.swift'
    source = app_source.read_text()
    source = source.replace('.windowResizability(.contentSize)',
                            '.defaultLaunchBehavior(.suppressed)\n        .windowResizability(.contentSize)')
    app_source.write_text(source)
    delegate_source = compiled_sources / 'NanaFocus/SessionNotificationScheduler.swift'
    source = delegate_source.read_text()
    marker = '    func applicationDidFinishLaunching(_: Notification) {'
    assert source.count(marker) == 1
    source = source.replace(marker, '''
    func applicationWillFinishLaunching(_: Notification) {
        NSApplication.shared.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_: Notification) {
        if Bundle.main.bundleIdentifier == "com.nanafox.NanaFlow.R1XCTest" {
            print("R1_HEADLESS_START active=\\(NSApplication.shared.isActive) visibleWindows=\\(NSApplication.shared.windows.filter { $0.isVisible }.count) policy=\\(NSApplication.shared.activationPolicy().rawValue)")
            return
        }
''')
    # Keep ordinary delegate declarations compiled without starting its live
    # status item, cloud synchronization, shortcut registration or UI bootstrap.
    marker = '    func applicationWillTerminate(_: Notification) {'
    assert source.count(marker) == 1
    source = source.replace(marker, marker + '\n        print("R1_HEADLESS_END active=\\(NSApplication.shared.isActive) visibleWindows=\\(NSApplication.shared.windows.filter { $0.isVisible }.count) policy=\\(NSApplication.shared.activationPolicy().rawValue)")')
    delegate_source.write_text(source)
    for path in compiled_sources.rglob('*.swift'):
        source = path.read_text()
        source = re.sub(r'\b(?:NSApplication\.shared|NSApp)\.activate\([^)]*\)',
                        '/* Unit host forbids foreground activation. */ ()', source)
        path.write_text(source)
    for name, marker in [
        ('AppWindowActivation.swift', '    static func bringToFront(title: String, miniaturizable: Bool? = nil) {'),
        ('FullscreenBreakView.swift', '    func show(controller: TimerController, manuallyTriggered: Bool = false) {'),
        ('ProUnlockedView.swift', '    func show() {'),
    ]:
        path = compiled_sources / 'NanaFocus' / name
        source = path.read_text()
        assert source.count(marker) == 1
        path.write_text(source.replace(marker, marker + '\n        if Bundle.main.bundleIdentifier == "com.nanafox.NanaFlow.R1XCTest" { return }'))
    # Source-contract tests continue reading the untouched shipping snapshot.
    # Only the Xcode source groups below point to the isolated unit-host copy.
    shutil.copytree(ROOT / 'Sources', project / 'Sources', dirs_exist_ok=True)
    manifest['adaptations'].append('Background unit host uses a separate compiled-source copy: all scene launches suppressed, activation prohibited, both activate overloads disabled, live app-delegate startup bypassed and known show/bringToFront routes guarded; source-contract tests read the untouched shipping snapshot. Desktop and TimerView lifecycle tests are excluded. No native UI acceptance is inferred.')

if args.run == 'ui-test':
    drag = project / 'Sources/NanaFocus/WindowDragSurface.swift'
    source = drag.read_text()
    for old, new in [
        ('            window.makeKeyAndOrderFront(nil)',
         '            window.makeKeyAndOrderFront(nil); traceDrag("down", event)'),
        ('            window.setFrameOrigin(Self.origin(start: startOrigin, anchor: startPoint, point: point))',
         '            window.setFrameOrigin(Self.origin(start: startOrigin, anchor: startPoint, point: point)); traceDrag("drag", event)'),
        ('        override func mouseUp(with event: NSEvent) {',
         '        override func mouseUp(with event: NSEvent) {\n            traceDrag("up", event)'),
        ('        override var isFlipped: Bool { true }',
         '        override var isFlipped: Bool { true }\n        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); traceDrag("attached", nil) }\n        override func layout() { super.layout(); traceDrag("layout", nil) }'),
        ('        override func hitTest(_ point: NSPoint) -> NSView? {',
         '        override func hitTest(_ point: NSPoint) -> NSView? {\n            traceDrag("hit", nil, hitPoint: point)'),
    ]:
        assert source.count(old) == 1
        source = source.replace(old, new)
    helper = '''
        private func traceDrag(_ kind: String, _ event: NSEvent?, hitPoint: NSPoint? = nil) {
            guard let window else { return }
            let pointer = NSEvent.mouseLocation
            let quartz = event?.cgEvent?.location
            var row: [String: Any] = ["event": kind, "windowX": window.frame.minX,
                "windowY": window.frame.minY, "width": window.frame.width,
                "height": window.frame.height, "pointerX": pointer.x, "pointerY": pointer.y,
                "quartzX": quartz?.x ?? -99999, "quartzY": quartz?.y ?? -99999,
                "eventX": event?.locationInWindow.x ?? -99999, "eventY": event?.locationInWindow.y ?? -99999,
                "viewX": frame.minX, "viewY": frame.minY,
                "viewWidth": frame.width, "viewHeight": frame.height]
            if let hitPoint {
                let local = convert(hitPoint, from: superview)
                row["inputX"] = hitPoint.x; row["inputY"] = hitPoint.y
                row["localX"] = local.x; row["localY"] = local.y
                row["inBounds"] = bounds.contains(local)
                row["inRegion"] = regions.contains { $0.contains(local) }
            }
            let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(DRAG_TRACE_NAME)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            guard let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]),
                  let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.write(contentsOf: Data([10]))
        }
'''.replace('DRAG_TRACE_NAME', json.dumps('r1-drag-' + args.stage + '.jsonl'))
    assert source.count('        static func origin(start:') == 1
    drag.write_text(source.replace('        static func origin(start:', helper + '        static func origin(start:'))
    manifest['adaptations'].append('Disposable UI host records drag input coordinates and window geometry; shipping source is unchanged by this diagnostic.')

    # Seed through the test app's own preference API, before its controller loads.
    # External `defaults import` can report the desired data while the launched
    # macOS app still reads a cached empty value. This is UI fixture setup only;
    # it makes no upgrade, sandbox migration or cross-process cache claim.
    controller = project / 'Sources/NanaFocus/TimerController.swift'
    source = controller.read_text()
    marker = '    static let shared = TimerController()'
    assert source.count(marker) == 1
    fixture = '''    static let shared: TimerController = {
        precondition(Bundle.main.bundleIdentifier == "com.nanafox.NanaFlow.R1XCTest")
        let defaults = UserDefaults.standard
        var preferences = TimerPreferences.standard
        preferences.autoStartFocus = false
        preferences.autoStartBreaks = false
        preferences.notificationSoundEnabled = false
        preferences.notificationsEnabled = false
        preferences.tickingSoundEnabled = false
        preferences.calendarSyncEnabled = false
        preferences.timerSyncEnabled = false
        preferences.showWindowOnLaunch = true
        preferences.hideWindowWhenTimerStarts = false
        preferences.startTimerOnLaunch = false
        preferences.resetCycleOnLaunch = false
        preferences.fullscreenBreaks = false
        preferences.globalHotkeysEnabled = false
        let now = Date()
        let sessions = [90.0, 60.0].enumerated().map { index, duration in
            let end = now.addingTimeInterval(-Double(index + 1) * 5)
            return FocusSession(id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!,
                startedAt: end.addingTimeInterval(-duration), endedAt: end, duration: duration,
                completed: true, title: "Synthetic R1 native UI fixture", type: .focus)
        }
        do {
            try TimerPreferencesPersistence(defaults: defaults).save(preferences)
            try TimerPersistence(defaults: defaults).save(TimerEngine(configuration: .standard))
            try SessionHistoryPersistence(defaults: defaults).save(sessions)
            defaults.set(true, forKey: "welcome.hasBeenShown")
            defaults.set(false, forKey: "welcome.showAtLaunch")
            let controller = TimerController()
            precondition(controller.sessions == sessions.sorted { $0.endedAt > $1.endedAt })
            print("R1_UI_FIXTURE ownerAPI=true loadedCount=2 seconds=150")
            return controller
        } catch {
            preconditionFailure("Isolated native UI fixture could not be saved")
        }
    }()'''
    controller.write_text(source.replace(marker, fixture))
    manifest['adaptations'].append('Native UI fixture is written by the isolated app through real persistence APIs before constructing its controller, then checked against the actual loaded records. Exactly two current synthetic completed focus records total 150 seconds; original native UI test source and assertions are unchanged. No production data, migration or cache acceptance is inferred.')

# Keep the original Info.plist for contract tests, while building a separate
# launch-registration-free copy for the test host.
info = plistlib.loads((project / 'Sources/NanaFocus/Info.plist').read_bytes())
if args.run == 'test':
    info['LSUIElement'] = True
for key in ['CFBundleURLTypes', 'NSAppleScriptEnabled', 'OSAScriptingDefinition']:
    info.pop(key, None)
(project / 'R1TestHost-Info.plist').write_bytes(plistlib.dumps(info))
pbx = project / 'NanaFlow.xcodeproj/project.pbxproj'
text = pbx.read_text()
for original, isolated in [
    ('com.nanafox.NanaFlow.Widget', 'com.nanafox.NanaFlow.R1XCTest.Widget'),
    ('com.nanafox.NanaFlowTests', 'com.nanafox.NanaFlow.R1XCTest.Tests'),
    ('com.nanafox.NanaFlow;', 'com.nanafox.NanaFlow.R1XCTest;'),
]:
    assert original in text
    text = text.replace(original, isolated)
text = text.replace('INFOPLIST_FILE = Sources/NanaFocus/Info.plist;',
                    'INFOPLIST_FILE = "R1TestHost-Info.plist";')
pbx.write_text(text)
manifest['adaptations'].append('Main, Widget and XCTest bundle identifiers isolated; App product name and test host path preserved.')
manifest['adaptations'].append('Test-host Info.plist excludes production URL and scripting registrations; source contract plist unchanged.')

# Wire a real XCUITest target in the disposable project, without changing the
# shipping project's targets or requiring a third-party project generator.
graph = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(pbx)]))
objects = graph['objects']
if args.run in ('desktop-test', 'ui-test'):
    for value in objects.values():
        if value.get('isa') == 'XCBuildConfiguration':
            settings = value.get('buildSettings', {})
            settings.pop('CODE_SIGN_ENTITLEMENTS', None)
            if 'ENABLE_APP_SANDBOX' in settings:
                settings['ENABLE_APP_SANDBOX'] = 'NO'
    manifest['adaptations'].append('Disposable desktop hosts omit restricted signing entitlements and sandboxing for local ad-hoc UI testing; shipping project and entitlement files remain unchanged. These runs do not validate signed system capabilities.')
if args.run == 'test':
    for value in objects.values():
        if value.get('isa') == 'PBXGroup' and value.get('path', '').startswith('Sources/'):
            value['path'] = value['path'].replace('Sources/', 'R1UnitHostSources/', 1)
ids = {name: f'C1261026B0000000000000{index:02X}' for index, name in enumerate(
    ['target', 'product', 'file', 'buildfile', 'sources', 'frameworks',
     'resources', 'configlist', 'debug', 'release', 'dependency', 'proxy'], 1)}
assert not any(key in objects for key in ids.values())
app_target = 'F5A71727D1AA94E59C942E13'
project_id = graph['rootObject']
objects[ids['product']] = {'isa': 'PBXFileReference', 'explicitFileType': 'wrapper.cfbundle',
                           'includeInIndex': '0', 'path': 'NanaFlowAcceptanceUITests.xctest',
                           'sourceTree': 'BUILT_PRODUCTS_DIR'}
objects[ids['file']] = {'isa': 'PBXFileReference', 'lastKnownFileType': 'sourcecode.swift',
                        'path': 'Tests/NanaFlowAcceptanceUITests/NativeAcceptanceTests.swift',
                        'sourceTree': 'SOURCE_ROOT'}
objects[ids['buildfile']] = {'isa': 'PBXBuildFile', 'fileRef': ids['file']}
for phase in ['sources', 'frameworks', 'resources']:
    objects[ids[phase]] = {'isa': {'sources': 'PBXSourcesBuildPhase',
        'frameworks': 'PBXFrameworksBuildPhase', 'resources': 'PBXResourcesBuildPhase'}[phase],
        'buildActionMask': '2147483647', 'runOnlyForDeploymentPostprocessing': '0',
        'files': [ids['buildfile']] if phase == 'sources' else []}
for configuration in ['debug', 'release']:
    objects[ids[configuration]] = {'isa': 'XCBuildConfiguration',
        'name': configuration.title(), 'buildSettings': {
            'PRODUCT_NAME': '$(TARGET_NAME)', 'GENERATE_INFOPLIST_FILE': 'YES',
            'PRODUCT_BUNDLE_IDENTIFIER': 'com.nanafox.NanaFlow.R1XCTest.UITests',
            'SDKROOT': 'macosx', 'MACOSX_DEPLOYMENT_TARGET': '15.0',
            'SWIFT_VERSION': '5.0', 'TEST_TARGET_NAME': 'NanaFlow',
            'CODE_SIGN_STYLE': 'Automatic'}}
objects[ids['configlist']] = {'isa': 'XCConfigurationList',
    'buildConfigurations': [ids['debug'], ids['release']],
    'defaultConfigurationIsVisible': '0', 'defaultConfigurationName': 'Release'}
objects[ids['proxy']] = {'isa': 'PBXContainerItemProxy', 'containerPortal': project_id,
    'proxyType': '1', 'remoteGlobalIDString': app_target, 'remoteInfo': 'NanaFlow'}
objects[ids['dependency']] = {'isa': 'PBXTargetDependency', 'target': app_target,
                             'targetProxy': ids['proxy']}
objects[ids['target']] = {'isa': 'PBXNativeTarget', 'name': 'NanaFlowAcceptanceUITests',
    'productName': 'NanaFlowAcceptanceUITests', 'productType': 'com.apple.product-type.bundle.ui-testing',
    'productReference': ids['product'], 'buildConfigurationList': ids['configlist'],
    'buildPhases': [ids[x] for x in ['sources', 'frameworks', 'resources']],
    'buildRules': [], 'dependencies': [ids['dependency']]}
root_object = objects[project_id]
root_object['targets'].append(ids['target'])
root_object['attributes'].setdefault('TargetAttributes', {})[ids['target']] = {
    'TestTargetID': app_target, 'CreatedOnToolsVersion': '16.0'}
objects[root_object['mainGroup']]['children'].append(ids['file'])
objects[root_object['productRefGroup']]['children'].append(ids['product'])
if args.run == 'test':
    check_path = project / 'R1BackgroundHostChecks.swift'
    check_path.write_text('''import AppKit
import XCTest

@MainActor
final class ZBackgroundIsolationTests: XCTestCase {
    func testUnitHostEndsInactiveWithoutVisibleWindows() {
        let application = NSApplication.shared
        let visibleWindows = application.windows.filter { $0.isVisible }.count
        print("R1_HEADLESS_VERIFIED active=\\(application.isActive) visibleWindows=\\(visibleWindows) policy=\\(application.activationPolicy().rawValue)")
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.nanafox.NanaFlow.R1XCTest")
        XCTAssertEqual(application.activationPolicy(), .prohibited)
        XCTAssertFalse(application.isActive)
        XCTAssertEqual(visibleWindows, 0)
    }
}
''')
    file_id, build_id = 'C1261026C000000000000001', 'C1261026C000000000000002'
    assert file_id not in objects and build_id not in objects
    objects[file_id] = {'isa': 'PBXFileReference', 'lastKnownFileType': 'sourcecode.swift',
                        'path': check_path.name, 'sourceTree': 'SOURCE_ROOT'}
    objects[build_id] = {'isa': 'PBXBuildFile', 'fileRef': file_id}
    objects[root_object['mainGroup']]['children'].append(file_id)
    unit_target = next(value for value in objects.values()
                       if value.get('isa') == 'PBXNativeTarget' and value.get('name') == 'NanaFlowTests')
    phase = next(objects[key] for key in unit_target['buildPhases']
                 if objects[key].get('isa') == 'PBXSourcesBuildPhase')
    phase['files'].append(build_id)
    manifest['adaptations'].append('One extra real XCTest checks background isolation after the product suite: inactive app, prohibited activation policy and zero visible windows. It is counted separately from product tests.')
pbx.write_bytes(plistlib.dumps(graph))
scheme = project / 'NanaFlow.xcodeproj/xcshareddata/xcschemes/NanaFlow.xcscheme'
tree = ET.parse(scheme)
reference_attributes = {'BuildableIdentifier': 'primary', 'BlueprintIdentifier': ids['target'],
    'BuildableName': 'NanaFlowAcceptanceUITests.xctest', 'BlueprintName': 'NanaFlowAcceptanceUITests',
    'ReferencedContainer': 'container:NanaFlow.xcodeproj'}
entry = ET.SubElement(tree.find('./BuildAction/BuildActionEntries'), 'BuildActionEntry', {
    'buildForTesting': 'YES', 'buildForRunning': 'NO', 'buildForProfiling': 'NO',
    'buildForArchiving': 'NO', 'buildForAnalyzing': 'NO'})
ET.SubElement(entry, 'BuildableReference', reference_attributes)
testable = ET.SubElement(tree.find('./TestAction/Testables'), 'TestableReference', {
    'skipped': 'NO', 'parallelizable': 'NO'})
ET.SubElement(testable, 'BuildableReference', reference_attributes)
tree.write(scheme, encoding='UTF-8', xml_declaration=True)
manifest['adaptations'].append('Disposable XCUITest target added for real native hover and drag; shipping project unchanged.')
manifest['generatedInputs'] = {
    str(path.relative_to(project)): digest(path)
    for path in sorted(project.rglob('*')) if path.is_file()
}

if args.run and not args.prepare_only:
    developer = args.developer_dir
    if not developer or not (developer / 'usr/bin/xcodebuild').is_file():
        manifest['result'] = 'blocked_missing_full_xcode'
        manifest['blockingCondition'] = 'Pass --developer-dir pointing to Xcode.app/Contents/Developer; CLT is insufficient.'
    else:
        derived = (args.derived_data or (stage / 'DerivedData')).resolve()
        action = 'test' if args.run in ('desktop-test', 'ui-test') else args.run
        if action == 'test':
            # Unit and native UI hosts deliberately share a disposable identity.
            # Serialize seed, launch and teardown across all invocations.
            test_lock = (ROOT / 'build/r1-completion/xcode-test.lock').open('a')
            fcntl.flock(test_lock, fcntl.LOCK_EX)
            manifest['testExecution'] = 'serialized_with_exclusive_test_identity_lock'
        command = [str(developer / 'usr/bin/xcodebuild'), '-project', str(pbx.parent),
                   '-scheme', 'NanaFlow', '-configuration',
                   'Debug' if action == 'test' else 'Release',
                   '-destination', 'platform=macOS', '-derivedDataPath', str(derived),
                   '-resultBundlePath', str(stage / (args.run + '.xcresult'))]
        if args.run in ('desktop-test', 'ui-test'):
            command.extend(['CODE_SIGNING_ALLOWED=YES', 'CODE_SIGNING_REQUIRED=NO',
                            'CODE_SIGN_IDENTITY=-', 'DEVELOPMENT_TEAM='])
            manifest['adaptations'].append('Native UI runner and disposable Debug host use local ad-hoc signatures; no developer credential or restricted entitlement is granted.')
        else:
            command.extend(['CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO'])
        if action == 'test':
            command.extend(['-testLanguage', 'zh-Hans', '-testRegion', 'CN',
                            '-parallel-testing-enabled', 'NO',
                            '-test-timeouts-enabled', 'YES',
                            '-default-test-execution-time-allowance', '60',
                            '-maximum-test-execution-time-allowance', '90',
                            'DEBUG_INFORMATION_FORMAT=dwarf-with-dsym'])
            manifest['adaptations'].append('Tests explicitly use zh-Hans/CN for existing localized-copy assertions; serial execution, timeouts and dSYM enable reproducible failure diagnostics.')
            command.append(('-only-testing:' if args.run == 'ui-test' else '-skip-testing:')
                           + 'NanaFlowAcceptanceUITests')
            if args.run == 'test':
                command.extend('-skip-testing:' + test for test in DESKTOP_UNIT_TESTS)
                manifest['excludedDesktopUnitTests'] = DESKTOP_UNIT_TESTS
                manifest['backgroundLimit'] = 'Six known window-presenting tests and four TimerView lifecycle rendering tests are preserved but excluded from this batch; the final zero-window sample is not proof of every instant of execution.'
            elif args.run == 'desktop-test':
                command.extend('-only-testing:' + test for test in DESKTOP_UNIT_TESTS)
                manifest['selectedDesktopUnitTests'] = DESKTOP_UNIT_TESTS
                manifest['desktopLimit'] = 'Only the ten original desktop/lifecycle tests omitted from the background batch are selected. Run exclusively in a dedicated test desktop.'
            # This domain belongs exclusively to this disposable test host.
            prefs = {'timerPreferences.v1': json.dumps({'autoStartFocus': False,
                'autoStartBreaks': False, 'notificationSoundEnabled': False,
                'notificationsEnabled': False,
                'timerSyncEnabled': False, 'calendarSyncEnabled': False,
                'showWindowOnLaunch': True, 'hideWindowWhenTimerStarts': False,
                'startTimerOnLaunch': False, 'appearance': 'light'}).encode(),
                'welcome.hasBeenShown': True, 'welcome.showAtLaunch': False,
                'timerEngine.v1': json.dumps({'configuration': {'focusDuration': 1500,
                    'shortBreakDuration': 300, 'longBreakDuration': 1800, 'sessionsPerCycle': 4},
                    'state': {'phase': 'focus', 'cycleIndex': 0,
                              'remainingWhenPaused': 1500, 'interruptions': []}}).encode(),
                'focusSessions.v1': b'[]'}
            if args.run == 'ui-test':
                now = datetime.datetime.now(datetime.timezone.utc).timestamp() - 978307200
                sessions = []
                for index, duration in enumerate([90, 60], 1):
                    end = now - index * 5
                    sessions.append({'id': f'00000000-0000-4000-8000-{index:012d}',
                        'startedAt': end - duration, 'endedAt': end, 'duration': duration,
                        'completed': True, 'title': 'Synthetic R1 native UI fixture',
                        'type': 'focus', 'interruptions': []})
                prefs['focusSessions.v1'] = json.dumps(sessions).encode()
            seed = stage / 'test-domain.plist'
            seed.write_bytes(plistlib.dumps(prefs))
            if args.run != 'ui-test':
                subprocess.run(['defaults', 'import', 'com.nanafox.NanaFlow.R1XCTest', str(seed)], check=True)
                container_preferences = Path.home() / 'Library/Containers/com.nanafox.NanaFlow.R1XCTest/Data/Library/Preferences'
                container_preferences.mkdir(parents=True, exist_ok=True)
                subprocess.run(['defaults', 'import', str(container_preferences / 'com.nanafox.NanaFlow.R1XCTest'), str(seed)], check=True)
            manifest['seed'] = {'domain': 'com.nanafox.NanaFlow.R1XCTest',
                                'path': str(seed), 'sha256': digest(seed),
                                'method': 'app_owned_persistence' if args.run == 'ui-test' else 'external_disposable_domains'}
            if args.run == 'ui-test':
                manifest['adaptations'].append('Saved UI fixture definition only; no external regular/container preference write. The isolated UI app seeds current dates through its own persistence before loading. Notifications/cloud/calendar are disabled.')
            else:
                manifest['adaptations'].append('Seeded only disposable R1XCTest regular and sandbox domains; notifications/cloud/calendar disabled; unit and desktop batches use empty history.')
        command.append(action)
        environment = dict(os.environ, DEVELOPER_DIR=str(developer))
        with (stage / (args.run + '.log')).open('w') as log:
            result = subprocess.run(command, cwd=project, env=environment,
                                    stdout=log, stderr=subprocess.STDOUT)
        manifest['commands'].append({'argv': command, 'exitCode': result.returncode,
                                     'logSHA256': digest(stage / (args.run + '.log'))})
        manifest['result'] = 'passed' if result.returncode == 0 else 'failed'
        manifest['limit'] = 'No developer provisioning, installation, real iCloud, notification delivery or Widget host acceptance is implied.'

(stage / 'manifest.json').write_text(json.dumps(manifest, indent=2))
print(json.dumps({'stage': str(stage), 'result': manifest['result'],
                  'inputFiles': len(manifest['inputs']),
                  'manifest': str(stage / 'manifest.json')}, indent=2))
sys.exit(0 if manifest['result'] in ['prepared_not_executed', 'passed'] else 1)
