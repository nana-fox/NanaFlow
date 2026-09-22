# NanaFlow 1.0 upload checklist

An unchecked gate is not evidence of completion. Record links or build identifiers beside each checked item.

## 1. Account and app record

- [x] Apple Developer Program status is Active; Team ID recorded: `LTLULSL8A2`.
- [ ] Agreements, tax, and banking requirements applicable to the selected price are complete.
- [ ] App Store Connect app record exists for bundle ID `com.nanafox.NanaFlow`.
- [ ] SKU, primary language, availability, and price are explicitly selected.
- [ ] Primary category is Productivity; secondary category is Utilities.
- [ ] Age rating questionnaire is completed against the final build.
- [ ] Copyright is resolved to `© [YEAR] [LEGAL_NAME]`.

## 2. Product scope

- [ ] Release UI and menus contain no web/app blocker, insights, tag workflow, mini timer, paywall, Calendar, or iCloud entry point.
- [ ] Store copy and screenshots contain none of those excluded capabilities.
- [ ] Only Simplified Chinese and English are treated as 1.0 listing locales.
- [ ] Widget decision is recorded: `REMOVED FROM 1.0 / INCLUDED AFTER SIGNED PASS`.

## 3. Signing and build

- [ ] Main App, any included Widget, and nested executables use the same Team.
- [ ] Version is `1.0.0`; build number is unique in App Store Connect: `[BUILD]`.
- [ ] Release archive effective entitlements match the approved allowlist.
- [ ] `ITSAppUsesNonExemptEncryption` answer matches the final executable and export-compliance selection.
- [ ] Release tests and Analyze pass at the exact submitted commit: `[COMMIT]`.
- [ ] Archive succeeds. Archive path/identifier: `[ARCHIVE_EVIDENCE]`.
- [ ] Validate App succeeds. Validation timestamp/log: `[VALIDATE_EVIDENCE]`.

## 4. Data safety and candidate verification

- [ ] Existing local history is backed up before installing the candidate.
- [ ] Store candidate installs and launches from the intended distribution path.
- [ ] Timer start, pause, resume, stage switch, reset, natural completion, and relaunch pass.
- [ ] Menu-bar countdown, left-click menu, right/Control-click quick toggle, and window reopening pass.
- [ ] D/W/M/Y bar counts and hover numbers match the candidate's test sessions.
- [ ] JSON backup opens as valid data; merge import preserves local-only session IDs.
- [ ] Existing-install migration is verified against anonymized session UUID counts, or the release is stopped.
- [ ] Notification permission request, denial, later enablement, and completion notification behavior pass.
- [ ] If Widget is included: Gallery discovery, data sharing, refresh, and main-app agreement pass on the signed candidate.

## 5. Metadata and public pages

- [x] `python3 AppStore/validate_metadata.py` passes at commit preparation time.
- [ ] `metadata.zh-Hans.md` is copied into the Simplified Chinese locale.
- [ ] `metadata.en-US.md` is copied into the English locale.
- [x] Privacy URL is public over HTTPS: `https://nana-fox.github.io/privacy/` and `https://nana-fox.github.io/en/privacy/`.
- [x] Support URL is public over HTTPS and links to the public issue tracker: `https://nana-fox.github.io/support/` and `https://nana-fox.github.io/en/support/`.
- [x] Product URL is public over HTTPS: `https://nana-fox.github.io/` and `https://nana-fox.github.io/en/`.
- [ ] App icon and every required screenshot slot are accepted by App Store Connect.
- [ ] Screenshot asset register records the exact candidate version/build.
- [ ] App Privacy answers are rechecked after signed-build and traffic verification.
- [ ] Version notes, copyright, support contact, and review contact placeholders are resolved.

## 6. Review notes and upload

- [ ] Base review note is updated with real contact details.
- [ ] Exactly one Widget review-note variant matches the uploaded binary.
- [ ] Reviewer can reach the main window from the menu bar using the documented steps.
- [ ] Build is uploaded and App Store Connect finishes processing it.
- [ ] Processed build is attached to version 1.0.
- [ ] Export compliance, content rights, advertising identifier, and review-information questions are answered against the final binary.
- [ ] Submission is configured for manual release after approval.
- [ ] Final submission diff is reviewed by a second person or an independent checklist pass.

