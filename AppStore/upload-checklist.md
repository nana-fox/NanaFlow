# NanaFlow App Store update checklist

An unchecked gate is not evidence of completion. Record links or build identifiers beside each checked item.

## Current update — 1.0.1 (4), checked 2026-11-02

- [x] Read the current review/version inventory before creating the update and again before submission; no other pending submission was present.
- [x] App and Widget agree on 1.0.1 (4); store scope and persistence formats remain unchanged.
- [x] 186 affected product checks and one background-isolation check passed; Release build/analyze passed.
- [x] Universal signed archive and both target entitlements verified; Apple processed the uploaded binary as verified.
- [x] Fresh current-state UI baseline, original binary preservation and two protected-data copies completed privately.
- [x] Exact signed Release archive candidate installed locally; normal first launch and quit/relaunch retained visible timer, statistics and supported settings.
- [x] Window edge, About version/build and native Window menu checked.
- [x] English/Simplified Chinese 1.0.1 copy saved and build 4 attached to the existing update.
- [x] Single App Review submission accepted on 2026-11-01; approved and automatically released on 2026-11-02.
- [x] Release after approval is automatic; immediate rollout and existing ratings retained.
- [x] Apple backend shows exact 1.0.1 (4) ready for distribution; public CN and US Lookup both return 1.0.1, released 2026-11-02T01:35:25Z.
- [x] Confirm a real official-store download provides the new version; a visible listing alone does not pass this check. Verified 2026-11-03: installed 1.0.1 (4) has `_MASReceipt`, `Apple Mac OS Application Signing` and its embedded Widget is the only registered copy.
- [ ] Apply the prepared localized shortcut-description correction in the next normally editable listing version; published 1.0.1 fields are disabled. No duplicate update is created for this housekeeping task.

Runtime acceptance used the exact development-signed Release archive, not a downloaded TestFlight/App Store variant. TestFlight channel installation and a full historical UUID-set audit were not performed. Notification actions, Widget pixel refresh and real sound audibility are deferred; no completion claim is made for them.

## Historical first-release checklist — 1.0.0 (2)

The following records describe the September 2026 first-release work. They are retained as history, not current 1.0.1 gates. Current evidence is summarized above and in [README.md](README.md).

## 1. Account and app record

- [x] Apple Developer Program status is Active; Team ID recorded: `LTLULSL8A2`.
- [x] The Free Apps Agreement is active for all countries or regions; the Paid Apps Agreement, tax, and banking setup are not required for the current free-only release.
- [x] App Store Connect app record exists for bundle ID `com.nanafox.NanaFlow`; Apple ID `6814738160`, SKU `nanaflow-macos-1`.
- [x] SKU `nanaflow-macos-1`, Simplified Chinese primary language, free price, and availability in all 175 storefronts are confirmed in App Store Connect.
- [x] EU Digital Services Act account status is declared **not a trader**; App Store Connect shows the declaration as valid for 27 EU storefronts (2026-09-22).
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

- [x] Existing local history is present in the App Group `group.com.nanafox.NanaFlow` and a NanaFlow backup snapshot is retained.
- [x] Store candidate installs and launches from `/Applications/NanaFlow 2.app`; bundle `1.0.0 (2)` is signed by `TestFlight Beta Distribution` with Team `LTLULSL8A2`.
- [ ] Timer start, pause, resume, stage switch, reset, natural completion, and relaunch pass.
- [ ] Menu-bar countdown, left-click menu, right/Control-click quick toggle, and window reopening pass.
- [x] D/W/M/Y controls are present in the candidate; week renders 7 bars and year renders 12 bars with accessible per-bar counts.
- [ ] JSON backup opens as valid data; merge import preserves local-only session IDs.
- [ ] Existing-install migration is verified against anonymized session UUID counts, or the release is stopped.
- [ ] Notification permission request, denial, later enablement, and completion notification behavior pass.
- [ ] If Widget is included: Gallery discovery, data sharing, refresh, and main-app agreement pass on the signed candidate.

## 5. Metadata and public pages

- [x] `python3 AppStore/validate_metadata.py` passes at commit preparation time.
- [x] `metadata.zh-Hans.md` is copied into the Simplified Chinese locale; description, promotional text, keywords, and URLs are saved in App Store Connect.
- [x] `metadata.en-US.md` is copied into the English (U.S.) locale; description, promotional text, keywords, and URLs are saved in App Store Connect.
- [x] Privacy URL is public over HTTPS: `https://nana-fox.github.io/privacy/` and `https://nana-fox.github.io/en/privacy/`.
- [x] Support URL is public over HTTPS and links to the public issue tracker: `https://nana-fox.github.io/support/` and `https://nana-fox.github.io/en/support/`.
- [x] Product URL is public over HTTPS: `https://nana-fox.github.io/` and `https://nana-fox.github.io/en/`.
- [x] App icon and the three uploaded screenshot slots are accepted by App Store Connect for both listing locales.
- [x] Screenshot asset register records six 1280×800 captures from candidate `1.0.0 (2)`; three are uploaded per locale.
- [x] App Privacy page shows “Data Not Collected”; signed candidate has no analytics/network entitlements and local App Group storage only.
- [x] English localization, version notes, screenshots, and review-note fields are resolved; copyright and review contact are configured.

