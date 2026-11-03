# NanaFlow 1.0.2 计划与验收标准

制定日期：2026-11-03。负责人：所有者 Nio；规划与验收：Claude；实现与自验：Codex（Orca worker）。

## 目标

1.0.1 已上线（App ID 6814738160）。1.0.2 是一次小版本，只做三件事：

1. **英文界面补全**：英文系统下仍有中文菜单项（菜单栏下拉菜单最明显，还有“返回计时器”“提醒”“自动开始”等）。
2. **重做商店截图**：现有截图来自 1.0（2），看不到 1.0.1 的次数/时长切换和分开选择提示音，分辨率也低。
3. **商店文案**：描述里的快捷键范围修正（仓库已改，商店未保存）与 1.0.2 更新说明。

不做：新功能、UI 改版、繁体中文、R1 分支合入、通知声音实现改动（另行跟进）、Widget 截图。

## 硬性约束（违反任何一条即验收失败）

- **不能影响所有者正在使用的商店版。** `/Applications/NanaFlow.app`（商店 1.0.1，bundle ID `com.nanafox.NanaFlow`）可能正在计时。不得退出、`pkill`、重启或覆盖它；不得运行 `script/build_and_run.sh`（会先杀掉同名进程）。
- **不能读写所有者的真实数据。** `~/Library/Containers/com.nanafox.NanaFlow`、`com.nanafox.NanaFlow.Widget`、`~/Library/Group Containers/group.com.nanafox.NanaFlow`、`~/Library/Preferences/com.nanafox.NanaFlow.plist` 在工作开始与结束时各做一次文件清单 + SHA-256（只读，不解码内容），两次必须一致。任何需要以生产 bundle ID 启动应用的步骤（包括以 NanaFlow.app 为宿主的单元测试）先停下来问协调者。
- 截图使用**独立 bundle ID**（如 `com.nanafox.NanaFlow.Screenshots`）和演示数据，完成后按精确 bundle ID 清理该身份的容器、偏好和 Widget 注册。
- **不对外发布**：不上传 App Store Connect、不提审、不改商店字段、不 push、不合入 main。所有工作在分支 `release/1.0.2` 上提交。
- 已有 1.0.1 历史文档保持原文，新增内容写在新文件或新小节里。

## 工作项与验收标准

### A. 英文本地化补全

- 对 `Sources/NanaFocus`、`Sources/NanaShared`（如有）、`Sources/NanaFlowWidget` 中所有用户可见的中文字符串键做完整审计，**包括运行时选择的键**（三元表达式、`String.LocalizationValue(title)` 传入的变量，如“隐藏计时器/显示计时器”“跳到休息/跳到专注”）。审计结果（键、文件、英文译文）记录在本文件末尾的附录。
- 每个键在 `en.lproj/Localizable.strings`（复数用 `.stringsdict`）中都有英文条目；英文措辞与 macOS 惯例一致（Settings…, Quit NanaFlow, Show Statistics 等）。
- 新增一个自动检查（XCTest 或 `script/` 下的脚本，接入现有测试流程）：扫描源码中的本地化键，任一键缺少英文条目即失败。先在修复前运行一次，确认它能报出这些缺失（附输出），修复后通过。
- 证据：英文环境下菜单栏菜单、计时窗口“⋯”菜单、统计页、设置页各一张截图，无中文残留。

### B. 版本号

- `project.yml` 中 `MARKETING_VERSION: "1.0.2"`、`CURRENT_PROJECT_VERSION: "5"`；用 XcodeGen 重新生成工程，`script/check_xcodegen_drift.sh` 通过。
- 应用、Widget 的 Info.plist 版本一致。

### C. 测试与构建

- 全部现有单元测试通过（在满足上面数据约束的前提下运行；若必须用生产 bundle ID 作为宿主，先问）。
- Release 配置 `xcodebuild archive` 成功，产物为 1.0.2（5），签名身份与 1.0.1 归档一致（Apple Development / Nio D，同一 Team `LTLULSL8A2`，自动签名）；本地 `exportArchive`（`method=app-store-connect`、`destination=export`，不上传）成功。协调者于 2026-11-03 澄清：原计划的 Apple Distribution 归档措辞有误；导出可用 `-allowProvisioningUpdates` 进行正常云端分发签名，若导出失败则原样记录错误并标注该子项未完成，不作绕过，由所有者后续在 Organizer 导出。归档存到 `~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive`。
- 记录归档中主程序可执行文件的 SHA-256。

### D. 商店截图

- 语言：`zh-Hans` 和 `en-US` 各一套，分别在对应系统语言/应用语言下拍摄。
- 尺寸：2880×1800，PNG 或高质量 JPEG，无透明通道（`sips -g hasAlpha` 为 no）。
- **界面像素必须来自 1.0.2 候选版本的真实代码**：可以是真实运行的截屏，也可以是用 `ImageRenderer` 以高倍率渲染的正式 SwiftUI 视图；不能手绘、拼凑控件或使用设计原型。允许把真实界面放在品牌色背景上并加一行本地化标题（营销框）。
- 窗口在画面中要足够大、清晰：计时数字在最终图里不小于 160px 高，不出现明显放大模糊。
- 内容（每种语言 4 张，顺序如下）：
  1. 正在专注的计时窗口 + 菜单栏倒计时（带今日完成数，如 `18:07 | 3`）和展开的菜单栏菜单
  2. 周统计，柱形、星期标签和“次数/时长”切换可见
  3. 月统计切到“时长”，悬停一根柱子显示数值
  4. 设置中专注与休息分别选择提示音和音量
- 演示数据：虚构、无个人信息，菜单栏不出现第三方应用、账号名、文件路径或通知。
- 文件放 `AppStore/Screenshots/1.0.2/<locale>/NN-name.png`，并在 `AppStore/screenshots.md` 新增 1.0.2 登记表（来源构建、文件名、尺寸、目视检查）。
- 不展示商店版没有入口的功能（日历、iCloud、阻断器、标签、历史列表、备份导入、全局快捷键面板、Widget）。

### E. 商店文案

- `AppStore/metadata.zh-Hans.md`、`metadata.en-US.md`：
  - 描述沿用仓库中已修正快捷键范围的版本，核对与 1.0.2 实际功能一致。
  - 新增 1.0.2 版本说明（中英文对应），只写用户可感知的真实改动（如英文界面补全）；更换商店截图不属于应用改动，不写进版本说明。
  - 字段长度符合 App Store 限制，`AppStore/validate_metadata.py` 通过。
- 新增 `AppStore/review-notes-1.0.2.txt`。
- `AppStore/upload-checklist.md` 增加 1.0.2 小节：列出上传、选择构建、替换截图、保存描述与版本说明、提审这些**由所有者确认后才执行**的步骤，均保持未勾选。

## 交付

- 分支 `release/1.0.2` 上的提交（按“测试复现 → 修复”分开提交本地化）。
- 本文件末尾追加“执行记录”：每条验收标准对应的命令、输出摘要或文件路径；生产数据前后摘要对比结果；未完成或有偏差的项如实写明。
- 完成后向协调者报告，由协调者独立复核，再交所有者确认上传与提审。

## 附录：本地化审计

审计命令：`python3 script/check_localization.py --audit build/release-1.0.2/evidence/localization-audit.md`。保守扫描三个正式源码目录的每一个中文 Swift 字符串，而不是只找 `Text("…")`：因此三元表达式两端、转入 `String.LocalizationValue(title)` / `LocalizedStringKey(title)` 的标题、单位与无入口的保留视图也纳入；另检查显式 String/NSLocalizedString 键、单位参数与通知数组的 1…10 运行时键。最终 259 个键，缺失英文 0，含中文的英文译文 0。

修复前检查（提交 `73cad7d`）exit 1，发现 31 个缺失键，原输出完整保留为 `Plans/evidence-1.0.2/localization-before.txt`；修复与动态字符串本地化单独提交于 `5837636`。后续补上分钟缩写和 `.stringsdict` 的 1 round / 4 rounds，并保证复数规则跟随 App 语言。所有条目与来源如下；通知范围标记为 runtime range。

