# App Privacy questionnaire draft

## Draft answer

- **Does this app collect data?** No.
- **Data used to track users?** No.
- **Data linked to the user?** No.
- **Privacy nutrition label candidate:** Data Not Collected.

This is a draft based on the current local-only architecture, not a submitted or signed-build-verified answer. “Collected” here means transmitted off the device by NanaFlow or its third-party partners for access beyond what is required to service a user request.

## Local data inventory

| Data | Purpose | Location / movement | App Privacy treatment |
|---|---|---|---|
| Timer state and preferences | Resume timer behavior and remember settings | App container / preferences on the Mac | Not collected off-device |
| Session history: identifiers, timestamps, durations, completion state, and preserved legacy metadata | Statistics, history, backup, and restore | App container; optional App Group mirror only if Widget ships | Not collected off-device |
| JSON/CSV/text exports and JSON imports | User-controlled portability | Only a file location selected by the user | Not collected off-device |
| Notification content | Announce timer-stage completion | Submitted to the local macOS notification framework | Not collected by NanaFlow off-device |
| Global shortcut configuration | Trigger timer commands | Stored locally | Not collected off-device |

No account, advertising identifier, analytics SDK, crash-reporting SDK, server API, Calendar data, iCloud sync, or payment flow is part of the locked 1.0 scope.

## Evidence in the current source tree

- Release entitlements declare App Sandbox, user-selected file read/write, and an App Group.
- The permission allowlist tests reject Apple Events automation, Calendar, network client, and iCloud KVS entitlements.
- `SessionHistoryPersistence` stores history locally and optionally mirrors it to App Group storage.
- `SessionExporter` creates local export data, and import uses a user-selected file.
- `SessionNotificationScheduler` uses `UNUserNotificationCenter` for timer-completion notifications.

## Mandatory checks before answering “No” in App Store Connect

- [ ] Inspect the **effective entitlements from the signed Release archive**, not only source plist files; confirm no unexpected network, Calendar, iCloud, contacts, location, microphone, camera, or tracking capability.
- [ ] Inspect the final dependency and linked-framework list; confirm no analytics, advertising, telemetry, crash-upload, attribution, or remote-configuration SDK was added.
- [ ] Run the signed candidate through timer, notification, backup, import, statistics, and relaunch flows while monitoring outbound network traffic; document that NanaFlow initiates no product-data transmission.
- [ ] Verify support and privacy pages make the same local-only claims as the submitted build.
- [ ] If Widget ships, verify App Group sharing remains on-device and update the local-data inventory; a failed Widget gate removes Widget from 1.0 rather than changing the privacy claim speculatively.
- [ ] Confirm no optional diagnostic upload, support attachment upload, or external feedback SDK was introduced after this draft.
- [ ] Re-answer the questionnaire if any build behavior, SDK, backend, or policy changes before submission.

## Privacy policy facts to carry into the public page

- Explain what timer/session/settings data is stored locally and why.
- Explain that exports occur only after the user chooses a destination and imports occur only after the user chooses a file.
- Explain notification permission and how to disable it.
- State whether a Widget is included only after the release decision is final.
- Provide `[PRIVACY_CONTACT_EMAIL]`, effective date, and a change-notice method.
- Do not claim that Apple itself collects no App Store diagnostics; scope the statement to data collected by NanaFlow and its developer.
