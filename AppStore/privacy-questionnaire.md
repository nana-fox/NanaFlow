# App Privacy questionnaire draft

Scope clarification — 2026-11-02: the data-collection decision is unchanged. The current store UI has no session-list, export-backup or import-restore entry point; preserved helper code does not make these user-accessible features. The historical checks below retain their original source build and unchecked status.

## Draft answer

- **Does this app collect data?** No.
- **Data used to track users?** No.
- **Data linked to the user?** No.
- **Privacy nutrition label candidate:** Data Not Collected.

This answer is supported by source review and signed-build entitlement/dependency inspection. The answer was published in App Store Connect on 2026-09-24 after explicit developer confirmation. “Collected” here means transmitted off the device by NanaFlow or its third-party partners for access beyond what is required to service a user request.

## Local data inventory

| Data | Purpose | Location / movement | App Privacy treatment |
|---|---|---|---|
| Timer state and preferences | Resume timer behavior and remember settings | App container / preferences on the Mac | Not collected off-device |
| Session history: identifiers, timestamps, durations, completion state, and preserved legacy metadata | Statistics and preservation of existing data | App container and the included Widget's local App Group mirror | Not collected off-device |
| Preserved export/import helper code | Internal compatibility logic; no reachable store UI | User-selected-file APIs in retained code; not advertised as an available workflow | No off-device collection is introduced |
| Notification content | Announce timer-stage completion | Submitted to the local macOS notification framework | Not collected by NanaFlow off-device |
| Global shortcut configuration | Trigger timer commands | Stored locally | Not collected off-device |

No account, advertising identifier, analytics SDK, crash-reporting SDK, server API, Calendar data, iCloud sync, or payment flow is part of the locked 1.0 scope.

## Evidence in the current source tree

- Release entitlements declare App Sandbox, user-selected file read/write, and an App Group.
- The permission allowlist tests reject Apple Events automation, Calendar, network client, and iCloud KVS entitlements.
- `SessionHistoryPersistence` stores history locally and optionally mirrors it to App Group storage.
- `SessionExporter` retains local export/import helpers; the store UI does not expose them as a usable backup workflow.
- `SessionNotificationScheduler` uses `UNUserNotificationCenter` for timer-completion notifications.

## Mandatory checks before answering “No” in App Store Connect

- [x] Inspect the **effective entitlements from signed Release archive `1.0.0 (2)`**: only App Sandbox, App Group, user-selected file read/write, application identifier, and Team identifier are present; no network, Calendar, iCloud, contacts, location, microphone, camera, or tracking entitlement.
- [x] Inspect the final dependency and linked-framework list; no analytics, advertising, telemetry, crash-upload, attribution, or remote-configuration SDK is linked.
- [ ] Run the signed candidate through reachable timer, notification, statistics and relaunch flows while monitoring outbound network traffic; document that NanaFlow initiates no product-data transmission. Hidden backup/import helpers are not a user-flow acceptance claim.
- [x] Verify the published support and privacy pages make the same local-only claims as the submitted build; all six HTTPS URLs return 200 after the GitHub Pages workflow deployment on 2026-09-24.
- [x] Widget ships in build 2; the signed candidate exposes `NanaFlowWidget.appex`, App Group `group.com.nanafox.NanaFlow` contains the shared history file, and Widget Gallery registration is present.
- [x] Confirm no optional diagnostic upload, support attachment upload, or external feedback SDK was introduced before candidate build 2.
- [ ] Re-answer the questionnaire if any build behavior, SDK, backend, or policy changes before submission.

## Privacy policy facts to carry into the public page

- Explain what timer/session/settings data is stored locally and why.
- Explain that the current store UI has no history-list, export or import entry point; do not turn retained file-access helpers into a feature promise.
- Explain notification permission and how to disable it.
- State whether a Widget is included only after the release decision is final.
- Provide `[PRIVACY_CONTACT_EMAIL]`, effective date, and a change-notice method.
- Do not claim that Apple itself collects no App Store diagnostics; scope the statement to data collected by NanaFlow and its developer.
