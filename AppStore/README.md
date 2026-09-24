# NanaFlow 1.0 App Store submission pack

This directory is the copy-ready, evidence-bounded submission pack for the first Mac App Store release.

## Files

- [`metadata.zh-Hans.md`](metadata.zh-Hans.md): Simplified Chinese metadata.
- [`metadata.en-US.md`](metadata.en-US.md): English metadata.
- [`screenshots.md`](screenshots.md): capture plan and localized captions.
- [`review-notes.md`](review-notes.md): App Review notes, including the conditional Widget path.
- [`privacy-questionnaire.md`](privacy-questionnaire.md): App Privacy questionnaire draft and verification gates.
- [`upload-checklist.md`](upload-checklist.md): pre-upload and submission checklist.
- [`validate_metadata.py`](validate_metadata.py): validates metadata limits directly from the localized Markdown files.

## Locked 1.0 scope

The store listing may describe only:

- focus, short-break, and long-break timers;
- pause, resume, skip, reset, and optional automatic starts;
- main-window D/W/M/Y statistics and per-bar hover counts;
- local session history plus JSON backup and merge import;
- menu-bar countdown and controls;
- notifications, completion sounds, and keyboard shortcuts.

Do not mention or show the web/app blocker, insights, tags, mini timer, paywall, Calendar, or iCloud. Widget metadata and screenshots remain excluded unless the signed App Store candidate passes Widget Gallery and App Group sharing verification.

## Current evidence boundary

Release candidate `1.0.0 (2)` has passed 200 tests, Release Analyze, a signed universal Archive, signature verification, effective-entitlement inspection, and App Store Connect upload validation. The upload was accepted for processing on 2026-09-22. The App Store Connect record, Simplified Chinese metadata, categories, age rating, copyright, review contact, and manual-release mode are configured.

App Store Connect has finished processing build 2 and reports it as ready to submit. The initial price is free, and the pricing page now confirms availability in all 175 storefronts. Build `1.0.0 (2)` is attached to macOS version 1.0 and the association is saved. The account-level EU Digital Services Act declaration was completed as **not a trader** on 2026-09-22 and App Store Connect reports the requirement as valid for the 27 EU storefronts. The signed TestFlight candidate is installed as `NanaFlow 2.app` (version `1.0.0`, build `2`) and its App Group history, Widget extension registration, main-window statistics, and menu-bar controls were verified. Three real candidate screenshots are uploaded for both listing locales, and the Chinese and English listing copy is saved. The App Privacy page is answered as “Data Not Collected”; publication of that answer is still a developer legal attestation. Migration edge-case tests, final privacy publication, and App Review submission remain explicit release gates. Named third-party quotations were removed from build 2 so the shipped Widget text is NanaFlow-authored.

Run before copying metadata into App Store Connect:

```sh
python3 AppStore/validate_metadata.py
```
