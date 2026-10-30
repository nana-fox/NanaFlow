#!/usr/bin/env python3
"""Fresh, isolated CLT review build. Never reads/writes production preferences or apps."""
import argparse, hashlib, json, os, pathlib, plistlib, shutil, subprocess, time
R = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(); p.add_argument('--stage', required=True); p.add_argument('--checks', action='store_true'); a = p.parse_args()
assert a.stage.replace('-', '').isalnum()
D = R/'build/r1'/a.stage
assert not D.exists(), f'Use a NEW staging name: {D}'
D.mkdir(parents=True)
manifest = {'schemaVersion':2, 'checksRequested':a.checks, 'stageRoot':str(D), 'baseline': subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(), 'inputs':{}, 'adaptations':[], 'commands':[], 'commandResults':[]}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(argv, log):
    command = [str(x) for x in argv]
    manifest['commands'].append(command)
    with (D/log).open('w') as f: result = subprocess.run(command, cwd=R, stdout=f, stderr=subprocess.STDOUT)
    manifest['commandResults'].append({'argv':command, 'log':log, 'logSHA256':sha(D/log), 'exitCode':result.returncode})
    result.check_returncode()
def replace(s, old, new, label, expected=None):
    n=s.count(old); assert n and (expected is None or n==expected), (label,n,expected)
    manifest['adaptations'].append({'label':label,'matches':n}); return s.replace(old,new)
for module in ('NanaFocus','NanaShared','NanaFlowWidget'):
    dest=D/'compat'/module; dest.mkdir(parents=True)
    for src in sorted((R/'Sources'/module).glob('*.swift')):
        manifest['inputs'][str(src.relative_to(R))]=sha(src)
        s=src.read_text()
        if 'import EventKit' in s: s=replace(s,'import EventKit','@preconcurrency import EventKit',str(src.name)+' SDK15 EventKit',1)
        if src.name in ('PermissionViews.swift','SessionNotificationScheduler.swift'): s=replace(s,'import UserNotifications','@preconcurrency import UserNotifications',src.name+' SDK15 UN non-Sendable callback/request',1)
        if src.name=='NanaFlowShared.swift': s=replace(s,'group.com.nanafox.NanaFlow','group.com.nanafox.NanaFlow.R1Review','isolated shared defaults',1)
        if src.name=='TimerController.swift': s=replace(s,'== "nanaflow"','== "nanaflow-r1-review"','isolated automation parser',1)
        if src.name=='SessionNotificationScheduler.swift': s=replace(s,'"sessionCompletedNotification"','"R1Review.sessionCompletedNotification"','isolated notification request',1)
        if src.name=='TimerView.swift':
            s=replace(s,'Image(controller.engine.state.isRunning ?', 'r1BundledTimerImage(controller.engine.state.isRunning ?', 'CLT PNG dynamic icon',1)
            s=replace(s,'Image("phosphor-', 'r1BundledTimerImage("phosphor-', 'CLT PNG static icons')
            s=replace(s,'Image(Self.assetName)', 'r1BundledTimerImage(Self.assetName)', 'CLT PNG cycle icon',1)
            s+='\nprivate func r1BundledTimerImage(_ name: String) -> Image {\n guard let url = Bundle.main.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: url) else { return Image(systemName: "questionmark.square") }; return Image(nsImage: image)\n}\n'
            s=replace(s,'            configureInitialWindows()','            configureInitialWindows(); R1Geometry.start()', 'temporary geometry diagnostic',1)
        if src.name=='WindowDragSurface.swift':
            trace_path=json.dumps(str(D/'drag-events.jsonl'))
            s=replace(s,'            window.makeKeyAndOrderFront(nil)','            window.makeKeyAndOrderFront(nil); traceDrag("down", event)', 'temporary drag down diagnostic',1)
            s=replace(s,'            window.setFrameOrigin(Self.origin(start: startOrigin, anchor: startPoint, point: point))','            window.setFrameOrigin(Self.origin(start: startOrigin, anchor: startPoint, point: point)); traceDrag("drag", event)', 'temporary drag displacement diagnostic',1)
            s=replace(s,'        override func mouseUp(with event: NSEvent) {','        override func mouseUp(with event: NSEvent) {\n            traceDrag("up", event)', 'temporary drag up diagnostic',1)
            trace='\n        private func traceDrag(_ kind: String, _ event: NSEvent) {\n            guard let window, let point = screenPoint(for: event) else { return }\n            let row: [String:Any] = ["event":kind,"pointX":point.x,"pointY":point.y,"originX":window.frame.origin.x,"originY":window.frame.origin.y,"time":Date().description]\n            let url=URL(fileURLWithPath:DRAG_PATH)\n            if !FileManager.default.fileExists(atPath:url.path) { FileManager.default.createFile(atPath:url.path,contents:nil) }\n            guard let data=try? JSONSerialization.data(withJSONObject:row,options:[.sortedKeys]),let f=try? FileHandle(forWritingTo:url) else { return }; defer { try? f.close() }; _ = try? f.seekToEnd();try? f.write(contentsOf:data);try? f.write(contentsOf:Data([10]))\n        }\n'
            s=replace(s,'        static func origin(start:',trace.replace('DRAG_PATH',trace_path)+'        static func origin(start:', 'temporary drag event trace helper',1)
        # Widget source is recorded/refreshed but deliberately not embedded or registered.
        if src.name=='NanaFlowWidgetBundle.swift': s=replace(s,'        if #available(macOS 26.0, *) {\n            IconControlWidget()\n        }\n','','SDK15 omit Control Widget bundle branch',1)
        if src.name=='NanaFlowWidgets.swift':
            marker='@available(macOS 26.0, *)'; assert s.count(marker)==1
            s=s.split(marker)[0]; manifest['adaptations'].append({'label':'SDK15 omit explicitly marked Control Widget declaration','matches':1})
        (dest/src.name).write_text(s)
