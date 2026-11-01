# NanaFlow App Store submission pack

This directory contains the localized store copy and release records. It distinguishes the published version from the update under review.

## Current status — 2026-11-01

- **Published:** version 1.0 is available on the [Mac App Store](https://apps.apple.com/app/nanaflow/id6814738160).
- **Submitted update:** 1.0.1 (4), waiting for App Review. Apple has processed and verified the uploaded binary. The existing update was submitted once on November 1; no duplicate version or upload was created.
- **Release control:** automatically release after approval, immediately to users, retaining existing ratings. Approval and public availability are still pending.
- **Source:** the 1.0.1 application changes are commit `2e637935106101ea4719722fbfa702e1783734ca`.

## Files

- [`metadata.zh-Hans.md`](metadata.zh-Hans.md) and [`metadata.en-US.md`](metadata.en-US.md): saved localized copy and 1.0.1 release notes.
- [`review-notes-1.0.1.txt`](review-notes-1.0.1.txt): the current reviewer access instructions.
- [`review-notes.md`](review-notes.md): historical 1.0 note templates; not the submitted 1.0.1 note.
- [`screenshots.md`](screenshots.md): the original screenshot register. Existing build-2 captures are retained; they are not new 1.0.1 captures.
- [`privacy-questionnaire.md`](privacy-questionnaire.md): data-handling scope and historical privacy checks.
- [`upload-checklist.md`](upload-checklist.md): current update checks followed by the historical first-release checklist.
- [`validate_metadata.py`](validate_metadata.py): localized field-length validation.

## Store scope

The store app provides focus and break timers, pause/resume/skip/reset, optional automatic starts, same-window D/W/M/Y statistics, menu-bar controls, notifications, completion sounds and keyboard shortcuts. The submitted 1.0.1 update adds a count/net-focus-time selector and separate focus/break sound choices.

Session data and settings stay on the Mac. History-list browsing and backup/import have no reachable store UI entry point and must not be advertised as available features. Do not import the public Beta's Calendar, iCloud, blocker, tag UI, mini timer or Pro scope. Only English and Simplified Chinese ship.

The existing Widget extension remains; no new Widget imagery or freshly passed host-refresh claim is included in this update.

## Current evidence and limits

The update passed 186 affected product checks plus one background-isolation check, Release build/analyze, universal signed archive verification, and Apple upload/processing validation. Final App/Widget effective entitlements were read back from App Store Connect and match the minimal sandbox/App Group/user-selected-file scope.

After a fresh private backup and live UI baseline, the exact signed Release archive candidate was installed locally and launched normally without a debugger. Its first launch and normal quit/relaunch preserved the visible timer, round, statistics and supported settings. Window edges, About version/build and the native Window menu were checked.

This is a development-signed Release archive test, not an App Store/TestFlight-downloaded variant. TestFlight channel installation was not covered by this update’s runtime checks. Real preferences/history were not semantically decoded through the CLI, and full historical UUID-set equality was not audited. Notification actions, Widget pixel refresh and actual sound audibility remain deferred. These are not recorded as passed.

## First-release history

Build 1.0.0 (2) passed its original test, signing, TestFlight and submission steps in September 2026; version 1.0 subsequently became publicly available. Those older checks do not establish fresh 1.0.1 runtime results. The checklist and asset register retain their source build labels.

Run before copying localized fields into App Store Connect:

```sh
python3 AppStore/validate_metadata.py
```