| Key | Source | English |
|---|---|---|
| %lld 分钟 | Sources/NanaFocus/StatisticsView.swift:1030 | %lld minutes |
| 25分钟的短时间是保持专注的理想选择。 | Sources/NanaFocus/HelpViews.swift:93 | A short timespan of 25 minutes is ideal to stay focused. |
| NanaFlow 会话.%@ | Sources/NanaFocus/StatisticsView.swift:679 | NanaFlow Sessions.%@ |
| NanaFlow 会话的标题。 | Sources/NanaFocus/AutomationIntents.swift:128 | Title of the NanaFlow session. |
| NanaFlow 基于流行的时间管理方法，称为番茄工作法。 | Sources/NanaFocus/HelpViews.swift:87 | NanaFlow is based on a popular focus timer method – the Pomodoro Technique. By default it consists of four simple steps. |
| NanaFlow 快捷方式 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:189 | NanaFlow Shortcut |
| NanaFlow将您的工作流划分为具有已定义中断的部分，使您可以轻松保持专注。 | Sources/NanaFocus/WelcomeView.swift:33 | NanaFlow divides your work into sections with defined breaks to help you stay focused and productive. |
| about_version_format | Sources/NanaFocus/HelpViews.swift:43 | Version %@ |
| breakCompletedBody1 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Your next NanaFlow is waiting. |
| breakCompletedBody10 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | You're all set to dive back in. |
| breakCompletedBody2 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Feeling motivated? Great! |
| breakCompletedBody3 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Let's get back to work. |
| breakCompletedBody4 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Let's get things done. |
| breakCompletedBody5 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Come on. Let's do it! |
| breakCompletedBody6 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Time to get back to NanaFlow. |
| breakCompletedBody7 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Back to productivity! You're ready. |
| breakCompletedBody8 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Let's refocus and get started. |
| breakCompletedBody9 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Back to NanaFlow. Let's go. |
| breakCompletedTitle1 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Your break is over. |
| breakCompletedTitle10 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Break is up! Focus time starts now. |
| breakCompletedTitle2 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Ready to focus again? |
| breakCompletedTitle3 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Your time to relax is over. |
| breakCompletedTitle4 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Enough relaxation. Let's focus! |
| breakCompletedTitle5 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Well, that was a nice break. |
| breakCompletedTitle6 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Break's done. Time to work! |
| breakCompletedTitle7 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Back to it! Let's focus. |
| breakCompletedTitle8 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Let's get back into the groove. |
| breakCompletedTitle9 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Hope you enjoyed your break! |
| duration_hms_format | Sources/NanaFocus/StatisticsView.swift:1021 | %1$lldh %2$lldm %3$llds |
| duration_minutes_unit | Sources/NanaFocus/CustomDurationView.swift:52<br>Sources/NanaFocus/CustomDurationView.swift:53<br>Sources/NanaFocus/CustomDurationView.swift:54 | min |
| duration_rounds_format | Sources/NanaFocus/CustomDurationView.swift:8 | {'rounds': {'one': '%lld round', 'other': '%lld rounds', 'NSStringFormatSpecTypeKey': 'NSStringPluralRuleType', 'NSStringFormatValueTypeKey': 'lld'}, 'NSStringLocalizedFormatKey': '%#@rounds@'} |
| duration_value_unit_format | Sources/NanaFocus/CustomDurationView.swift:14 | %1$lld %2$@ |
| flowCompletedBody1 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | It's time to have a break. |
| flowCompletedBody10 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Break time! You've earned it. |
| flowCompletedBody2 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Time to relax and have a break. |
| flowCompletedBody3 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Let's have a break. |
| flowCompletedBody4 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | It's the perfect moment for a break. |
| flowCompletedBody5 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Let's relax for a few minutes! |
| flowCompletedBody6 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | You've earned a well-deserved break! |
| flowCompletedBody7 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Recharge time! Enjoy a break. |
| flowCompletedBody8 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Take a deep breath and unwind. |
| flowCompletedBody9 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Let's pause and refresh. |
| flowCompletedTitle1 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Well done! Your NanaFlow is complete. |
| flowCompletedTitle10 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Another session completed successfully. |
| flowCompletedTitle2 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Great work session! |
| flowCompletedTitle3 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Good job! Session finished. |
| flowCompletedTitle4 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | You've done great this NanaFlow! |
| flowCompletedTitle5 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Session complete. Awesome! |
| flowCompletedTitle6 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Great effort! NanaFlow complete. |
| flowCompletedTitle7 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Nice work! NanaFlow finished. |
| flowCompletedTitle8 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | You crushed it! NanaFlow is over. |
| flowCompletedTitle9 | Sources/NanaFocus/SessionNotificationScheduler.swift (runtime range) | Way to go! Your session is done. |
| menu_bar_accessibility_format | Sources/NanaFocus/NanaFocusApp.swift:7 | %1$@, %2$@ remaining |
| selected | Sources/NanaFocus/StatisticsView.swift:215<br>Sources/NanaFocus/StatisticsView.swift:306 | Selected |
| statistics_count_format | Sources/NanaFocus/StatisticsView.swift:73 | %@ completed |
| statistics_next_period | Sources/NanaFocus/StatisticsView.swift:267 | Next period |
| statistics_previous_period | Sources/NanaFocus/StatisticsView.swift:267 | Previous period |
| today_completed_focus_format | Sources/NanaFocus/NanaFocusApp.swift:13 | %lld focus sessions completed today |
| 一旦启动，请进行提交。这有助于避免分心。 | Sources/NanaFocus/HelpViews.swift:94 | Once started, commit to it. This helps battle distractions. |
| 专注 | Sources/NanaFocus/CustomDurationView.swift:52<br>Sources/NanaFocus/CustomDurationView.swift:65 | Focus |
| 专注、休息、继续。 | Sources/NanaFocus/HelpViews.swift:39 | Focus. Rest. Repeat. |
| 专注于任务 | Sources/NanaFocus/HelpViews.swift:94 | Focus on the task |
| 专注完成声音 | Sources/NanaFocus/TimerSettingsView.swift:60 | Focus completion sound |
| 专注时播放滴答声 | Sources/NanaFocus/TimerSettingsView.swift:73 | Play ticking sound during focus |
| 为您的 NanaFlows 和休息设置自定义持续时间。 | Sources/NanaFocus/CustomDurationView.swift:22 | Set custom durations for your NanaFlows and breaks. |
| 享受短暂的5分钟休息。站起来，伸展双腿，喝水。 | Sources/NanaFocus/HelpViews.swift:98 | Enjoy a short 5-minute break. Stand up, stretch your legs, drink water. |
| 今天 | Sources/NanaShared/NanaFlowShared.swift:111 | Today |
| 从您要关注的待办事项列表中选择一项任务。 | Sources/NanaFocus/HelpViews.swift:92 | Pick a task you want to focus on from your to-do list. |
| 以励志名言开始新的一天。 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:140 | Get daily motivational quotes. |
| 休息 | Sources/NanaFocus/CustomDurationView.swift:64<br>Sources/NanaFocus/SessionExporter.swift:81<br>Sources/NanaFocus/StatisticsView.swift:1039<br>Sources/NanaFocus/TimerController.swift:104<br>Sources/NanaFocus/TimerController.swift:454<br>Sources/NanaFocus/TimerController.swift:508 | Break |
| 休息完成声音 | Sources/NanaFocus/TimerSettingsView.swift:61 | Break completion sound |
| 会话标题 | Sources/NanaFocus/AutomationIntents.swift:127 | Session Title |
| 会话详情 | Sources/NanaFocus/StatisticsView.swift:760 | Session Details |
| 你确定要删除此会话吗？ | Sources/NanaFocus/StatisticsView.swift:885 | Are you sure you want to delete this session? |
| 停止 | Sources/NanaFocus/TimerView.swift:189 | Stop |
| 允许通知 | Sources/NanaFocus/PermissionViews.swift:9<br>Sources/NanaFocus/TimerSettingsView.swift:59 | Allow Notifications |
| 全局快捷键 | Sources/NanaFocus/TimerSettingsView.swift:437 | Global Shortcuts |
| 全局快捷键或系统快捷键是激活的，可以在任何应用程序当前处于焦点时触发。 | Sources/NanaFocus/TimerSettingsView.swift:405 | Global shortcuts or System-wide shortcuts are active and can be triggered regardless of which application is currently in focus. |
| 全部关闭 | Sources/NanaFocus/SessionNotificationScheduler.swift:420 | Close All |
| 关于 NanaFlow | Sources/NanaFocus/HelpViews.swift:14<br>Sources/NanaFocus/NanaFocusApp.swift:181<br>Sources/NanaFocus/TimerOptionsMenuContent.swift:17 | About NanaFlow |
| 关闭 | Sources/NanaFocus/SessionNotificationScheduler.swift:419<br>Sources/NanaFocus/TimerView.swift:218 | Close |
| 关闭全屏休息 | Sources/NanaFocus/FullscreenBreakView.swift:75 | Exit Fullscreen Break |
| 关闭窗口 | Sources/NanaFocus/TimerSettingsView.swift:382 | Close window |
| 关闭通知也会关闭完成声音。音量受系统设置影响。 | Sources/NanaFocus/TimerSettingsView.swift:67 | Turning off notifications also turns off completion sounds. System volume applies. |
| 减少%@ | Sources/NanaFocus/CustomDurationView.swift:135 | Decrease %@ |
| 分钟 | Sources/NanaFocus/StatisticsView.swift:983<br>Sources/NanaFlowWidget/NanaFlowWidgets.swift:12<br>Sources/NanaFlowWidget/NanaFlowWidgets.swift:125 | Minutes |
| 切换计时器 | Sources/NanaFocus/AutomationIntents.swift:58 | Toggle Timer |
| 删除 | Sources/NanaFocus/StatisticsView.swift:887 | Delete |
| 删除会话 | Sources/NanaFocus/StatisticsView.swift:865 | Delete Session |
| 单位 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:51 | Unit |
| 取消 | Sources/NanaFocus/StatisticsView.swift:635<br>Sources/NanaFocus/StatisticsView.swift:876<br>Sources/NanaFocus/StatisticsView.swift:886 | Cancel |
| 只统计今天已完成的专注 | Sources/NanaFocus/TimerSettingsView.swift:50 | Only counts focus sessions completed today |
| 启动 | Sources/NanaFocus/TimerSettingsView.swift:34 | Launch |
| 启动或停止计时器 | Sources/NanaFocus/TimerSettingsView.swift:453 | Start or stop timer |
| 启动或恢复会话 | Sources/NanaFocus/AutomationIntents.swift:34 | Start or Resume Session |
| 启动或恢复当前 NanaFlow 会话或休息。 | Sources/NanaFocus/AutomationIntents.swift:35 | Starts or resumes the current NanaFlow session or break. |
| 启动时显示窗口 | Sources/NanaFocus/TimerSettingsView.swift:36 | Show Window at Launch |
| 启动计时器 | Sources/NanaFocus/HelpViews.swift:93 | Start the timer |
| 吹口哨 | Sources/NanaFocus/TimerSettingsView.swift:612 | Whistle |
| 周 | Sources/NanaFocus/StatisticsView.swift:1049 | Week |
| 和弦 | Sources/NanaFocus/TimerSettingsView.swift:607 | Chord |
| 唱钵 | Sources/NanaFocus/TimerSettingsView.swift:605 | Bowl |
| 在启动时显示此窗口 | Sources/NanaFocus/WelcomeView.swift:48 | Show this window at launch |
| 在系统设置中禁用通知。 转到系统设置以允许通知，然后重试。 | Sources/NanaFocus/PermissionViews.swift:13 | Notifications are disabled in System Settings. Go to System Settings to allow notifications and try again. |
| 在运行和暂停之间切换 NanaFlow 计时器。 | Sources/NanaFocus/AutomationIntents.swift:59 | Toggles the timer from running to stopped or vice versa. |
| 增加%@ | Sources/NanaFocus/CustomDurationView.swift:144 | Increase %@ |
| 天 | Sources/NanaFocus/StatisticsView.swift:1048 | Day |
| 好 | Sources/NanaFocus/StatisticsView.swift:644<br>Sources/NanaFocus/TimerSettingsView.swift:98<br>Sources/NanaFocus/TimerView.swift:108 | OK |
| 好的 | Sources/NanaFocus/PermissionViews.swift:85<br>Sources/NanaFocus/WelcomeView.swift:41 | OK |
| 完成 | Sources/NanaFocus/CustomDurationView.swift:97<br>Sources/NanaFocus/HelpViews.swift:47<br>Sources/NanaFocus/TimerSettingsView.swift:392 | Done |
| 完成你的第一次会话，在这里查看详细概览。 | Sources/NanaFocus/StatisticsView.swift:545 | Complete your first NanaFlow to see a detailed overview of your sessions. |
| 完整备份 | Sources/NanaFocus/StatisticsView.swift:609 | Full Backup |
| 导入备份… | Sources/NanaFocus/StatisticsView.swift:613 | Import Backup… |
| 导出 | Sources/NanaFocus/StatisticsView.swift:611 | Export |
| 已停止 | Sources/NanaFocus/StatisticsView.swift:750 | Stopped |
| 已启动 | Sources/NanaFocus/StatisticsView.swift:738<br>Sources/NanaFocus/StatisticsView.swift:855 | Started |
| 已完成 | Sources/NanaFocus/StatisticsView.swift:739<br>Sources/NanaFocus/StatisticsView.swift:856 | Completed |
| 已恢复 | Sources/NanaFocus/StatisticsView.swift:751 | Resumed |
| 年 | Sources/NanaFocus/StatisticsView.swift:1051 | Year |
| 开始 | Sources/NanaFocus/FullscreenBreakView.swift:58<br>Sources/NanaFocus/NanaFocusApp.swift:156<br>Sources/NanaFocus/SessionNotificationScheduler.swift:30<br>Sources/NanaFocus/TimerView.swift:189 | Start |
| 开始休息 | Sources/NanaFocus/TimerOptionsMenuContent.swift:21 | Start Break |
| 录制快捷键 | Sources/NanaFocus/KeyboardShortcutRecorder.swift:35 | Record shortcut |
| 循环 | Sources/NanaFocus/CustomDurationView.swift:55 | Cycle |
| 快速打开 NanaFlow。 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:190 | A quick way to open NanaFlow. |
| 怎么运行的 | Sources/NanaFocus/HelpViews.swift:83 | How It Works |
| 总用时 | Sources/NanaFocus/SessionHistory.swift:86 | Total Time |
| 总计次数 | Sources/NanaFocus/SessionHistory.swift:85 | Total Count |
| 恢复默认 | Sources/NanaFocus/TimerSettingsView.swift:441 | Restore Defaults |
| 您确定要重置您的统计数据吗？ | Sources/NanaFocus/StatisticsView.swift:634 | Are you sure you want to reset your statistics? |
| 所有会话 | Sources/NanaFocus/StatisticsView.swift:591 | All Sessions |
| 打开 | Sources/NanaFocus/SessionNotificationScheduler.swift:32 | Open |
| 打开 NanaFlow | Sources/NanaShared/NanaFlowShared.swift:194<br>Sources/NanaFlowWidget/NanaFlowWidgets.swift:182 | Open NanaFlow |
| 打开 NanaFlow 应用。 | Sources/NanaShared/NanaFlowShared.swift:195 | Open the NanaFlow app. |
| 打开 NanaFlow 计时器。 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:206 | Open the NanaFlow timer. |
| 打开设置 | Sources/NanaFocus/TimerSettingsView.swift:383 | Open settings |
| 打断 | Sources/NanaFocus/StatisticsView.swift:744<br>Sources/NanaFocus/StatisticsView.swift:858 | Interruptions |
| 提醒 | Sources/NanaFocus/TimerSettingsView.swift:58 | Alerts |
| 改为稍事休息 | Sources/NanaFocus/HelpViews.swift:115 | Take a long break |
| 数量 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:11 | Count |
| 文件 | Sources/NanaFocus/SessionNotificationScheduler.swift:417 | File |
| 新Fullscreen窗口 | Sources/NanaFocus/NanaFlowCommands.swift:9<br>Sources/NanaFocus/SessionNotificationScheduler.swift:418 | New Fullscreen Window |
| 无 | Sources/NanaFocus/TimerSettingsView.swift:601 | None |
| 无法保存 | Sources/NanaFocus/TimerView.swift:102 | Unable to Save |
| 无法保存会话记录：%@ | Sources/NanaFocus/TimerController.swift:483 | Unable to save session history: %@ |
| 无法保存计时状态：%@ | Sources/NanaFocus/TimerController.swift:496 | Unable to save timer state: %@ |
| 无法保存设置：%@ | Sources/NanaFocus/TimerController.swift:292 | Unable to save settings: %@ |
| 无法处理数据 | Sources/NanaFocus/StatisticsView.swift:640 | Unable to Process Data |
| 无法打开导出窗口。 | Sources/NanaFocus/StatisticsView.swift:673<br>Sources/NanaFocus/StatisticsView.swift:699 | Unable to open the export window. |
| 无法更新登录项 | Sources/NanaFocus/TimerSettingsView.swift:94 | Unable to Update Login Item |
| 时长 | Sources/NanaFocus/CustomDurationView.swift:50<br>Sources/NanaFocus/StatisticsView.swift:60<br>Sources/NanaFocus/StatisticsView.swift:731<br>Sources/NanaFocus/StatisticsView.swift:860 | Duration |
| 时长（含中断） | Sources/NanaFocus/StatisticsView.swift:734 | Duration With Interruptions |
| 显示今天完成的 NanaFlow 数量或专注分钟数。 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:46 | Show today's completed NanaFlows or focused minutes. |
| 显示今日完成数 | Sources/NanaFocus/TimerSettingsView.swift:46 | Show today’s completed count |
| 显示您的每日统计数据。 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:113 | Shows your total completed NanaFlows for the day. |
| 显示或隐藏窗口 | Sources/NanaFocus/TimerSettingsView.swift:456 | Show or hide window |
| 显示未完成 | Sources/NanaFocus/StatisticsView.swift:604 | Show Incomplete |
| 显示每日励志引语。 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:57 | Show a daily motivational quote. |
| 显示统计 | Sources/NanaFocus/NanaFocusApp.swift:165 | Show Statistics |
| 显示计时器 | Sources/NanaFocus/NanaFocusApp.swift:161 | Show Timer |
| 暂停 | Sources/NanaFocus/FullscreenBreakView.swift:57<br>Sources/NanaFocus/NanaFocusApp.swift:156 | Pause |
| 暂停会话 | Sources/NanaFocus/AutomationIntents.swift:46 | Pause Session |
| 暂停当前 NanaFlow 会话或休息。 | Sources/NanaFocus/AutomationIntents.swift:47 | Pauses the current NanaFlow session or break. |
| 更多 | Sources/NanaFocus/StatisticsView.swift:627 | More |
| 月 | Sources/NanaFocus/StatisticsView.swift:1050 | Month |
| 未完成 | Sources/NanaFocus/StatisticsView.swift:992 | Not Completed |
| 未完成会话不能编辑 | Sources/NanaFocus/StatisticsView.swift:770 | Incomplete sessions cannot be edited |
| 未找到会话 | Sources/NanaFocus/StatisticsView.swift:542 | No Sessions Found |
| 未知错误 | Sources/NanaFocus/StatisticsView.swift:646<br>Sources/NanaFocus/TimerSettingsView.swift:100<br>Sources/NanaFocus/TimerView.swift:110 | Unknown Error |
| 本地快捷键 | Sources/NanaFocus/TimerSettingsView.swift:411 | Local Shortcuts |
| 本地快捷键或特定应用程序快捷键仅在应用程序处于焦点时才激活。 | Sources/NanaFocus/TimerSettingsView.swift:500 | Local shortcuts or Application-specific shortcuts are only active when the application is in focus. |
| 标题 | Sources/NanaFocus/StatisticsView.swift:853 | Title |
| 次数 | Sources/NanaFocus/StatisticsView.swift:60 | Count |
| 欢迎来到NanaFlow | Sources/NanaFocus/WelcomeView.swift:28 | Welcome to NanaFlow |
| 此操作不能撤销。 | Sources/NanaFocus/StatisticsView.swift:638<br>Sources/NanaFocus/StatisticsView.swift:894 | This can't be undone. |
| 每四个休息时间都是一个较长的，更具恢复性的30分钟休息时间。 | Sources/NanaFocus/HelpViews.swift:117 | Every fourth break is a long, more restorative, 30-minute break. |
| 每日励志 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:139 | Daily Motivation |
| 每日引语组件 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:56 | Daily Quote Widget |
| 每日统计 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:112 | Daily Statistics |
| 每日统计组件 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:45 | Daily Statistics Widget |
| 没有符合当前筛选条件的会话。 | Sources/NanaFocus/StatisticsView.swift:546 | No sessions match the current filter. |
| 波纹 | Sources/NanaFocus/TimerSettingsView.swift:611 | Ripple |
| 浅色 | Sources/NanaFocus/TimerSettingsView.swift:584 | Light |
| 深色 | Sources/NanaFocus/TimerSettingsView.swift:585 | Dark |
| 添加 | Sources/NanaFocus/StatisticsView.swift:601<br>Sources/NanaFocus/StatisticsView.swift:877 | Add |
| 清除过滤 | Sources/NanaFocus/StatisticsView.swift:549 | Clear Filter |
| 激活全局键盘快捷键 | Sources/NanaFocus/TimerSettingsView.swift:399 | Enable Global Hotkeys |
| 登录时启动 | Sources/NanaFocus/TimerSettingsView.swift:35 | Launch at Login |
| 短休息 | Sources/NanaFocus/CustomDurationView.swift:53 | Short Break |
| 短暂休息 | Sources/NanaFocus/AutomationIntents.swift:20 | Short Break |
| 稍作休息 | Sources/NanaFocus/HelpViews.swift:97 | Take a short break |
| 竖琴 | Sources/NanaFocus/TimerSettingsView.swift:608 | Harp |
| 第 %1$lld 轮，共 %2$lld 轮 | Sources/NanaFocus/TimerController.swift:111 | Session %1$lld of %2$lld |
| 类型 | Sources/NanaFocus/StatisticsView.swift:730<br>Sources/NanaFocus/StatisticsView.swift:848 | Type |
| 系统 | Sources/NanaFocus/TimerSettingsView.swift:583 | System |
| 组件颜色 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:22 | Widget Color |
| 统计 | Sources/NanaFocus/TimerOptionsMenuContent.swift:14<br>Sources/NanaFocus/TimerView.swift:274 | Statistics |
| 统计单位 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:9 | Statistics Unit |
| 统计图表 | Sources/NanaFocus/StatisticsView.swift:223 | Statistics chart |
| 编辑 | Sources/NanaFocus/StatisticsView.swift:770<br>Sources/NanaFocus/StatisticsView.swift:877 | Edit |
| 脉冲 | Sources/NanaFocus/TimerSettingsView.swift:610 | Pulse |
| 自动开始 | Sources/NanaFocus/CustomDurationView.swift:62 | Auto-Start |
| 自定义持续时间 | Sources/NanaFocus/CustomDurationView.swift:21 | Custom Durations |
| 获取会话标题 | Sources/NanaFocus/AutomationIntents.swift:113 | Get Session Title |
| 获取剩余秒数 | Sources/NanaFocus/AutomationIntents.swift:93 | Get Remaining Seconds |
| 获取当前 NanaFlow 会话或休息的剩余秒数。 | Sources/NanaFocus/AutomationIntents.swift:94 | Gets the remaining seconds of the current NanaFlow session or break. |
| 获取当前 NanaFlow 会话标题。 | Sources/NanaFocus/AutomationIntents.swift:114 | Gets the current session title. |
| 获取当前 NanaFlow 阶段。 | Sources/NanaFocus/AutomationIntents.swift:104 | Gets the current phase. |
| 获取阶段 | Sources/NanaFocus/AutomationIntents.swift:103 | Get Phase |
| 菜单 | Sources/NanaFocus/TimerView.swift:302<br>Sources/NanaFocus/TimerView.swift:303 | Menu |
| 菜单栏 | Sources/NanaFocus/TimerSettingsView.swift:44 | Menu Bar |
| 计时开始后隐藏窗口 | Sources/NanaFocus/TimerSettingsView.swift:38 | Hide window when timer starts |
| 计时设置 | Sources/NanaFocus/CustomDurationView.swift:85<br>Sources/NanaFocus/TimerOptionsMenuContent.swift:11 | Timer Settings |
| 计时设置… | Sources/NanaFocus/NanaFocusApp.swift:179 | Timer Settings… |
| 设置 | Sources/NanaFocus/TimerSettingsView.swift:106 | Settings |
| 设置 NanaFlow 会话标题。 | Sources/NanaFocus/AutomationIntents.swift:124 | Sets the title for the NanaFlow session. |
| 设置… | Sources/NanaFocus/NanaFocusApp.swift:180<br>Sources/NanaFocus/TimerOptionsMenuContent.swift:16 | Settings… |
| 设置会话标题 | Sources/NanaFocus/AutomationIntents.swift:123 | Set Session Title |
| 跳到专注 | Sources/NanaFocus/NanaFocusApp.swift:168 | Skip to Focus |
| 跳到休息 | Sources/NanaFocus/NanaFocusApp.swift:168 | Skip to Break |
| 跳过 | Sources/NanaFocus/SessionNotificationScheduler.swift:31 | Skip |
| 跳过休息时间 | Sources/NanaFocus/FullscreenBreakView.swift:49<br>Sources/NanaFocus/TimerView.swift:234 | Skip Break |
| 跳过会话 | Sources/NanaFocus/AutomationIntents.swift:69 | Skip Session |
| 跳过会话或休息 | Sources/NanaFocus/TimerSettingsView.swift:454 | Skip session or break |
| 跳过当前 NanaFlow 会话或休息。 | Sources/NanaFocus/AutomationIntents.swift:70 | Skips the current NanaFlow session or break. |
| 轮 | Sources/NanaFocus/CustomDurationView.swift:4<br>Sources/NanaFocus/CustomDurationView.swift:55 | Rounds |
| 载入更多 | Sources/NanaFocus/StatisticsView.swift:574 | Load More |
| 输入会话标题 | Sources/NanaFocus/AutomationIntents.swift:129 | Enter session title |
| 输入快捷键… | Sources/NanaFocus/KeyboardShortcutRecorder.swift:45 | Enter shortcut… |
| 返回 | Sources/NanaFocus/CustomDurationView.swift:95<br>Sources/NanaFocus/HelpViews.swift:23<br>Sources/NanaFocus/TimerSettingsView.swift:116 | Back |
| 返回专注 | Sources/NanaFocus/TimerOptionsMenuContent.swift:21 | Return to Focus |
| 返回所有会话 | Sources/NanaFocus/StatisticsView.swift:765 | Back to All Sessions |
| 返回统计 | Sources/NanaFocus/StatisticsView.swift:596 | Back to Statistics |
| 返回计时器 | Sources/NanaFocus/StatisticsView.swift:176 | Back to Timer |
| 退出 NanaFlow | Sources/NanaFocus/NanaFocusApp.swift:183 | Quit NanaFlow |
| 选择任务 | Sources/NanaFocus/HelpViews.swift:92 | Choose a task |
| 重复4次 | Sources/NanaFocus/HelpViews.swift:105 | Repeat 4 times, then... |
| 重新开始 | Sources/NanaFocus/NanaFocusApp.swift:177 | Restart Cycle |
| 重新开始 NanaFlow 会话周期。 | Sources/NanaFocus/AutomationIntents.swift:82 | Resets the current session cycle. |
| 重新开始周期 | Sources/NanaFocus/TimerView.swift:254 | Restart Cycle |
| 重置 | Sources/NanaFocus/StatisticsView.swift:636 | Reset |
| 重置周期 | Sources/NanaFocus/AutomationIntents.swift:81 | Reset Cycle |
| 重置循环 | Sources/NanaFocus/TimerSettingsView.swift:455 | Reset cycle |
| 重置统计数据 | Sources/NanaFocus/StatisticsView.swift:126 | Reset Statistics |
| 重要事件 | Sources/NanaFocus/TimerSettingsView.swift:609 | Milestone |
| 铃声 | Sources/NanaFocus/TimerSettingsView.swift:603 | Bell |
| 铃铛 | Sources/NanaFocus/TimerSettingsView.swift:604 | Bells |
| 键盘快捷键 | Sources/NanaFocus/TimerSettingsView.swift:389 | Keyboard Shortcuts |
| 长休息 | Sources/NanaFocus/CustomDurationView.swift:54 | Long Break |
| 长时间停顿 | Sources/NanaFocus/AutomationIntents.swift:21<br>Sources/NanaFocus/SessionExporter.swift:82<br>Sources/NanaFocus/StatisticsView.swift:1040<br>Sources/NanaFocus/TimerController.swift:105<br>Sources/NanaFocus/TimerController.swift:458<br>Sources/NanaFocus/TimerController.swift:509 | Long Break |
| 闹钟 | Sources/NanaFocus/TimerSettingsView.swift:602 | Alarm Clock |
| 阶段 | Sources/NanaFocus/AutomationIntents.swift:17 | Phase |
| 隐藏计时器 | Sources/NanaFocus/NanaFocusApp.swift:161 | Hide Timer |
| 音量 | Sources/NanaFocus/TimerSettingsView.swift:63<br>Sources/NanaFocus/TimerSettingsView.swift:286 | Volume |
| 颜色 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:48<br>Sources/NanaFlowWidget/NanaFlowWidgets.swift:59 | Color |
| 风格 1 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:24 | Style 1 |
| 风格 2 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:25 | Style 2 |
| 风格 3 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:26 | Style 3 |
| 风格 4 | Sources/NanaFlowWidget/NanaFlowWidgets.swift:27 | Style 4 |
| 风铃 | Sources/NanaFocus/TimerSettingsView.swift:606 | Chime |