# No app group / KVS / production automation registration. Candidate does not embed a Widget.
app=D/'NanaFlow R1 Review.app'; contents=app/'Contents'; res=contents/'Resources'; (contents/'MacOS').mkdir(parents=True); res.mkdir()
sourceInfo=R/'Sources/NanaFocus/Info.plist'
for tool in (pathlib.Path(__file__), R/'Tools/verify-r1-manifest.py'):
    manifest['inputs'][str(tool.relative_to(R))]=sha(tool)
manifest['inputs'][str(sourceInfo.relative_to(R))]=sha(sourceInfo)
info=plistlib.loads(sourceInfo.read_bytes())
for k in ('CFBundleURLTypes','NSAppleScriptEnabled','OSAScriptingDefinition'): info.pop(k,None)
info.update(CFBundleIdentifier='com.nanafox.NanaFlow.R1Review',CFBundleDisplayName='NanaFlow R1 Review',CFBundleExecutable='NanaFlowR1Review',CFBundleName='NanaFlow R1 Review',CFBundleDevelopmentRegion='en',LSMinimumSystemVersion='15.0')
(contents/'Info.plist').write_bytes(plistlib.dumps(info))
manifest['finalInfoPlist']={'path':str((contents/'Info.plist').relative_to(D)), 'sha256':sha(contents/'Info.plist')}
for src in sorted((R/'Sources/NanaFocus').rglob('*')):
    if src.is_file() and ('.lproj' in str(src) or src.parent.name=='Sounds' or (src.parent.name=='NanaFocus' and src.suffix in ('.png','.icns','.html','.txt'))):
        manifest['inputs'][str(src.relative_to(R))]=sha(src)
        rel=src.relative_to(R/'Sources/NanaFocus') if '.lproj' in str(src) else pathlib.Path(src.name)
        dst=res/rel; dst.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(src,dst)
        if src.name=='InfoPlist.strings':
            localizedInfo=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(src)]))
            for key in ('CFBundleName','CFBundleDisplayName'): localizedInfo[key]='NanaFlow R1 Review'
            dst.write_bytes(plistlib.dumps(localizedInfo))
            manifest['adaptations'].append({'label':str(src.relative_to(R))+' isolated localized display name','matches':2})
