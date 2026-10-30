#!/usr/bin/env python3
"""Verify R1 provenance completeness and hashes; never launch the candidate UI.

--tamper-checks changes only disposable copies of the stage and source inputs.
This is local consistency evidence, not a signed or adversary-proof attestation.
"""
import argparse
import hashlib
import json
import pathlib
import plistlib
import shutil
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = pathlib.Path('NanaFlow R1 Review.app/Contents')
INFO = 'Sources/NanaFocus/Info.plist'
TESTS = {'Tests/NanaFocusTests/MenuBarAndJumpTests.swift', 'Tests/NanaFocusTests/R1BehaviorTests.swift'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def expected_inputs(repo, checks):
    paths = {INFO, 'Tools/build-r1.py', 'Tools/verify-r1-manifest.py'}
    for module in ('NanaFocus', 'NanaShared', 'NanaFlowWidget'):
        paths.update(str(p.relative_to(repo)) for p in (repo / 'Sources' / module).glob('*.swift'))
    for p in (repo / 'Sources/NanaFocus').rglob('*'):
        if p.is_file() and ('.lproj' in str(p) or p.parent.name == 'Sounds' or
                            (p.parent.name == 'NanaFocus' and p.suffix in ('.png', '.icns', '.html', '.txt'))):
            paths.add(str(p.relative_to(repo)))
    paths.update(str(p.relative_to(repo)) for p in (repo / 'Sources/NanaFocus/TimerIcons.xcassets').rglob('*') if p.is_file())
    if checks:
        paths.update(TESTS)
        paths.update(str(p.relative_to(repo)) for p in (repo / 'References/acceptance-2026-10-26-r1').glob('*fixture*.json'))
    return paths


def verify(stage, repo, require_checks=False):
    manifest = json.loads((stage / 'manifest.json').read_text())
    require(manifest.get('schemaVersion') == 2, 'Manifest schema 2 required')
    require(type(manifest.get('checksRequested')) is bool, 'Missing checksRequested')
    checks = manifest['checksRequested']
    require(not require_checks or checks, 'Executed shared checks required')

    def table(name, base, expected):
        entries = manifest.get(name, {})
        require(set(entries) == expected,
                f'{name} incomplete: missing={sorted(expected - set(entries))}, unexpected={sorted(set(entries) - expected)}')
        for name, digest in entries.items():
            path = base / name
            require(path.is_file() and sha(path) == digest, f'Hash mismatch: {name}')

    table('inputs', repo, expected_inputs(repo, checks))
    require(manifest.get('builderSHA256') == sha(repo / 'Tools/build-r1.py'), 'Builder hash mismatch')
    generated = {str(p.relative_to(stage)) for p in (stage / 'compat').rglob('*.swift')}
    table('generated', stage, generated)
    app_sources = {str(p.relative_to(stage)) for module in ('NanaFocus', 'NanaShared')
                   for p in (stage / 'compat' / module).glob('*.swift')}
    table('appGeneratedInputs', stage, app_sources)
    resources = {str(p.relative_to(stage / APP / 'Resources'))
                 for p in (stage / APP / 'Resources').rglob('*') if p.is_file()}
    table('resources', stage / APP / 'Resources', resources)

    final_info = manifest.get('finalInfoPlist', {})
    require(final_info.get('path') == str(APP / 'Info.plist'), 'Missing final Info.plist record')
    require(final_info.get('sha256') == sha(stage / APP / 'Info.plist'), 'Final Info.plist hash mismatch')
    info = plistlib.loads((repo / INFO).read_bytes())
    for key in ('CFBundleURLTypes', 'NSAppleScriptEnabled', 'OSAScriptingDefinition'):
        info.pop(key, None)
    info.update(CFBundleIdentifier='com.nanafox.NanaFlow.R1Review', CFBundleDisplayName='NanaFlow R1 Review',
                CFBundleExecutable='NanaFlowR1Review', CFBundleName='NanaFlow R1 Review',
                CFBundleDevelopmentRegion='en', LSMinimumSystemVersion='15.0')
    require(plistlib.loads((stage / APP / 'Info.plist').read_bytes()) == info, 'Final/source Info.plist metadata mismatch')
    require(manifest.get('executableSHA256') == sha(stage / APP / 'MacOS/NanaFlowR1Review'), 'App binary hash mismatch')

    commands = manifest.get('commands', [])
    results = manifest.get('commandResults', [])
    require(commands and commands == [r['argv'] for r in results], 'Missing command results')
    for result in results:
        require(result['exitCode'] == 0, f'Command failed: {result["log"]}')
        require(result['logSHA256'] == sha(stage / result['log']), f'Log hash mismatch: {result["log"]}')
    original_stage = pathlib.Path(manifest['stageRoot'])

    def compiled_inputs(log, stage_inputs, repo_inputs):
        records = [r for r in results if r['log'] == log]
        require(len(records) == 1, f'Missing compile record: {log}')
        argv = records[0]['argv']
        actual = [x for x in argv if x.endswith('.swift')]
        expected = {str(original_stage / p) for p in stage_inputs} | {str(ROOT / p) for p in repo_inputs}
        # Repo paths in original argv refer to this checkout, even in a tamper copy.
        require(len(actual) == len(expected) and set(actual) == expected, f'Compile inputs incomplete: {log}')
        return argv

    app_argv = compiled_inputs('compile.log', app_sources, set())
    require(app_argv[app_argv.index('-o') + 1] == str(original_stage / APP / 'MacOS/NanaFlowR1Review'), 'App output mismatch')
    if checks:
        runner_sources = (app_sources - {'compat/NanaFocus/NanaFocusApp.swift'}) | {'RegressionApp.swift', 'RegressionMain.swift'}
        table('runnerGeneratedInputs', stage, runner_sources)
        require((stage / 'RegressionApp.swift').read_text() ==
                (stage / 'compat/NanaFocus/NanaFocusApp.swift').read_text().replace('@main\n', ''), 'RegressionApp provenance mismatch')
        main = (stage / 'RegressionMain.swift').read_text()
        require('try MenuBarAndJumpChecks.run()' in main and 'try await R1BehaviorChecks.run()' in main,
                'RegressionMain must invoke both shared checks')
        argv = compiled_inputs('checks-compile.log', runner_sources, TESTS)
        runner = manifest.get('runner', {})
        require(runner.get('path') == 'r1-checks', 'Missing runner binary record')
        require(runner.get('sha256') == sha(stage / 'r1-checks'), 'Runner binary hash mismatch')
        require(argv[argv.index('-o') + 1] == str(original_stage / 'r1-checks'), 'Runner compile output mismatch')
        runs = [r for r in results if r['argv'] == [str(original_stage / 'r1-checks')]]
        require(len(runs) == 1, 'Missing actual runner execution')
        require(type(runner.get('exitCode')) is int and runner['exitCode'] == runs[0]['exitCode'] == 0,
                'Runner exit code must be recorded success')
        require(runner.get('log') == runs[0]['log'] == 'checks-results.log', 'Runner results log mismatch')
        require(runner.get('logSHA256') == sha(stage / 'checks-results.log'), 'Runner results hash mismatch')
        output = (stage / 'checks-results.log').read_text()
        require('PASS MenuBarAndJumpChecks' in output and 'PASS R1BehaviorChecks' in output, 'Missing shared-check results')
    return {'verified': True, 'inputs': len(manifest['inputs']), 'appGeneratedInputs': len(app_sources),
            'runnerGeneratedInputs': len(manifest.get('runnerGeneratedInputs', {})), 'resources': len(resources),
            'runnerExitCode': manifest.get('runner', {}).get('exitCode')}


def tamper_checks(stage, repo):
    require(json.loads((stage / 'manifest.json').read_text())['checksRequested'], 'Tamper checks require a checks build')
    with tempfile.TemporaryDirectory(prefix='nanaflow-r1-manifest-tamper-') as temp:
        base = pathlib.Path(temp)
        copied_stage, copied_repo = base / 'stage', base / 'repo'
        shutil.copytree(stage, copied_stage)
        manifest = json.loads((stage / 'manifest.json').read_text())
        for name in manifest['inputs']:
            dest = copied_repo / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(repo / name, dest)
        verify(copied_stage, copied_repo, True)
        cases = []

        def reject(label, path, change):
            original = path.read_bytes()
            try:
                change(path)
                try:
                    verify(copied_stage, copied_repo, True)
                except (ValueError, KeyError, OSError) as error:
                    cases.append({'case': label, 'rejected': True, 'reason': str(error)})
                else:
                    raise RuntimeError(f'Tamper accepted: {label}')
            finally:
                path.write_bytes(original)

        for label, path in [('source Info.plist', copied_repo / INFO),
                            ('final Info.plist', copied_stage / APP / 'Info.plist'),
                            ('RegressionMain.swift', copied_stage / 'RegressionMain.swift'),
                            ('runner binary', copied_stage / 'r1-checks')]:
            reject(label, path, lambda p: p.write_bytes(p.read_bytes() + b'\nTAMPER\n'))

        def edit_manifest(edit):
            def apply(path):
                value = json.loads(path.read_text())
                edit(value)
                path.write_text(json.dumps(value))
            return apply

        for label, edit in [
            ('omit source Info.plist', lambda m: m['inputs'].pop(INFO)),
            ('omit final Info.plist', lambda m: m.pop('finalInfoPlist')),
            ('omit actual runner entrypoint', lambda m: m['runnerGeneratedInputs'].pop('RegressionMain.swift')),
            ('omit runner binary hash', lambda m: m['runner'].pop('sha256')),
            ('nonzero runner exit', lambda m: m['runner'].update(exitCode=17))]:
            reject(label, copied_stage / 'manifest.json', edit_manifest(edit))
        verify(copied_stage, copied_repo, True)
        return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', required=True, type=pathlib.Path)
    parser.add_argument('--require-checks', action='store_true')
    parser.add_argument('--tamper-checks', action='store_true')
    args = parser.parse_args()
    try:
        result = verify(args.stage.resolve(), ROOT, args.require_checks)
        if args.tamper_checks:
            result['tamperChecks'] = tamper_checks(args.stage.resolve(), ROOT)
    except (ValueError, KeyError, OSError) as error:
        print(json.dumps({'verified': False, 'error': str(error)}, ensure_ascii=False, indent=2))
        raise SystemExit(1)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