## 执行记录

执行日期：2026-11-03，UTC+08。本地分支 `release/1.0.2`，基线 `d029f6417706809df20e76c440b13770946e5aeb`；最终 UI 源码提交 `8fd36e09eda6a8299e549058e544029e165f71de`，提交测试复现 `73cad7d` 与翻译修复 `5837636` 分开。最终提交号由 worker_done 收据报告。Xcode 27.1（27A9275），XcodeGen 2.46.0。

| 验收项 | 结果 | 执行命令 / 检查 | 输出摘要 | 证据路径 |
|---|---|---|---|---|
| A1 全量键与运行时选键 | PASS | python3 script/check_localization.py --audit build/release-1.0.2/evidence/localization-audit.md | 259 键；含三元两端、变量标题/单位、通知 1…10 范围；审计表在本附录 | script/check_localization.py；build/release-1.0.2/evidence/localization-audit.md |
| A2 英文条目与复数 | PASS | python3 script/check_localization.py; plutil -lint Sources/NanaFocus/{en,zh-Hans}.lproj/Localizable.{strings,stringsdict} | 缺失 0，非英文 0；1 round / 4 rounds 测试通过，分钟使用 min，Settings… / Quit NanaFlow / Show Statistics 符合菜单用语 | Sources/NanaFocus/en.lproj/；Plans/evidence-1.0.2/localization-plutil.txt |
| A3 检查先失败后通过并接入测试 | PASS | python3 script/check_localization.py; script/test.sh | 修复前 exit 1：31 个缺失（保留原输出）；修复后 exit 0；LocalizationAuditTests 在正常 XCTest 中执行同一检查 | 提交 73cad7d → 5837636；Plans/evidence-1.0.2/localization-before.txt；Tests/NanaFocusTests/LocalizationAuditTests.swift |
| A4 英文四面截图 | PASS | python3 script/render_release_screenshots.py；逐张 view_image 目视检查 | 菜单栏菜单、计时 ⋯ 菜单、统计、设置均无中文残留 | AppStore/Screenshots/1.0.2/en-US/{01-focus-menu,02-week-count,04-completion-sounds}.png；Plans/evidence-1.0.2/A-en-timer-options.png |
| B1 版本与重新生成 | PASS | PATH=/opt/homebrew/bin:$PATH xcodegen generate | XcodeGen 2.46.0；MARKETING_VERSION=1.0.2 / CURRENT_PROJECT_VERSION=5 | project.yml；NanaFlow.xcodeproj；build/release-1.0.2/evidence/xcodegen.txt |
| B2 无工程漂移 | PASS | PATH=/opt/homebrew/bin:$PATH script/check_xcodegen_drift.sh | exit 0：NanaFlow.xcodeproj matches project.yml (no drift) | Plans/evidence-1.0.2/drift.txt |
| B3 App / Widget 有效 Info 版本 | PASS | python3 script/verify_release_archive.py --archive … --previous … --export-app … --package … --output build/release-1.0.2/evidence/archive-verification.json | 两个归档 bundle 的 Info 均为 1.0.2（5），ID 保持正式 App / Widget | Plans/evidence-1.0.2/archive-verification.json |
| C1 全部单元测试 | PASS | script/test.sh | 214 项 / 0 失败；212 个现有测试全部保留，新增本地化 gate 与复数测试；独立宿主和 App Group；无排除测试 | build/release-1.0.2/evidence/tests-final.txt；Plans/evidence-1.0.2/tests-summary.txt |
| C2 Release archive | PASS | xcodebuild archive -project NanaFlow.xcodeproj -scheme NanaFlow -configuration Release -destination 'generic/platform=macOS' -archivePath ~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive -derivedDataPath build/release-1.0.2/ArchiveDerivedData | ARCHIVE SUCCEEDED；universal arm64+x86_64；Apple Development: Nio D / LTLULSL8A2，与 1.0.1 archive 相同（协调者已修正签名标准） | ~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive；build/release-1.0.2/evidence/archive-final.txt |
| C3 本地 app-store-connect 导出 | PASS | xcodebuild -exportArchive -archivePath ~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive -exportPath build/release-1.0.2/ExportRelease -exportOptionsPlist build/release-1.0.2/ExportOptions.plist -allowProvisioningUpdates | EXPORT SUCCEEDED；ExportOptions 为 destination=export；App 与 Widget 为 Apple Distribution / LTLULSL8A2，pkg 签名通过；未上传 | build/release-1.0.2/ExportRelease/NanaFlow.pkg；build/release-1.0.2/evidence/export-final.txt；Plans/evidence-1.0.2/archive-verification.json |
| C4 可执行文件 SHA-256 | PASS | python3 script/verify_release_archive.py --archive … --previous … --export-app … --package … --output build/release-1.0.2/evidence/archive-verification.json | 850975fb37e03da0bb4e8405a3a0efdb3e18142b27efe0a15b8d124f9b537e93 | 归档 Products/Applications/NanaFlow.app/Contents/MacOS/NanaFlow |
| D1 两种语言独立拍摄 | PASS | python3 script/render_release_screenshots.py | en-US: AppleLanguages=en / AppleLocale=en_US；zh-Hans: zh-Hans / zh_Hans；各 4 张 | build/release-1.0.2/evidence/screenshots-final.txt；script/ReleaseScreenshots.swift |
| D2 尺寸 / 格式 / 无 alpha | PASS | sips -g pixelWidth -g pixelHeight -g hasAlpha AppStore/Screenshots/1.0.2/*/*.png | 全部 2880×1800 PNG，hasAlpha=no | Plans/evidence-1.0.2/screenshot-properties.txt |
| D3 正式代码真实界面像素 | PASS | python3 script/render_release_screenshots.py | 正式 TimerView / StatisticsView / TimerSettingsView / MenuBarStatusContent / AppStatusItemService.makeMenu；ImageRenderer 或原生窗口缓存 4×；没有原型/控件重画 | script/ReleaseScreenshots.swift；AppStore/Screenshots/1.0.2/manifest.json |
| D4 清晰度与计时数字高度 | PASS | swift script/verify_release_screenshots.swift AppStore/Screenshots/1.0.2 | 两种语言的最终图中数字 ink 高均为 203px ≥160px；源 UI 1520×1088，最终保持同等像素尺寸 | Plans/evidence-1.0.2/screenshots-verify.txt |
| D5-1 专注 + 菜单栏菜单 | PASS | python3 script/render_release_screenshots.py；逐张目视检查 | 18:07 正在专注（暂停图标），菜单栏 18:07 \| 3，展开正式菜单 | AppStore/Screenshots/1.0.2/*/01-focus-menu.png |
| D5-2 周统计 | PASS | python3 script/render_release_screenshots.py；逐张目视检查 | W 选中，7 根柱、星期标签及 Count/Duration 或 次数/时长可见 | AppStore/Screenshots/1.0.2/*/02-week-count.png |
| D5-3 月时长 + hover | PASS | python3 script/render_release_screenshots.py；逐张目视检查 | M 选中、时长选中、31 根柱；正式 tooltip 状态显示 2 hr 50 min / 2 小时 50 分钟 | AppStore/Screenshots/1.0.2/*/03-month-duration.png |
| D5-4 分开提示音 + 音量 | PASS | python3 script/render_release_screenshots.py；逐张目视检查 | Focus/Break completion sound 分别 Chime/Bowl（风铃/唱钵），Volume 50% 完整可读；原生滚动到底 | AppStore/Screenshots/1.0.2/*/04-completion-sounds.png |
| D6 演示数据 / 隐私边界 | PASS | python3 script/render_release_screenshots.py；源码与图片检查 | 记录、偏好、计时器、通知/声音端口均内存 mock；仅 NanaFlow 菜单栏状态；无账号、路径、第三方菜单或通知 | script/ReleaseScreenshots.swift；script/run_isolated_tests.py |
| D7 路径 / 登记表 | PASS | python3 build/release-1.0.2/write_release_records.py | 八张图片按 NN 顺序落盘；新增 1.0.2 登记表，大小与 SHA 记录在 manifest；没有覆盖 1.0 历史截图 | AppStore/screenshots.md；AppStore/Screenshots/1.0.2/manifest.json |
| D8 不展示未开放功能 | PASS | 逐张 view_image；核对 TimerView / TimerSettingsView / TimerOptionsMenuContent | 只显示正式入口；无日历、iCloud、阻断器、标签、历史列表、备份导入、全局快捷键面板或 Widget | 八张最终 PNG；AppStore/review-notes-1.0.2.txt |
| E1 描述与实际功能一致 | PASS | git diff d029f64 -- AppStore/metadata.*.md；核对正式路由源码 | 描述沿用已修正的应用内快捷键范围；原文保持不变；与 1.0.2 可达功能一致 | AppStore/metadata.zh-Hans.md；AppStore/metadata.en-US.md |
| E2 新版本说明 / 字段长度 | PASS | python3 AppStore/validate_metadata.py | 所有字段通过；新增中英 1.0.2 说明仅写英文本地化、动态菜单与时长控件修复；不把截图更换当应用更新 | Plans/evidence-1.0.2/metadata.txt；两个 metadata 文件末尾 |
| E3 审核备注 | PASS | 检查 AppStore/review-notes-1.0.2.txt | 新增 1.0.2（5）审核路径与同功能双语言说明 | AppStore/review-notes-1.0.2.txt |
| E4 所有者确认后外部步骤 | PASS | 检查 AppStore/upload-checklist.md 末尾新增小节 | 上传、选择构建、替换截图、保存描述/说明和审核信息、提审均未勾选 | AppStore/upload-checklist.md |
| 约束1 保护运行商店版 | PASS | ps -p 41738 -o pid,comm；NSWorkspace 精确 bundle ID 查询 | 生产 PID 41738 持续运行在 /Applications/NanaFlow.app；未 quit/kill/relaunch/replace，未运行 build_and_run.sh | Plans/evidence-1.0.2/production-process.txt；production-app-resolution.txt |
| 约束2 生产数据前后清单与哈希 | DIFF / 协调者已复核 | python3 script/release_data_snapshot.py build/release-1.0.2/evidence/production-after.json --compare build/release-1.0.2/evidence/production-before.json | 85 个条目（16 个常规文件 SHA-256、69 个不跟随的符号链接）；路径集合不变；2 个偏好 plist 差异按协调者 mtime 归因记录，未读内容、未回写 | build/release-1.0.2/evidence/production-{before,after,comparison}.json；下方差异表 |
| 约束3 无生产 ID 启动 | PASS | script/test.sh；python3 script/render_release_screenshots.py | 宿主 com.nanafox.NanaFlow.ReleaseTests、截图 com.nanafox.NanaFlow.Screenshots；共享 suite 也替换；归档/导出仅文件操作，生产 ID 未启动，因此无需申请生产启动 | script/run_isolated_tests.py；script/ReleaseScreenshots.swift |
| 约束4 独立身份清理 | PASS | python3 script/cleanup_release_identities.py | 按精确 identity/路径清理偏好、容器、App Group、Widget/LaunchServices；精确查询两者均未注册；未杀进程 | Plans/evidence-1.0.2/cleanup.txt |
| 约束5 无外发与本地分支 | PASS | git branch --show-current；git log d029f64..HEAD | release/1.0.2；仅本地提交，无 push/merge/网站更改/Apple 上传或字段编辑；只进行了获准的正常签名/配置与 destination=export | 本地 Git 历史；ExportOptions.plist；新增未勾选上传清单 |
| 约束6 历史原文保留 | PASS | python3 build/release-1.0.2/write_release_records.py（逐文件 startswith 原版本） | metadata/README/screenshots/checklist 原文全部保留，仅追加；AppStore/history 与 1.0.1 review notes 未修改 | Plans/evidence-1.0.2/historical-docs.json |

### 归档与导出命令

```sh
xcodebuild archive -project NanaFlow.xcodeproj -scheme NanaFlow -configuration Release -destination 'generic/platform=macOS' -archivePath ~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive -derivedDataPath build/release-1.0.2/ArchiveDerivedData
xcodebuild -exportArchive -archivePath ~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive -exportPath build/release-1.0.2/ExportRelease -exportOptionsPlist build/release-1.0.2/ExportOptions.plist -allowProvisioningUpdates
python3 script/verify_release_archive.py \
  --archive ~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive \
  --previous ~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.1-build4.xcarchive \
  --export-app build/release-1.0.2/ExportReleaseExpanded/com.nanafox.NanaFlow.pkg/Payload/NanaFlow.app \
  --package build/release-1.0.2/ExportRelease/NanaFlow.pkg \
  --output build/release-1.0.2/evidence/archive-verification.json
```

以上导出选项为 `method=app-store-connect`、`destination=export`、`signingStyle=automatic`、Team `LTLULSL8A2`、`manageAppVersionAndBuildNumber=false`。导出后的 pkg 只用 `pkgutil --expand-full` 解包检查，未安装，未上传。

归档主程序 SHA-256：`850975fb37e03da0bb4e8405a3a0efdb3e18142b27efe0a15b8d124f9b537e93`。本地 pkg：`build/release-1.0.2/ExportRelease/NanaFlow.pkg`，10,510,922 字节，SHA-256 `cb1280ef6cb0eb821a873de88eb933fc61ef0889f5edb86de1f5897694912749`。

### 生产数据差异与协调者复核

只读取路径、lstat/mtime、文件原始字节以计算 SHA-256；没有解码偏好或会话内容，没有跟随容器指向用户其他目录的符号链接。前后各 85 条目，路径无新增/删除，14/16 个常规文件及 69 个符号链接相同；2 个常规偏好文件 SHA-256 不同。完整本地收据留在 `build/release-1.0.2/evidence/production-before.json`、`production-after.json`、`production-comparison.json`，不把真实数据清单提交到 Git。

| 文件 | before mtime（UTC+08） | after mtime（UTC+08） | 字节数变化 |
|---|---|---|---|
| `~/Library/Containers/com.nanafox.NanaFlow/Data/Library/Preferences/com.nanafox.NanaFlow.plist` | 2026-11-03T17:34:33.264839+08:00 | 2026-11-03T17:59:42.515009+08:00 | 52733 → 52869 |
| `~/Library/Group Containers/group.com.nanafox.NanaFlow/Library/Preferences/group.com.nanafox.NanaFlow.plist` | 2026-11-03T17:34:22.519155+08:00 | 2026-11-03T17:59:42.517845+08:00 | 50460 → 50648 |

`~/Library/Containers/com.nanafox.NanaFlow/Data/Library/Preferences/com.nanafox.NanaFlow.plist`：before SHA-256 `398143e4ff0a3f54806b33807d6f7d3a7b20d8de4c1337751170ca1f6aa3ad3a`；after `a7690021eb30122d9c86d6a2e4026f5d1baaef8043cf50937fa1e97c51e39a5d`。

`~/Library/Group Containers/group.com.nanafox.NanaFlow/Library/Preferences/group.com.nanafox.NanaFlow.plist`：before SHA-256 `bee0e7b397b4e9267848aa8538b53ec0758605af46f8fb1fe4010078189d8e41`；after `bbd671f7768e20373c2d8be92e6705e82ab95c39bd86a96f6444e52f6741386c`。

协调者于 2026-11-03 通过 Orca `msg_542023f48cd9` 复核，要求记录以下归因性说明；这是 attributed，并非 proven，也不把 DIFF 写成哈希匹配：

> DIFF in 2 preference plists, attributed by mtime pattern to the owner's running store app (25-minute session interval); contents not read; no action taken. Coordinator reviewed 2026-11-03.

### 注册、失败复现与边界

- Xcode 的正常 archive 步骤曾对本工作树的临时 `ArchiveDerivedData/Build/Intermediates.noindex/ArchiveIntermediates/NanaFlow/InstallationBuildProductsLocation/Applications/NanaFlow.app` 执行 `RegisterWithLaunchServices`。这不是启动。最终以 `lsregister -u <该精确临时路径>` 移除登记（exit 0，日志 `build/release-1.0.2/evidence/archive-registration-cleanup.txt`），随后 `NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.nanafox.NanaFlow")` 读回 `/Applications/NanaFlow.app`。没有注销或改写已安装商店版路径。
- 初次完整测试保留在 `build/release-1.0.2/evidence/tests-initial.txt`：隔离副本缺少 Widget/project 源码证据，另有一条依赖当前系统 locale 的旧日期断言；补齐隔离资源并明确日期测试 locale 后通过。新增复数测试曾发现中文系统地区下英语 `1 rounds`，证据在 `tests-plural-before.txt`；实际修复为按 App 语言选择复数规则，最终 214 项全部通过。测试日志里的系统 `linkd.autoShortcut` 连接警告未导致测试失败，不作为真实系统快捷方式运行验收。
- 清理脚本最初在已未注册的插件/应用上重试删除得到非零，日志 `cleanup-initial.txt` 与 `cleanup-already-unregistered.txt` 已保留；最终脚本先做精确身份查询，幂等清理后 exit 0，并再次证明两个独立身份均未注册。
- 截图只验收本计划要求的实际像素与演示状态；没有声称完成 App Store 上传、提审、真实商店升级、Widget Gallery 或真实通知/声音的额外运行验收。没有改动通知声音实现。
- 无代码、测试、归档或导出阻塞；生产数据的 2 个 DIFF 已按协调者复核记录且未采取动作。协调者独立复核与所有者确认上传/提审仍是后续步骤，不在本 worker 的外发权限内。


## 2026-11-03 独立复核后的修订记录

本节为当前候选的最终记录，取代上方早期候选的对应结果；早期记录与旧 SHA 保留为历史。归档路径已按要求覆盖，版本仍为 **1.0.2（5）**，正式源码提交 `d706c738379a5570a1d4fdc83556b6aa5631bf55`，截图工具提交 `eed2e7b55a39b131fa0a7e0631fb2398136ce87a`；本轮任务 `task_08235066a970` / `ctx_89dee02ea9da`。

| 复核项 / 检查 | 结果 | 命令与输出摘要 | 证据 |
|---|---|---|---|
| 1：设置 ON 外观 | PASS | `python3 script/render_release_screenshots.py`：独立 RenderWindow 强制 key/main 外观并传入 controlActiveState.key；两种语言 ON 开关均为绿色，像素检查各 6969 ≥500 | `script/ReleaseScreenshots.swift`；`Plans/evidence-1.0.2/review-fixes/screenshots-verify.txt` |
| 1：分节标题 / 相同取景 | PASS | 依据真实 NSSwitch 在窗口中的位置连续裁切：en y=184、zh y=240，均 1520×700；顶部留同样 12px 边距，页标题与“提醒”均完全不入镜，通知/专注/休息/音量及说明完整；没有拼接或重绘控件 | 两种语言 `04-completion-sounds.png`；`manifest.json` |
| 2：菜单图标 | 按协调者更正撤销图标修改 | macOS 27 SDK `NSMenuItem.h` 明确 Automatic 通常隐藏图像；`preferredImageVisibility=.visible` 草稿已全部撤回，正式 `NanaFocusApp.swift` 相比 `97b732a` 无差异；最终使用原进程内原生菜单渲染，不覆盖系统策略 | Orca `msg_a66af162a2ad`、`msg_64ec22b960d2`；截图登记表 |
| 2：屏幕录制权限 | 已清理，不依赖 | 窗口 ID 路径曾尝试，独立身份权限未授予，已停止该路线；最终工具不调用 screencapture / ScreenCaptureKit；`tccutil reset ScreenCapture com.nanafox.NanaFlow.Screenshots` exit 0，且在注销该身份之前执行 | `review-fixes/cleanup.txt`；`tcc-cleanup.txt` |
| 3：先失败测试 | PASS（预期失败） | `python3 script/run_isolated_tests.py -only-testing:NanaFlowTests/SessionHistoryTests/testMonthAxisPreservesEndDateWithoutCrowdingLabelsForEveryMonthLength`：修复前 1 test / 2 failures，31 天出现 30/31 相邻；提交 b95d356 | `Plans/evidence-1.0.2/review-fixes/month-axis-before.txt` |
| 3：月末标签修复 | PASS | 保留最后一天，前一个五日标签至少间隔 3 天；28/29/30/31 均保留 1/5/10/15/20/25/末日；31 天不再显示 30；提交 d706c73 | `Sources/NanaFocus/StatisticsView.swift`；`Tests/NanaFocusTests/SessionHistoryTests.swift`；两种语言 `03-month-duration.png` |
| 全量隔离单测 | PASS | `script/test.sh`：215 tests / 0 failures，未排除用例 | `build/release-1.0.2/evidence/review-fixes/tests.txt`；提交的 tests-summary |
| 本地化 / 工程漂移 / 文案 | PASS | `python3 script/check_localization.py --audit Plans/evidence-1.0.2/review-fixes/localization-audit.md`：259/0；`script/check_xcodegen_drift.sh` exit 0；`python3 AppStore/validate_metadata.py` exit 0；版本说明补充真实月末标签修复 | 同目录 localization / drift / metadata 记录 |
| 截图验证 | PASS | `swift script/verify_release_screenshots.swift AppStore/Screenshots/1.0.2`：8 张 2880×1800、无 alpha；两种语言计时数字 203px；通知 ON 强调色各 6969px；`sips -g pixelWidth -g pixelHeight -g hasAlpha …` 一致 | screenshots-verify / screenshot-properties；逐张目视检查四张修改图；01 与 97b732a 字节相同 |
| Release 重归档 | PASS | `xcodebuild archive -project NanaFlow.xcodeproj -scheme NanaFlow -configuration Release -destination 'generic/platform=macOS' -archivePath ~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive -derivedDataPath build/release-1.0.2/ArchiveDerivedData`：ARCHIVE SUCCEEDED | review-fixes/archive.txt；archive-verification.json |
| 最新归档 / 导出校验 | PASS | `xcodebuild -exportArchive`，仍为 method=app-store-connect / destination=export，输出 ExportReviewFixes；`pkgutil --expand-full` 后 `python3 script/verify_release_archive.py --archive … --previous … --export-app … --package … --output …`：App / Widget 1.0.2(5)，开发归档身份匹配 1.0.1，同 Team，严格签名通过；导出为 Apple Distribution | `build/release-1.0.2/ExportReviewFixes/NanaFlow.pkg`；review-fixes/archive-verification.json |
| 生产数据收据 | DIFF，未归因 | `python3 script/release_data_snapshot.py build/release-1.0.2/evidence/review-fixes/production-after.json --compare build/release-1.0.2/evidence/review-fixes/production-before.json`：DIFF: 1 preference file changed among 85 unchanged paths; contents not decoded, no attribution or corrective write made. | 本地 before / after / comparison JSON；下方 mtime 表 |
| 原有边界 / 清理 | PASS | 未启动生产 ID，未读/解码/回写生产内容，无 push/merge/upload/提审/Apple 字段编辑/网站变更；生产 PID 41738 启动于 16:24:19，仍解析至 `/Applications/NanaFlow.app`；精确清理两个 fixture identity、Widget、容器、偏好、TCC；归档临时注册路径精确注销 | review-fixes/production-process.txt、production-app-resolution.txt、cleanup.txt；archive-registration-cleanup.txt |

当前归档主程序 SHA-256：`abd19732001008099166356db2460a0a96f402b306ceebe868655c3a0e5c68d3`。当前本地导出包 `build/release-1.0.2/ExportReviewFixes/NanaFlow.pkg`：10,511,003 字节，SHA-256 `c79508dac6ca88e663b92ae6dda19c5ad32ae579b9040c640f2893cc32e1d266`。本轮唯一正式产品源码改动为月统计标签策略；设置代码及菜单工厂未改动。

| Changed file | Before mtime (UTC+08) | After mtime (UTC+08) | Bytes |
|---|---|---|---|
| `~/Library/Containers/com.nanafox.NanaFlow/Data/Library/Preferences/com.nanafox.NanaFlow.plist` | 2026-11-03T17:59:42.515009+08:00 | 2026-11-03T18:50:52.533305+08:00 | 52869 → 52921 |


完整生产数据清单只保留于本地 build 目录，未提交；本轮不对 mtime 变化作未经核对的归因，也未因差异执行任何数据恢复。上一轮 2 文件差异及协调者对其时间模式的归因仍保留在上方历史记录，不等同于本轮结论。

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


本轮截图调试曾发生：启动时机导致非 key 外观；更长等待和单独 GUI 启动未形成可靠捕获；曾尝试仅非可见滚动定位标记，但已完全撤回。最终未更改任何生产设置布局或菜单图标策略，仅通过独立窗口 key 外观及连续取景修正图片。TCC 清理最初放在 LaunchServices 注销之后而返回“无此 bundle ID”，已调整为先精确解析/临时登记该 fixture、重置其 ScreenCapture，再注销并读回两个身份都不存在；最终清理 exit 0，完整失败输出留在本地 `cleanup-before-ordering.txt`。


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
