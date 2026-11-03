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


## 2026-11-03 所有者批准上传与提审（执行中）

所有者已审核并批准 8 张截图与两种语言商店文案，明确授权上传现有归档和提交 App Review；分支基线为 `f0829dcd0b64d9e9b5ee30308d07a856f5e9d386`，不得合入 main。本次不重新构建、不启动或操作已安装的商店版、不读取生产数据内容、不修改网站。

生产数据 DIFF 已由所有者与协调者确认：**attributed to the running store app's own writes (post-run change at 19:16 confirms)**。所有者未使用应用，但任务结束后 19:16 偏好再次变化，当时仅商店版 PID 41738 运行；来源为 TimerController.persist / recordSession 在阶段结束时写入自身计时状态，无需采取动作；历史哈希 DIFF 保持原样，不改写为相等。

上传前只读核对归档：`1.0.2 (5)`、Team `LTLULSL8A2`、主程序 SHA-256 `abd19732001008099166356db2460a0a96f402b306ceebe868655c3a0e5c68d3`。本地收据：`build/release-1.0.2/evidence/submission/archive-preflight.json`。

已于 20:51 UTC+08 启动 `xcodebuild -exportArchive -archivePath /Users/oyd/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive -exportOptionsPlist build/release-1.0.2/evidence/submission/UploadOptions.plist -exportPath build/release-1.0.2/Upload -allowProvisioningUpdates`；`method=app-store-connect`、`destination=upload`、Team `LTLULSL8A2`、版本号自动管理关闭。尚未确认上传成功；日志：`build/release-1.0.2/evidence/submission/upload.log`。

App Store Connect 网页当前显示 Apple 账户登录页，尚未编辑版本、截图或文案，尚未提交审核。Ego task space 2 已 handOff 给所有者以完成登录；登录页证据：`build/release-1.0.2/evidence/submission/asc-signin-required.png`。


### 上传、版本配置与提交前证据（尚未提审）

- `xcodebuild -exportArchive` 于 20:54:46 UTC+08 返回 `Upload succeeded` / `EXPORT SUCCEEDED`，未重建。完整普通上传日志与前置 SHA 收据已提交在 `Plans/evidence-1.0.2/submission/`。
- App Store Connect 处理完成，构建 `1.0.2 (5)` / ID `fcf3ab94-cc49-482c-9af7-c5935af341f2` 显示“准备提交”；新建 macOS 1.0.2 并选中、保存该构建。
- zh-Hans、en-US 各四张新截图按 `01-focus-menu.png`、`02-week-count.png`、`03-month-duration.png`、`04-completion-sounds.png` 顺序保存；旧中文素材已移除，英文为独立素材，不再继承中文图片。
- 两种语言 description、最后一个 version_notes 文本块、完整 review-notes 文件（包括尾换行）均已保存；重新载入后逐字比较通过。字段与顺序收据：`Plans/evidence-1.0.2/submission/{zh-Hans,en-US}-fields.json`。名称、副标题、关键词、价格、隐私、分类均未编辑；当前页面其余控件的前后值一致。
- 1.0.1 的 releaseType 只读查询为 AFTER_APPROVAL，1.0.2 继承同值，依本任务最新指示保持“审核通过后自动发布”；历史清单“不自动发布”的措辞由本次明确“沿用 1.0.1 发布方式”的指示取代。现有联系人保持原值；没有遇到新的出口合规问题。
- 提交前双语言版本页已保存并目视检查：`build/release-1.0.2/evidence/submission/version-zh-Hans-before-submit.png`、`version-en-US-before-submit.png`；完整页面包含现有审核联系信息，仅留本地，不提交图片到 Git。
- 上传 UI 的首次素材移除与上传发生竞态，出现处理停留和单张不完整素材；刷新后确认未成功，清空素材并等到 0/10 后通过正常文件选择器上传，最终重新载入各 4 张且顺序正确。文本 fill 路径未触发表单保存状态，未将 DOM 值当成已保存；改用浏览器原生粘贴、显式保存并重新载入校验，最终内容一致。

待协调者澄清：Apple 新建版本未继承 1.0.1 的推广文本，两种语言当前均为空（本 worker 未编辑此字段）。为避免违反“其他字段不变”，提交前询问是否将 1.0.1 已发布的推广文本原样沿用到 1.0.2；尚未点“添加以供审核”或“提交审核”。


### 21:50 UTC+08 已提交，最终交付前复核待处理

