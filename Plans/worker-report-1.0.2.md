# NanaFlow 1.0.2 — independent-review fixes

Branch `release/1.0.2`; shipping source `d706c738379a5570a1d4fdc83556b6aa5631bf55`; screenshot harness `eed2e7b55a39b131fa0a7e0631fb2398136ce87a`; final delivery commit is in the worker_done receipt. No push, merge, upload, submission, Apple metadata edit or website change.

| Criterion | Result | Evidence |
|---|---|---|
| Fix 1: active ON toggle / clean equal framing | PASS | Both 04 images show a green ON track (6969 accent pixels); section/page headers excluded completely; same 1520×700 continuous crop aligned to the actual control; production settings unchanged |
| Fix 2: menu icons | DROPPED BY COORDINATOR | macOS 27 automatic image policy retained; no preferredImageVisibility override or menu production diff; final in-process native menu capture requires no Screen Recording grant; exact TCC reset succeeded |
| Fix 3: month-end labels | PASS | Failing test first b95d356; fix d706c73; 28/29/30/31-day cases preserve the last date with spacing; both 03 images regenerated |
| A: localization | PASS | 259 audited keys / 0 missing; full XCTest gate retained |
| B: version/project | PASS | 1.0.2 (5), App/Widget versions match; drift check exit 0 |
| C: tests/archive/export | PASS | 215/215 tests; new universal archive and local signed distribution export validated |
| D: screenshot assets | PASS | 8 opaque 2880×1800 PNGs; real candidate controls, 203px timer ink; four revised images inspected; 01 unchanged byte-for-byte |
| E: metadata | PASS | Validator exit 0; current release notes also mention the real month-end label repair; owner upload steps remain unchecked |
| Constraint 1: running store app | PASS | PID 41738 continuously started 16:24:19; installed path still /Applications/NanaFlow.app; no quit/kill/relaunch/replace |
| Constraint 2: data receipts | DIFF / no attribution | DIFF: 1 preference file changed among 85 unchanged paths; contents not decoded, no attribution or corrective write made. |
| Constraint 3: production launch gate | PASS | Only isolated screenshot/test hosts; separate suites; production archive never launched |
| Constraint 4: identity cleanup | PASS | Exact fixture containers/preferences/Widget/LaunchServices cleaned; exact ScreenCapture reset; temporary archive registration removed |
| Constraint 5: local-only | PASS | Local branch/commits, destination=export only |
| Constraint 6: historical text | PASS | 1.0.1 history untouched; plan and screenshot register append superseding review records |

Archive: `/Users/oyd/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive` (overwritten with 1.0.2 build 5). Main executable SHA-256: `abd19732001008099166356db2460a0a96f402b306ceebe868655c3a0e5c68d3`. Export: `build/release-1.0.2/ExportReviewFixes/NanaFlow.pkg` (10,511,003 bytes; App/Widget Apple Distribution / LTLULSL8A2; strict signature checks pass).

| Screenshot | Bytes | Dimensions | Alpha |
|---|---:|---|---|
| `AppStore/Screenshots/1.0.2/en-US/01-focus-menu.png` | 2,943,743 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/en-US/02-week-count.png` | 3,437,327 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/en-US/03-month-duration.png` | 3,454,250 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/en-US/04-completion-sounds.png` | 3,946,183 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/zh-Hans/01-focus-menu.png` | 2,934,027 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/zh-Hans/02-week-count.png` | 3,429,106 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/zh-Hans/03-month-duration.png` | 3,463,657 | 2880×1800 | no |
| `AppStore/Screenshots/1.0.2/zh-Hans/04-completion-sounds.png` | 3,943,142 | 2880×1800 | no |


| Changed file | Before mtime (UTC+08) | After mtime (UTC+08) | Bytes |
|---|---|---|---|
| `~/Library/Containers/com.nanafox.NanaFlow/Data/Library/Preferences/com.nanafox.NanaFlow.plist` | 2026-11-03T17:59:42.515009+08:00 | 2026-11-03T18:50:52.533305+08:00 | 52869 → 52921 |


Production inventory/hash receipts remain local under `build/release-1.0.2/evidence/review-fixes/`, without decoding their contents. The prior run's two-file DIFF and its coordinator-reviewed mtime attribution remain historical in the plan; this repair-run DIFF is reported separately without an invented cause.

No code/test/build/export blockers remain; the data comparison is disclosed for coordinator review. Coordinator independent visual review and owner-confirmed upload/submission remain; no outward release action was taken. Full commands and audit trail: the final review section in `Plans/release-1.0.2.md`; concise committed receipts in `Plans/evidence-1.0.2/review-fixes/`; current image hashes in `AppStore/Screenshots/1.0.2/manifest.json`.
