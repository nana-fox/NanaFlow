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

The text is based on the implementation and release scope at commit `e47a916`. It does **not** claim that Archive, Validate App, upload, App Store installation, Widget sharing, or data migration have passed. URLs, legal entity, copyright year, support email, pricing, age rating answers, and signed-build privacy checks remain placeholders or gates.

Run before copying metadata into App Store Connect:

```sh
python3 AppStore/validate_metadata.py
```