## Current status

As of 2026-09-22, the excluded-feature scope reduction landed on top of the prior 230-test baseline: Calendar/EventKit, App/Web Blocker, Pro-unlock UI, tag catalog CRUD/UI, and iCloud timer sync were physically removed from `Sources/NanaFocus` (not just hidden from menus), including `TimerPreferences.calendarSyncEnabled`/`calendarIdentifier` and the Blocker/Calendar-only resources `Blocked.html`, `NanaFlowBlockedIcon.png`, `NanaFlowCalendarAccess.png` (all confirmed to have zero live references before deletion). All but the `en`/`zh-Hans` localizations were deleted. `FocusSession.tag` and its backup/export/import/edit pass-through remain intact and covered by tests, including a controller-level edit test that starts from a non-nil legacy tag and asserts it survives an edit unchanged; `TimerPreferences` safely ignores legacy `timerSyncEnabled` and `calendarSyncEnabled`/`calendarIdentifier` JSON keys on decode (regression tests for both). 200 tests, Release Analyze, and a fresh unsigned Release Archive are recorded as passed at this state (net -30 from the 230 baseline, independently verified via the test-file diff: 39 test methods removed, 9 added). `otool -L`/`nm`/`strings` on the unsigned Release Archive binary confirm no EventKit, no Security.framework, and no iCloud/cloud-sync linkage or symbols; only `en.lproj`/`zh-Hans.lproj` ship in both the main app and Widget bundles, and the three removed Blocker/Calendar resources are absent from the archived bundle. `script/build_and_run.sh` now force-cleans its repo-scoped DerivedData directory before every build (incremental builds were previously leaving stale removed-locale resources in the Debug bundle) and its `--verify` mode runs a bundle-resource verifier that fails unless exactly `en`/`zh-Hans` ship and none of the three removed resources are present; this was confirmed against both the fresh Debug build and the Release Archive. Non-mutating XcodeGen drift check and `git diff --check` are clean. `python3 AppStore/validate_metadata.py` passes. Runtime logs (captured via `log show` with an explicit timestamp range spanning a full build+launch, to avoid missing early-startup entries) show two known, non-fatal categories and no crash or genuine fault: (1) the known unsigned-build App Intents `linkd` connection-rejection pattern (`requiresValidatedBundle`, `Error Domain=NSCocoaErrorDomain Code=4097`); and (2) an intermittent AppKit `WarnOnce` layout-recursion message (`-layoutSubtreeIfNeeded on a view which is already being laid out`) that occurs during standard `NSStatusItem` Control Center scene registration on this macOS 26.1 environment. This was investigated in depth: an A/B/elimination study across 30+ timed cold launches localized it specifically to `NSStatusBar.system.statusItem(withLength:)` itself (0/6 launches warned with no status item constructed; 5/6 warned with the status item constructed and nothing else touched), with every occurrence's log context showing `com.apple.controlcenter` `NSStatusItemView` scene-fence activity, not application code. A one-run-loop-turn defer of status item construction measurably reduced the rate (12/12 clean in one batch) but did not deterministically eliminate it in further testing (occasional recurrence, log context unchanged), so no code change for it is retained in this branch — a partial, unproven timing mitigation was judged worse than an honest known-issue record. Do not report this warning as fixed or eliminated. It requires retesting on a signed distribution build and/or a different OS build to determine whether it reproduces outside this sandboxed, rapidly-relaunched development environment; it does not block functionality (the app always launches and stays running, `build_and_run.sh --verify` always passes) but should be retested before or alongside the signed-build gate. The signed Archive remains blocked while Apple's provisioning service reports no eligible device for the team — this scope-reduction work does not change that blocker and does not claim it resolved. Validate App, upload, store installation, Widget sharing, and existing-data migration are **not recorded as passed**. Do not check those items using local unit-test, unsigned-archive, or ad-hoc-build evidence.
