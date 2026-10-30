#!/usr/bin/env python3
"""Read-only private digest of stable production preferences/history and installed app."""
import hashlib,json,pathlib,plistlib,sys
home=pathlib.Path.home(); paths=[home/'Library/Preferences/com.nanafox.NanaFlow.plist',home/'Library/Preferences/group.com.nanafox.NanaFlow.plist',home/'Library/Containers/com.nanafox.NanaFlow/Data/Library/Preferences/com.nanafox.NanaFlow.plist']
paths+=list((home/'Library/Group Containers').glob('group.com.nanafox.NanaFlow/Library/Preferences/*.plist'))
rows={}
for path in paths:
 if path.exists():
  d=plistlib.loads(path.read_bytes())
  rows[str(path)]={k:hashlib.sha256(plistlib.dumps({'value':v},sort_keys=True)).hexdigest() for k,v in d.items() if k in ('timerPreferences.v1','focusSessions.v1','sessionTags.v1','welcome.hasBeenShown','welcome.showAtLaunch')}
exe=pathlib.Path('/Applications/NanaFlow.app/Contents/MacOS/NanaFlow')
if exe.exists(): rows['installedExecutableSHA256']=hashlib.sha256(exe.read_bytes()).hexdigest()
out=pathlib.Path(sys.argv[1]);out.write_text(json.dumps(rows,indent=2));out.chmod(0o600)
print(f'Private stable production digest saved ({len(rows)} entries); no values printed.')