## 6. Review notes and upload

- [ ] Base review note is updated with real contact details.
- [ ] Exactly one Widget review-note variant matches the uploaded binary.
- [ ] Reviewer can reach the main window from the menu bar using the documented steps.
- [x] Build 2 is uploaded, processing is complete, and App Store Connect reports “Ready to Submit.”
- [x] Processed build 2 is attached to version 1.0 and saved in App Store Connect.
- [ ] Export compliance, content rights, advertising identifier, and review-information questions are answered against the final binary.
- [ ] Submission is configured for manual release after approval.
- [x] Final submission diff is reviewed by an independent checklist pass before submission.

## Historical status — 2026-09-24

As of 2026-09-24, candidate `1.0.0 (2)` is the only intended review candidate. Calendar/EventKit, App/Web Blocker, Pro-unlock UI, tag catalog CRUD/UI, and iCloud timer sync are absent from the release UI and code paths; only `en` and `zh-Hans` ship. The candidate passed 200 tests, Release Analyze, universal signed Archive, deep signature verification, effective-entitlement inspection, linked-framework/symbol inspection, and App Store upload validation. The App and Widget use Team `LTLULSL8A2`, and the signed entitlements contain only the sandbox, shared App Group, user-selected file access where applicable, and Apple signing identifiers. Named third-party quotations were removed before build 2; all generated Widget quotations are attributed to NanaFlow. The upload was accepted for processing at 2026-09-22 15:43 CST.

Build `1.0.0 (2)` is attached to macOS version 1.0 and saved. The signed TestFlight candidate is installed and verified, the three real candidate screenshots are uploaded for both listing locales, and the listing copy is saved in Chinese and English. App Privacy is published as “Data Not Collected”, content rights are set to no third-party content, and App Store Connect accepted the version for review on 2026-09-24. The price is free, all 175 storefronts are available, and the EU DSA non-trader declaration is valid. Apple notes that review may take up to 48 hours.


## 1.0.2（5）— 由所有者确认后执行

本地准备与截图不代表已上传或发布。以下外部步骤全部保留未勾选，须经所有者确认；此工作分支没有执行它们。

- [x] 所有者确认候选版和本地验收报告后，使用 Xcode Organizer 上传 1.0.2（5）。（2026-11-03 明确授权后以 xcodebuild -exportArchive / destination=upload 完成；20:54:46 Upload succeeded。）
- [x] 等待处理完成，在 App Store Connect 的 1.0.2 版本选择构建 5。（构建 ID fcf3ab94-cc49-482c-9af7-c5935af341f2；已保存。）
- [x] 按 `screenshots.md` 的 1.0.2 登记表顺序替换 zh-Hans 和 en-US 各 4 张截图。（重新载入核对：各 4 张、01–04 顺序；英文使用独立素材。）
- [x] 保存两种语言已修正快捷键范围的描述，以及新增的 1.0.2 版本说明。（重新载入后与源文件逐字一致。）
- [x] 保存 `review-notes-1.0.2.txt`，由所有者核对审核联系人、出口合规和发布方式。（备注逐字核对；联系人未改；未出现新的出口问题；依所有者指示沿用 1.0.1 的 AFTER_APPROVAL 自动发布。）
- [x] 所有者最终确认后提交审核；不自动发布。（2026-11-03 已进入 Waiting for Review；旧默认值“不自动发布”由本轮所有者明确要求的“沿用 1.0.1 发布设置”取代，实际为 AFTER_APPROVAL。）


### 2026-11-03 执行结果

所有者已明确批准截图、文案、上传及提审，协调者再次复核提交前双语言页面，并授权保留 1.0.1 推广文本与 AFTER_APPROVAL 发布设置。以上 6 项已完成；已提交 1.0.2（5），当前 Waiting for Review；不是已审核通过或已公开发布。提交后独立只读会话强制刷新并分别核对两种语言 Mac 媒体管理，4 张截图标题和顺序均匹配源图；未撤回、未改字段、未重新提交。证据见 `Plans/evidence-1.0.2/submission/` 与 `Plans/worker-report-1.0.2.md` 末尾。