# Convert fresh SVGs without actool; no reuse of old PNGs.
convert=D/'ConvertIcons.swift'
convert.write_text('import AppKit\nlet input = URL(fileURLWithPath: CommandLine.arguments[1]); let output = URL(fileURLWithPath: CommandLine.arguments[2])\nfor folder in try FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil) where folder.pathExtension == "imageset" { let name = folder.deletingPathExtension().lastPathComponent; let url = folder.appendingPathComponent(name + ".svg"); guard let image = NSImage(contentsOf: url), let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data:tiff), let png = bitmap.representation(using:.png,properties:[:]) else { fatalError("Cannot convert \\(url)") }; try png.write(to:output.appendingPathComponent(name + ".png")) }\n')
for src in (R/'Sources/NanaFocus/TimerIcons.xcassets').rglob('*'):
    if src.is_file(): manifest['inputs'][str(src.relative_to(R))]=sha(src)
empty=D/'empty.modulemap';empty.write_text('')
overlay=D/'toolchain-overlay.json';overlay.write_text(json.dumps({'version':0,'roots':[{'type':'file','name':'/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap','external-contents':str(empty)}]}))
sdk=subprocess.check_output(['xcrun','--show-sdk-path'],text=True).strip()
flags=['xcrun','swiftc','-swift-version','6','-sdk',sdk,'-target','arm64-apple-macos15.0','-module-cache-path',str(R/'build/r1/ModuleCache'),'-vfsoverlay',str(overlay)]
run(flags+[convert,'-o',D/'convert-icons'],'icons-compile.log');run([D/'convert-icons',R/'Sources/NanaFocus/TimerIcons.xcassets',res],'icons.log')
geometry=D/'compat/NanaFocus/R1Geometry.swift'
geometry.write_text('''import AppKit
@MainActor enum R1Geometry {
 static var timer: Timer?
 static func start() {
  guard timer == nil else { return }
  snapshot("appear")
  timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in Task { @MainActor in snapshot("settled") } }
 }
 static func snapshot(_ event: String) {
  func tree(_ v: NSView, _ depth: Int = 0) -> [[String: String]] {
   guard depth < 7 else { return [] }
   return [["class":String(describing:type(of:v)),"bounds":NSStringFromRect(v.bounds),"frame":NSStringFromRect(v.frame),"safeArea":String(describing:v.safeAreaInsets),"windowRect":NSStringFromRect(v.convert(v.bounds,to:nil))]] + v.subviews.flatMap { tree($0,depth+1) }
  }
  let rows: [[String: Any]] = NSApp.windows.filter { $0.title == "NanaFlow" }.map { w in ["event":event,"time":Date().description,"frame":NSStringFromRect(w.frame),"contentLayoutRect":NSStringFromRect(w.contentLayoutRect),"styleMask":w.styleMask.rawValue,"isMovable":w.isMovable,"backgroundDrag":w.isMovableByWindowBackground,"canBecomeKey":w.canBecomeKey,"isKeyWindow":w.isKeyWindow,"isVisible":w.isVisible,"windowNumber":w.windowNumber,"type":String(describing:type(of:w)),"views":w.contentView.map { tree($0) } ?? []] }
  guard let data = try? JSONSerialization.data(withJSONObject:rows, options:[.sortedKeys]), let f = try? FileHandle(forWritingTo:URL(fileURLWithPath:GEOMETRY_PATH)) else { return }
  defer { try? f.close() }; _ = try? f.seekToEnd(); try? f.write(contentsOf:data); try? f.write(contentsOf:Data([10]))
 }
}
'''.replace('GEOMETRY_PATH',json.dumps(str(D/'geometry.jsonl'))))
(D/'geometry.jsonl').touch()
sources=sorted((D/'compat/NanaFocus').glob('*.swift'))+sorted((D/'compat/NanaShared').glob('*.swift'))
try:
    run(flags+['-module-name','NanaFlow','-o',contents/'MacOS/NanaFlowR1Review']+sources,'compile.log')
    run(['codesign','--force','--sign','-',app],'sign.log');run(['codesign','--verify','--deep','--strict','--verbose=2',app],'signature-verify.log')
    run(['codesign','-d','--entitlements',':-',app],'signed-entitlements.log')
    manifest['appGeneratedInputs']={str(x.relative_to(D)):sha(x) for x in sources}
    actualEntitlements=(D/'signed-entitlements.log').read_text()
    assert '<plist' not in actualEntitlements, 'Candidate unexpectedly has entitlements'
    assert 'com.apple.developer.ubiquity' not in actualEntitlements and 'application-groups' not in actualEntitlements
    manifest['executableSHA256']=sha(contents/'MacOS/NanaFlowR1Review')
    manifest['sdkVersion']=json.loads((pathlib.Path(sdk)/'SDKSettings.json').read_text())['Version']
    manifest['toolchain']=subprocess.check_output(['xcrun','swiftc','--version'],text=True);manifest['sdk']=sdk
    manifest['identity']={'bundleID':info['CFBundleIdentifier'],'sharedSuite':'group.com.nanafox.NanaFlow.R1Review','URLTypes':info.get('CFBundleURLTypes',[]),'scripting':False,'widgetEmbedded':False,'entitlements':{},'KVS':False}
    assert not (contents/'PlugIns').exists(); assert 'group.com.nanafox.NanaFlow"' not in (D/'compat/NanaShared/NanaFlowShared.swift').read_text()
    manifest['resources']={str(x.relative_to(res)):sha(x) for x in sorted(res.rglob('*')) if x.is_file()}
    for sound in ('alarmClock','bell','bells','bowl','chime','chord','harp','milestone','pulse','ripple','whistle'):
        for suffix in ('','-v1','-v2','-v3'): assert (res/f'NanaFlow-{sound}{suffix}.aiff').is_file()
    if a.checks:
        appsource=D/'compat/NanaFocus/NanaFocusApp.swift';runnerApp=D/'RegressionApp.swift';runnerApp.write_text(replace(appsource.read_text(),'@main\n','', 'current App without entrypoint',1))
        runnerSources=[x for x in sources if x != appsource]+[runnerApp]
        tests=[R/'Tests/NanaFocusTests/MenuBarAndJumpTests.swift',R/'Tests/NanaFocusTests/R1BehaviorTests.swift']
        for f in (R/'References/acceptance-2026-10-26-r1').glob('*fixture*.json'): manifest['inputs'][str(f.relative_to(R))]=sha(f)
        for t in tests: manifest['inputs'][str(t.relative_to(R))]=sha(t)
        main=D/'RegressionMain.swift';main.write_text('import Foundation\n@main struct R1Main { @MainActor static func main() async throws { try MenuBarAndJumpChecks.run(); print("PASS MenuBarAndJumpChecks"); try await R1BehaviorChecks.run(); print("PASS R1BehaviorChecks") } }\n')
        manifest['runnerGeneratedInputs']={str(x.relative_to(D)):sha(x) for x in runnerSources+[main]}
        run(flags+['-D','NANAFLOW_LOCAL_CHECKS','-module-name','NanaFlow','-o',D/'r1-checks']+runnerSources+tests+[main],'checks-compile.log')
        manifest['runner']={'path':'r1-checks', 'sha256':sha(D/'r1-checks'), 'exitCode':None, 'log':'checks-results.log'}
        try:
            run([D/'r1-checks'],'checks-results.log')
        finally:
            if manifest['commandResults'][-1]['argv']==[str(D/'r1-checks')]:
                manifest['runner']['exitCode']=manifest['commandResults'][-1]['exitCode']
                manifest['runner']['logSHA256']=sha(D/'checks-results.log')
finally:
    manifest['builderSHA256']=sha(pathlib.Path(__file__))
    manifest['generated']={str(x.relative_to(D)):sha(x) for x in sorted((D/'compat').rglob('*.swift'))}
    (D/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(app)
subprocess.run(['python3',str(R/'Tools/verify-r1-manifest.py'),'--stage',str(D)] + (['--require-checks'] if a.checks else []),cwd=R,check=True)
