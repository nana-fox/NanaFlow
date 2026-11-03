# NanaFlow App Store submission pack

This directory contains the localized store copy and release records. It distinguishes the published version from the update under review.

## Current status — checked 2026-11-02

- **Published:** version 1.0.1 is visible on both the Chinese and U.S. [Mac App Store](https://apps.apple.com/app/nanaflow/id6814738160) listings, with release date November 2, 2026. The exact build 1.0.1 (4) is ready for distribution in App Store Connect.
- **Submission:** the existing update was submitted once on November 1 and released automatically after approval; no duplicate version, upload or submission was created.
- **Official download:** verified 2026-11-03. The Store-downloaded 1.0.1 (4) carries `_MASReceipt`, is signed by `Apple Mac OS Application Signing`, and its Widget is the only registered copy.
- **Source:** the 1.0.1 application changes are commit `2e637935106101ea4719722fbfa702e1783734ca`.

This is a published update, not a new upload task. Copy housekeeping does not require a new binary or another submission. [Maintenance and next work](../Plans/project-maintenance.md) records the channel boundaries and deferred checks.

## Files

- [`metadata.zh-Hans.md`](metadata.zh-Hans.md) and [`metadata.en-US.md`](metadata.en-US.md): localized copy and 1.0.1 release notes, with the inaccurate global-keyboard-shortcut claim narrowed on November 2. The original submitted versions are preserved in [`history/`](history/1.0.1-submitted-20261101.en-US.md). The correction is prepared for the next editable listing version: the published 1.0.1 description fields are disabled in App Store Connect. It has not been saved to Apple; do not claim otherwise or create a duplicate version to bypass the lock.
- The editable **promotional text** was updated in both languages and read back after reload/locale selection. It describes in-app shortcuts, local data and the released 1.0.1 statistics. This does not remove the older global-shortcut sentence from the locked description; that remaining correction is explicit in the checklist.
- [`review-notes-1.0.1.txt`](review-notes-1.0.1.txt): the current reviewer access instructions.
- [`review-notes.md`](review-notes.md): historical 1.0 note templates; not the submitted 1.0.1 note.
- [`screenshots.md`](screenshots.md): the original screenshot register. Existing build-2 captures are retained; they are not new 1.0.1 captures.
- [`privacy-questionnaire.md`](privacy-questionnaire.md): data-handling scope and historical privacy checks.
- [`upload-checklist.md`](upload-checklist.md): current update checks followed by the historical first-release checklist.
- [`validate_metadata.py`](validate_metadata.py): localized field-length validation.

## Store scope

The store app provides focus and break timers, pause/resume/skip/reset, optional automatic starts, same-window D/W/M/Y statistics, menu-bar controls, notifications, completion sounds and in-app keyboard shortcuts. The submitted 1.0.1 update adds a count/net-focus-time selector and separate focus/break sound choices. Global shortcut code exists but its enablement UI is not reachable for a new store user; it is not advertised as available.

Session data and settings stay on the Mac. History-list browsing and backup/import have no reachable store UI entry point and must not be advertised as available features. Do not import the public Beta's Calendar, iCloud, blocker, tag UI, mini timer or Pro scope. Only English and Simplified Chinese ship.

The existing Widget extension remains; no new Widget imagery or freshly passed host-refresh claim is included in this update.

## Current evidence and limits

The update passed 186 affected product checks plus one background-isolation check, Release build/analyze, universal signed archive verification, and Apple upload/processing validation. Final App/Widget effective entitlements were read back from App Store Connect and match the minimal sandbox/App Group/user-selected-file scope.

After a fresh private backup and live UI baseline, the exact signed Release archive candidate was installed locally and launched normally without a debugger. Its first launch and normal quit/relaunch preserved the visible timer, round, statistics and supported settings. Window edges, About version/build and the native Window menu were checked.

This is a development-signed Release archive test, not an App Store/TestFlight-downloaded variant. TestFlight channel installation was not covered by this update’s runtime checks. Real preferences/history were not semantically decoded through the CLI, and full historical UUID-set equality was not audited. Notification actions, Widget pixel refresh and actual sound audibility remain deferred. These are not recorded as passed.

## November 3 official-download follow-up

The installed Store build 1.0.1 (4) was independently rechecked without quitting or replacing the running app. Both App and Widget pass strict signature verification, Gatekeeper reports `source=Mac App Store`, the Store receipt is present, and there is one main process and one registered official Widget. See the [official-download receipt](official-download-1.0.1.md) for executable digests and the distinction from the earlier development-signed runtime checks. The 1.0.1 acquisition gate is closed; this does not mark the deferred system checks as passed.

## First-release history

Build 1.0.0 (2) passed its original test, signing, TestFlight and submission steps in September 2026; version 1.0 subsequently became publicly available. Those older checks do not establish fresh 1.0.1 runtime results. The checklist and asset register retain their source build labels.

Run before copying localized fields into App Store Connect:

```sh
python3 AppStore/validate_metadata.py
```

## Public copy ownership

The website introduces the product and links to the official store; support pages explain reachable controls and known limitations. The store description covers the timer, menu bar, statistics and local data. Version-specific additions belong in the matching update notes. Do not advertise Beta-only features, inaccessible history/backup screens, guaranteed sound delivery, complete migration coverage or unrestricted source-code licensing.

After the official new-version download is verified, update the version status in the project README, this file, the current checklist and release plan, plus both website home pages (`#release-status`) and support pages (`#updates`). Keep the existing static Pages deployment and verify the live result.
