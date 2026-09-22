# NanaFlow 1.0 upload checklist

An unchecked gate is not evidence of completion. Record links or build identifiers beside each checked item.

## 1. Account and app record

- [x] Apple Developer Program status is Active; Team ID recorded: `LTLULSL8A2`.
- [ ] Agreements, tax, and banking requirements applicable to the selected price are complete.
- [x] App Store Connect app record exists for bundle ID `com.nanafox.NanaFlow`; Apple ID `6814738160`, SKU `nanaflow-macos-1`.
- [ ] SKU `nanaflow-macos-1`, Simplified Chinese primary language, and free price are selected; all 175 storefronts were submitted for availability and await final readback verification.
- [x] Primary category is Productivity; secondary category is Utilities.
- [x] Age rating questionnaire is completed; current result is 4+.
- [x] Copyright is set to `2026 Nio D`.

## 2. Product scope

- [x] Release UI and menus contain no web/app blocker, insights, tag workflow, mini timer, paywall, Calendar, or iCloud entry point.
- [x] Store copy contains none of those excluded capabilities; screenshot verification remains open until final assets are uploaded.
- [x] Only Simplified Chinese and English are treated as 1.0 listing locales.
- [x] Widget decision is recorded: included in build 2; Gallery and App Group runtime verification remain mandatory before submission.

## 3. Signing and build

- [x] Main App and included Widget use Team `LTLULSL8A2`.
- [x] Version is `1.0.0`; build number `2` was accepted for App Store Connect processing.
- [x] Release archive effective entitlements match the approved allowlist.
- [x] `ITSAppUsesNonExemptEncryption` is `false`, matching the final executable.
- [x] 200 tests and Release Analyze pass on the build 2 candidate working tree.
- [x] Archive succeeds: `/tmp/NanaFlow-AppStore-build2.xcarchive`.
- [x] App Store upload validation succeeds; upload accepted at 2026-09-22 15:43 CST.

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
- [x] `metadata.zh-Hans.md` is copied into the Simplified Chinese locale.
- [ ] `metadata.en-US.md` is copied into the English locale.
- [x] Privacy URL is public over HTTPS: `https://nana-fox.github.io/privacy/` and `https://nana-fox.github.io/en/privacy/`.
- [x] Support URL is public over HTTPS and links to the public issue tracker: `https://nana-fox.github.io/support/` and `https://nana-fox.github.io/en/support/`.
- [x] Product URL is public over HTTPS: `https://nana-fox.github.io/` and `https://nana-fox.github.io/en/`.
- [ ] App icon and every required screenshot slot are accepted by App Store Connect.
- [ ] Screenshot asset register records the exact candidate version/build.
- [ ] App Privacy answers are rechecked after signed-build and traffic verification.
- [ ] English localization, version notes, screenshots, and remaining review-note fields are resolved; copyright and review contact are already configured.

## 6. Review notes and upload

- [ ] Base review note is updated with real contact details.
- [ ] Exactly one Widget review-note variant matches the uploaded binary.
- [ ] Reviewer can reach the main window from the menu bar using the documented steps.
- [x] Build 2 is uploaded, processing is complete, and App Store Connect reports “Ready to Submit.”
- [ ] Processed build is attached to version 1.0.
- [ ] Export compliance, content rights, advertising identifier, and review-information questions are answered against the final binary.
- [ ] Submission is configured for manual release after approval.
- [ ] Final submission diff is reviewed by a second person or an independent checklist pass.

## Current status

As of 2026-09-22, candidate `1.0.0 (2)` is the only intended review candidate. Calendar/EventKit, App/Web Blocker, Pro-unlock UI, tag catalog CRUD/UI, and iCloud timer sync are absent from the release UI and code paths; only `en` and `zh-Hans` ship. The candidate passed 200 tests, Release Analyze, universal signed Archive, deep signature verification, effective-entitlement inspection, linked-framework/symbol inspection, and App Store upload validation. The App and Widget use Team `LTLULSL8A2`, and the signed entitlements contain only the sandbox, shared App Group, user-selected file access where applicable, and Apple signing identifiers. Named third-party quotations were removed before build 2; all generated Widget quotations are attributed to NanaFlow. The upload was accepted for processing at 2026-09-22 15:43 CST.

Still open: attachment of build 2 to version 1.0, final readback of the submitted 175-storefront availability, EU trader-status completion, mainland-China compliance follow-up, screenshots, English localization entry, privacy publication attestation, signed distribution installation, Widget Gallery/App Group runtime verification, migration verification, and final App Review submission. The price is free. Final submission requires explicit developer confirmation.
