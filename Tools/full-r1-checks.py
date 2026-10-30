#!/usr/bin/env python3
"""Auditable CLT checks; no UI launch, installation, XCTest emulation or test edits.

Exit 0 means this evidence run completed and every runnable check passed. It does
not mean XCTest/Xcode analyze/system acceptance passed. See results.json.
"""

import argparse
import datetime
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time


ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = ROOT / "build/r1-completion/full-checks"
LOCAL_TESTS = ["MenuBarAndJumpTests.swift", "R1BehaviorTests.swift"]
CLT = "/Library/Developer/CommandLineTools"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", default=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.run):
        parser.error("--run must contain only letters, digits, underscores and hyphens")
    stage = BASE / args.run
    stage.mkdir(parents=True, exist_ok=False)
    snapshot = stage / "snapshot"
    snapshot.mkdir()
    commands, adaptations = [], []
    report = {
        "schemaVersion": 1, "startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "stage": str(stage), "commands": commands, "adaptations": adaptations,
        "invocation": [sys.executable, str(pathlib.Path(__file__).resolve())] + sys.argv[1:],
        "effectiveDeveloperDirectory": CLT,
        "scope": "Current-source CLT checks only; not complete XCTest, Xcode analyze or product acceptance",
        "safety": {"launchApps": False, "installApps": False, "productionPreferences": False,
                   "systemSettings": False, "existingTestsEdited": False, "fakeXCTestAPI": False},
    }

    def save():
        (stage / "results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")

    def run(label, argv, kind="check", env=None, timeout=600, cwd=ROOT):
        command = [str(x) for x in argv]
        overrides = {**(env or {}), "DEVELOPER_DIR": CLT}
        log = stage / (label + ".log")
        record = {"label": label, "argv": command, "cwd": str(cwd), "kind": kind,
                  "log": str(log.relative_to(stage)), "environmentOverrides": overrides}
        commands.append(record)
        save()
        started = time.monotonic()
        try:
            with log.open("w") as output:
                result = subprocess.run(command, cwd=cwd, env={**os.environ, **overrides},
                                        stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
            record["exitCode"] = result.returncode
        except subprocess.TimeoutExpired:
            record.update(exitCode=124, timedOut=True)
        except OSError as error:
            log.write_text(str(error) + "\n")
            record.update(exitCode=127, launchError=str(error))
        record.update(seconds=round(time.monotonic() - started, 3), logSHA256=digest(log))
        save()
        print(f'{label}: exit {record["exitCode"]} ({record["seconds"]}s)', flush=True)
        return record

    input_paths = set()
    for folder in ("Sources", "Tests", "Tools"):
        input_paths.update(p for p in (ROOT / folder).rglob("*") if p.is_file())
    input_paths.update([ROOT / "project.yml", ROOT / "NanaFlow.xcodeproj/project.pbxproj"])
    input_paths.update(p for p in (ROOT / "NanaFlow.xcodeproj/xcshareddata").rglob("*") if p.is_file())
    input_paths.update((ROOT / "References/acceptance-2026-10-26-r1").glob("*fixture*.json"))
    # Explicit input allow-list avoids collecting unrelated build trees or private settings.
    input_paths = sorted(p for p in input_paths if p.suffix != ".pyc" and "__pycache__" not in p.parts)
    report["inputs"] = {str(p.relative_to(ROOT)): digest(p) for p in input_paths}
    for path in input_paths:
        dest = snapshot / path.relative_to(ROOT)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
    report["snapshotMatchesInputs"] = all(digest(snapshot / name) == value for name, value in report["inputs"].items())
    tests = sorted((snapshot / "Tests/NanaFocusTests").glob("*.swift"))
    inventory = []
    for path in tests:
        methods = re.findall(r"\bfunc\s+(test\w+)\s*\(", path.read_text())
        inventory.append({"file": str(path.relative_to(snapshot)), "methods": methods,
                          "methodCount": len(methods), "sha256": digest(path),
                          "execution": "shared body executed by CLT runner" if path.name in LOCAL_TESTS else "blocked: XCTest module/runner unavailable"})
    report["testInventory"] = inventory
    report["testMethodCount"] = sum(x["methodCount"] for x in inventory)
    report["xctestMethodsExecuted"] = 0
    report["sharedBodiesRequested"] = LOCAL_TESTS
    save()

    run("git-head", ["git", "rev-parse", "HEAD"], "evidence")
    run("git-status", ["git", "status", "--short"], "evidence")
    run("developer-directory", ["xcode-select", "-p"], "evidence")
    run("swift-version", ["xcrun", "swiftc", "--version"], "evidence")
    sdk_record = run("sdk-path", ["xcrun", "--show-sdk-path"], "evidence")
    if sdk_record["exitCode"]:
        report["runError"] = "Cannot resolve SDK"
        save()
        return 1
    sdk = pathlib.Path((stage / "sdk-path.log").read_text().strip())
    report["sdkSettings"] = json.loads((sdk / "SDKSettings.json").read_text())
    report["xcodeAppsInApplications"] = [str(p) for p in pathlib.Path("/Applications").glob("*Xcode*.app")]
    run("xcode-metadata-search", ["mdfind", 'kMDItemCFBundleIdentifier == "com.apple.dt.Xcode"'], "evidence")
    run("signing-identities", ["security", "find-identity", "-v", "-p", "codesigning"], "evidence")
    run("xcode-version", ["xcodebuild", "-version"], "capability-probe")
    run("xctest-runner", ["xcrun", "--find", "xctest"], "capability-probe")
    run("xcode-test", ["xcodebuild", "test", "-project", "NanaFlow.xcodeproj", "-scheme", "NanaFlow",
                       "-destination", "platform=macOS", "-derivedDataPath", stage / "DerivedData",
                       "CODE_SIGNING_ALLOWED=NO"], "capability-probe")
    run("xcode-release-analyze", ["xcodebuild", "analyze", "-project", "NanaFlow.xcodeproj", "-scheme", "NanaFlow",
                                 "-configuration", "Release", "-destination", "generic/platform=macOS",
                                 "-derivedDataPath", stage / "AnalyzeData", "CODE_SIGNING_ALLOWED=NO"], "capability-probe")

    empty = stage / "empty.modulemap"
    empty.write_text("")
    overlay = stage / "toolchain-overlay.json"
    overlay.write_text(json.dumps({"version": 0, "roots": [{"type": "file", "name": "/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap", "external-contents": str(empty)}]}))
    adaptations.append({"scope": "compiler invocation", "reason": "CLT duplicate SwiftBridging modulemap", "detail": "VFS overlay hides only the duplicate CLT usr/include/swift/module.modulemap; no framework or assertion API is fabricated"})
    flags = ["xcrun", "swiftc", "-swift-version", "6", "-sdk", str(sdk), "-target", "arm64-apple-macos15.0",
             "-module-cache-path", str(stage / "ModuleCache"), "-vfsoverlay", str(overlay)]
    xctest_probe = stage / "XCTestProbe.swift"
    xctest_probe.write_text("import XCTest\nfinal class CapabilityProbe: XCTestCase {}\n")
    run("xctest-module", flags + ["-typecheck", xctest_probe], "capability-probe")
    testing_probe = stage / "TestingProbe.swift"
    testing_probe.write_text("import Testing\n@Test func capabilityProbe() { #expect(1 == 1) }\n")
    framework_dir = pathlib.Path("/Library/Developer/CommandLineTools/Library/Developer/Frameworks")
    run("swift-testing-module", flags + ["-F", framework_dir, "-typecheck", testing_probe], "capability-probe")
    xctest_overlay = pathlib.Path("/Library/Developer/CommandLineTools/usr/lib/swift-5.0/macosx/libswiftXCTest.dylib")
    if xctest_overlay.exists():
        run("legacy-xctest-overlay-dependencies", ["otool", "-L", xctest_overlay], "evidence")
    report["developerFrameworks"] = [str(p) for p in framework_dir.glob("*")]
    report["xctestFrameworkPresent"] = (framework_dir / "XCTest.framework").exists()
    run("tests-parse", ["xcrun", "swiftc", "-frontend", "-parse"] + flags[2:] + tests)

    app = sorted((snapshot / "Sources/NanaFocus").glob("*.swift")) + sorted((snapshot / "Sources/NanaShared").glob("*.swift"))
    widget = sorted((snapshot / "Sources/NanaFlowWidget").glob("*.swift")) + sorted((snapshot / "Sources/NanaShared").glob("*.swift"))
    report["sourceCounts"] = {"appAndShared": len(app), "widgetAndShared": len(widget)}
    run("app-original-release-typecheck", flags + ["-O", "-whole-module-optimization", "-warnings-as-errors", "-typecheck", "-module-name", "NanaFlow"] + app, "capability-probe")
    run("widget-original-release-typecheck", flags + ["-O", "-whole-module-optimization", "-warnings-as-errors", "-typecheck", "-module-name", "NanaFlowWidget"] + widget, "capability-probe")

    compat = stage / "compat"
    for module in ("NanaFocus", "NanaShared", "NanaFlowWidget"):
        for original in sorted((snapshot / "Sources" / module).glob("*.swift")):
            text = original.read_text()

            def replace(old, new, reason, expected=1):
                nonlocal text
                count = text.count(old)
                if count != expected:
                    raise ValueError(f"Unexpected source structure {original.name}: {reason}: {count} != {expected}")
                text = text.replace(old, new)
                adaptations.append({"file": str(original.relative_to(snapshot)), "reason": reason, "matches": count, "old": old, "new": new})

            if "import EventKit" in text:
                replace("import EventKit", "@preconcurrency import EventKit", "SDK15 EventKit concurrency annotation compatibility")
            if original.name in ("PermissionViews.swift", "SessionNotificationScheduler.swift"):
                replace("import UserNotifications", "@preconcurrency import UserNotifications", "SDK15 UserNotifications concurrency annotation compatibility")
            if original.name == "NanaFlowWidgetBundle.swift":
                replace('        if #available(macOS 26.0, *) {\n            IconControlWidget()\n        }\n', "", "SDK15 cannot typecheck macOS26 ControlWidget bundle branch")
            if original.name == "NanaFlowWidgets.swift":
                marker = "@available(macOS 26.0, *)"
                if text.count(marker) != 1:
                    raise ValueError("ControlWidget boundary changed")
                omitted = text[text.index(marker):]
                text = text[:text.index(marker)]
                adaptations.append({"file": str(original.relative_to(snapshot)), "reason": "SDK15 lacks macOS26 ControlWidget APIs; omit only explicitly marked declaration", "omittedSHA256": hashlib.sha256(omitted.encode()).hexdigest(), "omittedLines": len(omitted.splitlines())})
            dest = compat / module / original.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(text)
    compatible_app = sorted((compat / "NanaFocus").glob("*.swift")) + sorted((compat / "NanaShared").glob("*.swift"))
    compatible_widget = sorted((compat / "NanaFlowWidget").glob("*.swift")) + sorted((compat / "NanaShared").glob("*.swift"))
    run("app-clt-release-typecheck", flags + ["-O", "-whole-module-optimization", "-warnings-as-errors", "-typecheck", "-module-name", "NanaFlow"] + compatible_app)
    run("widget-clt-release-typecheck", flags + ["-O", "-whole-module-optimization", "-warnings-as-errors", "-typecheck", "-module-name", "NanaFlowWidget"] + compatible_widget)

    # Separate runner source set: tests remain byte-identical to the snapshot.
    # Isolate fallback defaults and shared defaults even if a future test omits injection.
    runner_sources = []
    suite = "NanaFlow.FullR1Checks." + args.run
    for source in compatible_app:
        text = source.read_text()
        if source.name in ("TimerPersistence.swift", "TimerPreferences.swift", "SessionHistory.swift", "SessionTags.swift"):
            old = "UserDefaults = .standard"
            if text.count(old) != 1:
                raise ValueError(f"Defaults boundary changed in {source.name}")
            text = text.replace(old, f'UserDefaults = UserDefaults(suiteName: "{suite}")!')
            adaptations.append({"scope": "runner only", "file": source.name, "reason": "fallback persistence uses isolated suite", "matches": 1})
        if source.name == "NanaFlowShared.swift":
            old = '"group.com.nanafox.NanaFlow"'
            if text.count(old) != 1:
                raise ValueError("Shared defaults boundary changed")
            text = text.replace(old, f'"{suite}.shared"')
            adaptations.append({"scope": "runner only", "file": source.name, "reason": "isolate app-group defaults", "matches": 1})
        if source.name == "NanaFocusApp.swift":
            if text.count("@main\n") != 1:
                raise ValueError("App entry point changed")
            text = text.replace("@main\n", "")
            adaptations.append({"scope": "runner only", "file": source.name, "reason": "remove application entry point so no App is started", "matches": 1})
        dest = stage / "runner-sources" / source.parent.name / source.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text)
        runner_sources.append(dest)
    entry = stage / "FullR1Main.swift"
    entry.write_text('''import Foundation
@main struct FullR1Main {
    @MainActor static func main() async throws {
        try MenuBarAndJumpChecks.run()
        print("PASS MenuBarAndJumpChecks (original test body)")
        try await R1BehaviorChecks.run()
        print("PASS R1BehaviorChecks (original test body)")
    }
}
''')
    original_tests = [ROOT / "Tests/NanaFocusTests" / name for name in LOCAL_TESTS]
    if any(digest(path) != report["inputs"][str(path.relative_to(ROOT))] for path in original_tests):
        raise ValueError("Original tests changed after snapshot; rerun against current source")
    home = stage / "isolated-home"
    (home / "Library/Preferences").mkdir(parents=True)
    overrides = {"HOME": str(home), "CFFIXED_USER_HOME": str(home)}
    report["runnerIsolation"] = {"suite": suite, "environment": overrides,
                                 "notifications": "injected spies/controlled submission only", "appEntrypoint": "removed from runner copy"}
    for configuration, optimization in [("debug", ["-Onone"]), ("release", ["-O", "-whole-module-optimization"])]:
        executable = stage / ("shared-checks-" + configuration)
        compiled = run("shared-checks-" + configuration + "-compile", flags + optimization + ["-warnings-as-errors", "-D", "NANAFLOW_LOCAL_CHECKS", "-module-name", "NanaFlow", "-o", executable] + runner_sources + original_tests + [entry])
        if compiled["exitCode"] == 0:
            run("shared-checks-" + configuration + "-run", [executable], env=overrides, timeout=120)

    run("r1-resources", [sys.executable, ROOT / "Tools/check-r1-resources.py"])
    plist_inputs = [snapshot / "NanaFlow.xcodeproj/project.pbxproj"]
    plist_inputs += [p for p in (snapshot / "Sources").rglob("*") if p.suffix in (".plist", ".entitlements", ".strings", ".stringsdict")]
    run("all-property-lists", ["plutil", "-lint"] + sorted(plist_inputs))
    report["propertyListCount"] = len(plist_inputs)
    project_record = run("xcode-project-json", ["plutil", "-convert", "json", "-o", "-", snapshot / "NanaFlow.xcodeproj/project.pbxproj"])
    membership_checks = []
    if project_record["exitCode"] == 0:
        objects = json.loads((stage / "xcode-project-json.log").read_text())["objects"]
        for target in objects.values():
            if target.get("isa") != "PBXNativeTarget":
                continue
            name = target["name"]
            if name not in ("NanaFlow", "NanaFlowTests", "NanaFlowWidget"):
                continue
            actual = []
            for phase_id in target["buildPhases"]:
                phase = objects[phase_id]
                if phase["isa"] == "PBXSourcesBuildPhase":
                    for build_id in phase["files"]:
                        ref = objects[objects[build_id]["fileRef"]]
                        actual.append(pathlib.Path(ref["path"]).name)
            expected = [p.name for p in ({"NanaFlow": app, "NanaFlowWidget": widget, "NanaFlowTests": tests}[name])]
            membership_checks.append({"target": name, "expected": sorted(expected), "actual": sorted(actual), "matches": sorted(actual) == sorted(expected)})
    report["projectSourceMembership"] = membership_checks
    report["projectSourceMembershipPassed"] = len(membership_checks) == 3 and all(x["matches"] for x in membership_checks)
    report["sourceDrift"] = [name for name, value in report["inputs"].items() if not (ROOT / name).exists() or digest(ROOT / name) != value]
    report["generatedSHA256"] = {str(p.relative_to(stage)): digest(p) for folder in ("compat", "runner-sources") for p in sorted((stage / folder).rglob("*.swift"))}
    report["generatedSHA256"].update({str(p.relative_to(stage)): digest(p) for p in (entry, empty, overlay, xctest_probe, testing_probe)})
    report["executables"] = {p.name: digest(p) for p in stage.glob("shared-checks-*") if p.is_file() and p.suffix != ".log"}
    report["allRunnableChecksPassed"] = all(x["exitCode"] == 0 for x in commands if x["kind"] == "check") and not report["sourceDrift"] and report["projectSourceMembershipPassed"]
    report["sharedBodiesExecuted"] = len(LOCAL_TESTS) if all(any(c["label"] == f"shared-checks-{config}-run" and c["exitCode"] == 0 for c in commands) for config in ("debug", "release")) else 0
    report["uncovered"] = [
        "All 216 XCTest test methods: no XCTest module/framework/runner; 2 shared bodies run separately, never counted as XCTest execution",
        "Xcode Release analyze: complete Xcode unavailable; Swift optimized typecheck is a different check",
        "macOS26 ControlWidget declaration and registration: SDK15.5 lacks APIs; omitted only in explicit CLT Widget copy",
        "XCTest assertions in other 214 methods including UI/rendering/resource contracts: not executed or translated",
        "Native UI, real system notification delivery/audio, install, entitlements/iCloud and signing: outside this worker scope",
    ]
    report["finishedUTC"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
    lines = ["# Current-source CLT full-check evidence", "", report["scope"], "",
             f'- Input files: {len(report["inputs"])}; test files: {len(inventory)}; discovered test methods: {report["testMethodCount"]}.',
             f'- XCTest methods executed: 0; shared original bodies executed in both Debug and optimized Release: {report["sharedBodiesExecuted"]}.',
             f'- All runnable checks passed: {report["allRunnableChecksPassed"]}; source drift: {report["sourceDrift"]}.', "",
             "| Command | Kind | Exit | Log |", "| --- | --- | ---: | --- |"]
    lines += [f'| {c["label"]} | {c["kind"]} | {c["exitCode"]} | [{c["log"]}]({c["log"]}) |' for c in commands]
    lines += ["", "## Uncovered", ""] + ["- " + x for x in report["uncovered"]]
    lines += ["", "Exact argv, input hashes, generated-source hashes, adaptations, log hashes, timings and SDK settings are in [results.json](results.json).", ""]
    (stage / "REPORT.md").write_text("\n".join(lines))
    print(stage, flush=True)
    return 0 if report["allRunnableChecksPassed"] else 1


if __name__ == "__main__":
    sys.exit(main())
