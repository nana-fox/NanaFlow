# NanaFlow 1.0 upload checklist

An unchecked gate is not evidence of completion. Record links or build identifiers beside each checked item.

## 1. Account and app record

- [ ] Apple Developer Program status is Active; Team ID recorded: `[TEAM_ID]`.
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

As of the material-pack commit, Archive, Validate App, upload, store installation, Widget sharing, and existing-data migration are **not recorded as passed**. Do not check those items using local unit-test or ad-hoc-build evidence.
