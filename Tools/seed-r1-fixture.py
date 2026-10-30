#!/usr/bin/env python3
"""Seed ONLY the R1 review identity, while its app is stopped. Never a production domain."""
import argparse,json,pathlib,plistlib,subprocess
R=pathlib.Path(__file__).resolve().parents[1];domain='com.nanafox.NanaFlow.R1Review'
p=argparse.ArgumentParser();p.add_argument('--mode',choices=['fixture','short-timer','standard'],default='fixture');p.add_argument('--appearance',choices=['light','dark','system'],default='light');p.add_argument('--phase',choices=['focus','shortBreak','longBreak'],default='focus');a=p.parse_args()
active=subprocess.check_output(['ps','-A','-o','comm='],text=True)
assert not any('/build/r1/' in x and x.endswith('/Contents/MacOS/NanaFlowR1Review') for x in active.splitlines()),'Quit the R1 candidate first'
r=subprocess.run(['defaults','export',domain,'-'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
data=plistlib.loads(r.stdout) if r.returncode==0 else {}
prefs=json.loads(data.get('timerPreferences.v1',b'{"autoStartFocus":false,"autoStartBreaks":false,"notificationSoundEnabled":true}'))
prefs.update(appearance=a.appearance,hideWindowWhenTimerStarts=False,startTimerOnLaunch=False,resetCycleOnLaunch=False,autoStartFocus=False,autoStartBreaks=False,timerSyncEnabled=False,calendarSyncEnabled=False)
if a.mode=='short-timer':prefs.update(notificationsEnabled=False)
data['timerPreferences.v1']=json.dumps(prefs).encode()
duration=3 if a.mode=='short-timer' else 1500
engine={'configuration':{'focusDuration':duration,'shortBreakDuration':300,'longBreakDuration':1800,'sessionsPerCycle':4},'state':{'phase':a.phase,'cycleIndex':3 if a.phase=='longBreak' else 0,'remainingWhenPaused':duration if a.phase=='focus' else 300 if a.phase=='shortBreak' else 1800,'interruptions':[]}}
data['timerEngine.v1']=json.dumps(engine).encode();data['welcome.hasBeenShown']=True;data['welcome.showAtLaunch']=False
if a.mode=='fixture':data['focusSessions.v1']=(R/'References/acceptance-2026-10-26-r1/sessions-fixture.json').read_bytes()
if a.mode=='short-timer':data['focusSessions.v1']=b'[]'
out=R/'build/r1/candidate-test-domain.plist';out.write_bytes(plistlib.dumps(data))
subprocess.run(['defaults','import',domain,str(out)],check=True,stdout=subprocess.DEVNULL)
print(f'Seeded {domain}: {a.mode}, {a.appearance}; no production/shared/iCloud domain touched.')