协调者 `msg_8f6adc717af1` 批准两种语言提交前页面并明确授权将 1.0.1 推广文本原样复制到 1.0.2，随后提交。已只读读回 1.0.1 的 zh-Hans 61 字符、en-US 158 字符推广文本，均与 metadata 文件一致；保存到 1.0.2 后重新载入逐字比较一致，收据 `published-promotional-text.json` 与两个 locale-fields JSON 已更新。

最终双语言页面在 `version-{zh-Hans,en-US}-final-before-submit.png`；已在点击前通过 Orca `msg_c4cdbf8111af` 发送。随后点击“添加以供审核”，草稿显示 macOS 1.0.2 / 1.0.2 (5)，再点击“提交以供审核”；未出现出口合规问题。于 `2026-11-03T13:50:34.351Z` 核对为 **Waiting for Review / 正在等待审核**，releaseType 仍为 AFTER_APPROVAL。证据：`Plans/evidence-1.0.2/submission/waiting-for-review.json`、`waiting-for-review.png`；成功面板显示“已提交 1 个项目”。Ego task space 2 已正常 finish。

归档主程序 SHA 再次只读核对仍为 `abd19732001008099166356db2460a0a96f402b306ceebe868655c3a0e5c68d3`；生产进程只读 `ps -p 41738 -o pid,lstart,comm` 仍为 16:24:19 启动的 `/Applications/NanaFlow.app/Contents/MacOS/NanaFlow`，未执行任何生产操作。

**交付前待复核的可见差异：** 提交前最终 en-US PNG（已等图片完成加载）明确显示英文截图；提审成功面板背后却在英语（美国）标题/英文推广文本下显示中文缩略图。两处素材数量/文件名相同，不能仅凭文件名判断映射；可能是提交后缓存，但尚未验证，不据此声称已提交的英文映射正确。任务浏览器已结束，需协调者允许新的只读浏览器复核，或独立核对已提交的两种语言素材；在此之前不写最终成功交付、不 push。


## 2026-11-03 最终上传与 App Review 交付记录

本节取代上方“执行中”“尚未提审”和“待复核”的当前状态表述，上方内容保留为执行历史。所有者已批准上传与提审，协调者 `msg_8f6adc717af1` 再次批准双语言页面和 1.0.1 推广文本原样沿用，`msg_3e5850d8b86b` 授权提交后新建只读会话核对素材。

**当前结果：App ID 6814738160，macOS 1.0.2（5），Waiting for Review / 正在等待审核；build ID fcf3ab94-cc49-482c-9af7-c5935af341f2；releaseType AFTER_APPROVAL，与 1.0.1 一致。** 未声称审核通过或已公开发布。

| 本轮步骤 / 约束 | 结果 | 命令或操作、输出摘要 | 证据路径 |
|---|---|---|---|
| 1 上传既有归档 | PASS | `xcodebuild -exportArchive ... -exportOptionsPlist .../UploadOptions.plist -allowProvisioningUpdates`；destination=upload / app-store-connect / LTLULSL8A2；20:54:46 Upload succeeded / EXPORT SUCCEEDED，未重建 | `submission/upload.log`、`UploadOptions.plist`、`archive-preflight.json` |
| 2 处理、创建版本、选 build 5 | PASS | Ego UI：构建 1.0.2 (5) 处理为“准备提交”；新建 macOS 1.0.2 并选择、保存该构建 | `submission/build-processed.txt`、`waiting-for-review.json` |
| 3 两种语言截图 | PASS | Ego UI：各 4 张，01–04；提审后只读会话执行 `Page.reload {ignoreCache:true}`，分别选择 zh-Hans / en-US 并打开 Mac 媒体管理；逐张读取已显示的 CDN 缩略图，以标题匹配源图并核对顺序 | `submission/submitted-{zh-Hans,en-US}-media{,-end}.png`、对应 JSON、`submitted-media-verification.json` |
| 4 文案与审核信息 | PASS | 原生粘贴并保存两种语言 description、最后一块 version_notes 和完整 review-notes；reload 后逐字比较。1.0.1 推广文本原样复制，zh 61 / en 158 字符，均与 metadata 一致；其他指定字段、联系人未编辑；保留 AFTER_APPROVAL，无新增出口合规提问 | `submission/{zh-Hans,en-US}-fields.json`、`published-promotional-text.json`、`1.0.1-release-option.json` |
| 5 先发送页面证据再提审 | PASS | Orca 提交前消息 msg_9614dff87653 / msg_c4cdbf8111af；协调者批准后点击 Add for Review、Submit for Review；21:50 UTC+08 显示 Waiting for Review，随后只读复核仍相同 | `submission/draft-submission.txt`、`waiting-for-review.json`、`waiting-for-review.png`、`review-submission-status.png` |
| 运行商店版 | PASS | `ps -p 41738 -o pid,lstart,comm`：仍是 16:24:19 启动的 `/Applications/NanaFlow.app/Contents/MacOS/NanaFlow`；本轮无 quit/kill/relaunch/replace，无 production-ID 启动或测试 | 本节命令摘要；本轮仅归档导出上传和网页配置 |
| 生产数据 | RESOLVED，历史 DIFF 保留 | 所有者确认 **attributed to the running store app's own writes (post-run change at 19:16 confirms)**；来自 TimerController.persist / recordSession 的阶段结束写入；未解码、未恢复、无需动作，本轮未再读取生产数据文件 | 上方历史 before/after 及 mtime 收据；本轮任务授权说明 |
| 其他边界 | PASS | 未启动 fixture、未改网站、未合入 main；外发范围仅所有者本轮授权的上传、指定字段与截图、提审，以及 release/1.0.2 分支推送；历史文档追加记录，清单仅按本任务要求打勾并注释最新授权 | `AppStore/upload-checklist.md`、Git diff、本轮 Orca 记录 |

