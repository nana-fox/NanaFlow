# NanaFlow 1.0.2 worker report

Branch: `release/1.0.2`; base `d029f64`; shipping UI/source commit `8fd36e09eda6a8299e549058e544029e165f71de`. Final delivery commit is in the worker_done receipt and `git rev-parse HEAD`. No push, merge, upload, submission, Apple metadata edits or website changes were performed.

| Criterion | Result | Evidence |
|---|---|---|
| A — English localization | PASS | 259 audited keys, 0 missing; pre-fix 31-key failure retained; XCTest gate; four English surface images |
| B — Version/project | PASS | 1.0.2 (5), App/Widget effective Info match; XcodeGen drift exit 0 |
| C — Unit tests/archive/export | PASS | 214/214 tests; universal strict-signed archive matches 1.0.1 Development identity/Team; local Apple Distribution export succeeds |
| D — Screenshots | PASS | Eight 2880×1800 opaque PNGs; real shipping views/native menus; timer digit ink 203px; separate locale processes and fictional data |
| E — Metadata | PASS | Corrected description retained; bilingual 1.0.2 notes, review notes and unchecked owner upload steps; metadata validator exit 0 |
| Constraint 1 — Running store app | PASS | PID 41738 remains `/Applications/NanaFlow.app/Contents/MacOS/NanaFlow`; no quit, kill, relaunch or replacement |
| Constraint 2 — Production-data comparison | DIFF, coordinator reviewed | Same 85 entries; 2 preference hashes differ; mtime attribution to running store timer accepted by coordinator, contents unread, no action |
| Constraint 3 — Production identity launch gate | PASS | Only ReleaseTests / Screenshots hosts launched; separate App Group, minimal test entry; production candidate never launched |
| Constraint 4 — Fixture cleanup | PASS | Exact containers/preferences/groups removed or absent; exact Widget and LaunchServices queries empty |
| Constraint 5 — Local-only work | PASS | Local branch/commits only; export destination=export; no outward publication actions |
| Constraint 6 — Historical text | PASS | Existing history and 1.0.1 notes untouched; current metadata/register/checklist/README only appended |

Archive: `/Users/oyd/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive`. Main executable SHA-256: `850975fb37e03da0bb4e8405a3a0efdb3e18142b27efe0a15b8d124f9b537e93`. Export: `build/release-1.0.2/ExportRelease/NanaFlow.pkg` (10,510,922 bytes; App and Widget Apple Distribution / LTLULSL8A2).

| Screenshot | Bytes | Dimensions | Alpha |
|---|---:|---|---|
| `AppStore/Screenshots/1.0.2/en-US/01-focus-menu.png` | 2,943,743 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/en-US/02-week-count.png` | 3,437,327 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/en-US/03-month-duration.png` | 3,454,742 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/en-US/04-completion-sounds.png` | 3,486,715 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/zh-Hans/01-focus-menu.png` | 2,934,027 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/zh-Hans/02-week-count.png` | 3,429,106 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/zh-Hans/03-month-duration.png` | 3,464,150 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/zh-Hans/04-completion-sounds.png` | 3,485,815 | 2880×1800 | no |

Extra English timer-options evidence: `Plans/evidence-1.0.2/A-en-timer-options.png` (3,178,682 bytes). Image hashes/source details: `AppStore/Screenshots/1.0.2/manifest.json`.

DIFF in 2 preference plists, attributed by mtime pattern to the owner's running store app (25-minute session interval); contents not read; no action taken. Coordinator reviewed 2026-11-03.

| Changed preference file | Before mtime (UTC+08) | After mtime (UTC+08) | Bytes |
|---|---|---|---|
| `~/Library/Containers/com.nanafox.NanaFlow/Data/Library/Preferences/com.nanafox.NanaFlow.plist` | 2026-11-03T17:34:33.264839+08:00 | 2026-11-03T17:59:42.515009+08:00 | 52733 → 52869 |
| `~/Library/Group Containers/group.com.nanafox.NanaFlow/Library/Preferences/group.com.nanafox.NanaFlow.plist` | 2026-11-03T17:34:22.519155+08:00 | 2026-11-03T17:59:42.517845+08:00 | 50460 → 50648 |

Open issues: no code/test/build/export blockers. The two production-preference DIFFs are disclosed and reviewed, with no remediation. Coordinator independent review and owner-confirmed upload/submission remain; the worker has not published anything. The archive temporary LaunchServices registration was removed by its exact generated path, and production resolution reads `/Applications/NanaFlow.app`.

Full per-criterion commands, summaries, audit table and failure history: `Plans/release-1.0.2.md`. Verbose local evidence and private hash receipts: `build/release-1.0.2/evidence/`. Concise committed evidence: `Plans/evidence-1.0.2/`.
