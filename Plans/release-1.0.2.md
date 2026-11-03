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
- Release 配置 `xcodebuild archive` 成功，产物为 1.0.2（5），签名身份与 1.0.1 归档一致（Apple Distribution / 同一 Team `LTLULSL8A2`）；本地 `exportArchive`（app-store 方式，不上传）成功。归档存到 `~/Library/Developer/NanaFlow-ReleaseArchives.noindex/NanaFlow-1.0.2-build5.xcarchive`。
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

（由实现者填写）

## 执行记录

（由实现者填写）