上表 `submission/` 均指 `Plans/evidence-1.0.2/submission/`。提交前完整页面位于本地 `build/release-1.0.2/evidence/submission/version-{zh-Hans,en-US}-final-before-submit.png`，含既有审核联系信息，未提交到 Git。只读复核的 CDN 缩略图位于同目录的 `submitted-<locale>/`，证据 JSON 记录各图 URL、顺序与缩略图 SHA-256；720×450 缩略图只做标题/内容核对，不冒充 2880×1800 源图的逐字节校验。

提交成功面板背后曾出现英语标题下中文缩略图的瞬时显示。协调者要求复核后，在全新只读会话强制刷新、重新选择语言，并分别查看 Mac 媒体管理，确认实际两组素材分别为中文和英文且顺序正确；未改字段、未撤回、未重新提交。硬刷新英文媒体管理 URL 时页面曾返回版本页；重新打开媒体管理后再次核对并截图，最终证据 URL 明确以 `/media-manager` 结尾。该显示差异已排除为当前已提交素材错误，具体 UI 缓存/渲染机制未调查。

| 语言 | 顺序 | 已提交缩略图标题，与本地源图相符 |
|---|---:|---|
| zh-Hans | 01 | 专注，节奏尽在眼前 |
| zh-Hans | 02 | 一周专注，一眼看清 |
| zh-Hans | 03 | 让每一段专注都有分量 |
| zh-Hans | 04 | 专注与休息，各有声音 |
| en-US | 01 | Focus. Keep your rhythm. |
| en-US | 02 | See your week at a glance. |
| en-US | 03 | Make your focus time count. |
| en-US | 04 | A sound for focus. A sound for rest. |

| 原计划 A–E | 最终结果 | 本轮变化 |
|---|---|---|
| A 本地化 | PASS（已有 259/0 审计） | 已批准源码、资源未更改 |
| B 版本 / 工程 | PASS | 上传原 1.0.2（5），未重建或改版本 |
| C 测试 / 归档 | PASS（已有 215/215） | 本轮未改源码，因此不重复启动测试宿主；归档主程序 SHA 再核对相同 |
| D 截图 | PASS | 8 张源图尺寸/alpha/视觉验收保留；已上传并核对提交后的 locale 映射与顺序 |
| E 商店文案 | PASS | `python3 AppStore/validate_metadata.py` exit 0；Apple 字段保存、reload 比较与提审完成 |

归档仍为 `/Users/oyd/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive`；`shasum -a 256 .../Products/Applications/NanaFlow.app/Contents/MacOS/NanaFlow` 再核对：`abd19732001008099166356db2460a0a96f402b306ceebe868655c3a0e5c68d3`。8 张源图未修改，文件大小见上方截图表。

没有待决定的产品、素材或合规问题；后续为等待 Apple 审核结果。交付分支仅 `release/1.0.2`，最终提交和远端同 SHA 校验随 worker_done 回传；不会合入 main。

Git 交付检查：收据一致性检查通过（双语言 metadata 精确匹配、各 4 张已核对素材、清单 6/6）；首次 `git diff --cached --check` 发现 Xcode 原始日志行尾空格，提交副本仅移除行尾空格/末尾空行后复查，原始日志仍完整保留于本地 `build/release-1.0.2/evidence/submission/upload.log`。
