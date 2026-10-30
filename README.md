# NanaFlow

NanaFlow 是一个原生 macOS 专注计时器。当前产品采用紧凑的单主窗：计时器与 D/W/M/Y 统计在同一窗口内切换，状态栏默认显示倒计时，可选显示当天已完成的专注次数。交互设计参考 Flow 的克制与易用性；NanaFlow 与 Flow 及其开发者没有关联，应用代码、品牌和随包音频、图形资源均为独立实现，不含 Flow 素材。

## 当前范围

- 25/5/30 默认周期、暂停、继续、跳过、重置与自动开始。
- 主窗口内统计：日按实际小时（夏令时为 23/25 小时）、周 7 天、月按实际天数、年 12 个月；可切换次数/净专注时长，合计、柱形、悬浮提示和辅助功能同步。
- 独立的专注/休息完成声音，含「无」；共用静音/25/50/75/100% 五档音量，试听使用同一通知音频资源。关闭通知也关闭完成声音。
- 会话记录、设置、通知、日历、快捷键、自动化与 Widget 代码。
- 状态栏倒计时及快速命令；可显示 `25:00 | 3`，不显示品牌半圆标记。
- 手动「跳到专注 / 跳到休息」立即开始下一阶段；自然结束仍遵循自动开始设置。
- 旧版阻断器、标签与迷你计时器模块仅保留兼容代码，不在当前产品入口中展示或启动。

## 公测状态

`1.0-beta.1` 的应用内版本为 1.0 (3)。安装包与发布状态以 [GitHub Releases](https://github.com/nana-fox/NanaFlow/releases) 为准；发布说明见 [Releases/1.0-beta.1.md](Releases/1.0-beta.1.md)。

[1.0-beta.1 公测版](https://github.com/nana-fox/NanaFlow/releases/tag/v1.0-beta.1) 已提供 Developer ID 签名、公证并附票的通用 ZIP。维护者已完成一次受控隔离下载包的实际安装、升级与退出重开核对；这不是浏览器下载路径或所有 Mac 的兼容性验证。

以下三项尚未验收，不代表已通过：

- 通知动作：通知卡片上的打开、开始、跳过等动作，以及前台显示。
- Widget：实际画面与刷新。
- 声音：完成提示音的实际播放。

## 旧版数据导入

入口为「设置 → 旧版数据 → 导入旧版数据…」，用于导入旧版 NanaFlow 的偏好文件，不支持导入 Flow 或其他应用的数据。

1. 在旧版中暂停计时，并关闭“启动时开始计时”“启动时重置周期”和定时器同步；然后退出旧版。
2. 将 `~/Library/Preferences/com.nanafox.NanaFlow.plist` 复制到其他位置留作备份，导入时选择这份副本。
3. 确认新版当前没有运行中的计时，再选择文件。

兼容边界：

- 只接受不超过 16 MiB 的 `.plist`。必须包含计时状态、偏好和会话历史，且能被当前版本解码；标签可选，其他内容一律不导入。
- 不合并，也不覆盖：目标中已有不同的值或已有会话历史时会拒绝。若所有值已逐字节相同，则不写入，只刷新内存状态。
- 校验不通过时不做任何更改。写入后的读回失败时会尝试移除本次写入，但这不是跨进程的崩溃安全事务；若提示校验未通过，请退出 App 后再检查数据。
- 导入不会开始计时、发送通知、写入日历、同步或播放声音。
- 不要依赖首次启动的系统自动迁移：工程带有 `container-migration.plist`，但它在维护者的一次真实升级中未生效，原因尚未确定，迁移只在容器首次创建时才可能执行。

导入已在较早候选 1.0 (1) 上用一台 Mac 的真实数据验证并重开核对；1.0 (3) 已通过本次导入保护回归。其他旧版本和数据形态未覆盖。主历史缺失而 Widget 镜像为空的特定场景，旧版导入可能被保护规则拒绝；这是静态审查边界，尚未实机覆盖，请保留原数据文件。

## 菜单栏与阶段跳转

在「设置 → 菜单栏」开启「显示今日完成数」后，菜单栏显示 `倒计时 | 数量`，不额外显示“今日”。开关默认关闭，修改立即生效并在重启后保留；当天尚无已完成专注时显示 `0`。

数量按本地日期和会话结束时间统计，仅包括已完成的专注，不包括休息与中途跳过；与当天统计采用相同口径。日期区间采用左闭右开边界，午夜结束的会话只计入新的一天。

菜单栏、主窗口按钮及菜单、全屏休息界面和全局快捷键中的主动跳转，会从下一阶段的完整时长立即开始。运行、暂停、尚未开始时都适用；强制专注期间仍不能跳过。自然结束以及 URL / AppleScript / App Intents 的既有跳转命令继续遵循自动开始偏好。

设计、实现范围和验收边界见 [菜单栏今日完成数与跳转即开始](Plans/menu-bar-daily-count-and-skip-start.md)。

## 工程结构

| 路径 | 内容 |
| --- | --- |
| `Sources/NanaFocus` | 主应用、计时器、窗口与系统集成 |
| `Sources/NanaShared` | 主应用与 Widget 共用模型 |
| `Sources/NanaFlowWidget` | Widget extension |
| `Tests/NanaFocusTests` | 单元、契约与视图回归测试 |
| `project.yml` | XcodeGen 工程定义 |

## 本地开发

要求：macOS 15 或更高版本，支持 Swift 6 和 macOS 26 SDK 的 Xcode（控制中心 Widget 使用 macOS 26 API，主应用最低运行版本仍为 macOS 15），以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```sh
git clone https://github.com/nana-fox/NanaFlow.git
cd NanaFlow
```

仓库已包含 `NanaFlow.xcodeproj`，公测版本以该工程文件为准，无需运行 XcodeGen。修改工程结构后才需要重新生成，并须核对 `container-migration.plist` 仍在 Resources 中：

```sh
xcodegen generate
```

```sh
xcodebuild test -project NanaFlow.xcodeproj -scheme NanaFlow -destination 'platform=macOS'
```

无需开发者证书的静态分析：

```sh
xcodebuild analyze \
  -project NanaFlow.xcodeproj \
  -scheme NanaFlow \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## 本地验收构建

R1 在仅有 CLT Swift 6.1.2 / macOS SDK 15.5 的环境提供可追溯独立候选；每次使用新的 staging 名称：

```sh
mkdir -p build/r1
python3 Tools/check-r1-resources.py > build/r1/resources-report.json
python3 Tools/build-r1.py --stage review-01 --checks
open -n 'build/r1/review-01/NanaFlow R1 Review.app' --args -AppleLanguages '(zh-Hant)' -AppleLocale zh_TW
```

脚本从当前源码生成兼容副本、资源与本地签名，记录输入 hash、每项适配、app/runner 各自输入和命令。`--checks` 真正编译执行 `MenuBarAndJumpChecks` 与 XCTest 共用的 `R1BehaviorChecks`，包含可控异步通知提交的最终配置与截止时间检查。不会使用旧 compat、旧 RegressionApp 或旧二进制。

候选身份为 `com.nanafox.NanaFlow.R1Review`，共享 suite 也独立；移除生产 URL/脚本注册、KVS/App Group entitlement，省略 Widget。启动前须核对 staging 的 manifest、签名与身份报告，不可将生产偏好/历史导入候选。测试数据工具 `Tools/seed-r1-fixture.py` 只写候选域，要求先退出候选；`--mode fixture` 读取主代理夹具，`--mode short-timer` 供独立域自然结束自检。语言参数仅影响候选进程，不修改系统语言。

这些检查不替代完整 Xcode XCTest/Release analyze、macOS 26 Widget、正式签名/iCloud 或系统通知实际投递验收。最终验收由主代理完成，不覆盖 `/Applications/NanaFlow.app`。

完整 Xcode 就绪后可使用 `Tools/xcode-r1-acceptance.py` 生成独立工程并运行后台 `--run test` 或 `--run analyze`，每次使用新的 `--stage` 名称，`--developer-dir` 必须指向实际的 `Xcode.app/Contents/Developer`。可用 `--derived-data` 将编译缓存放在外置盘；工具只对子进程设置 `DEVELOPER_DIR`，不更改系统的 Xcode 选择。

该工程使用独立 R1XCTest 身份、共享 suite 和无生产 URL/脚本注册的 Info，复制当前测试所需夹具，并单独接入原生悬浮/拖动 UI 测试。`prepare` 生成成功不代表 Xcode 编译、测试或系统能力通过；命令、输入 hash、结果包和日志保存在 `build/r1-completion/<stage>`。

后台单元测试使用独立编译副本抑制场景启动、禁止应用激活，并跳过实时菜单栏/云同步启动；源码契约检查仍读取原始快照。六个明确显示窗口的用例和四个存在窗口生命周期副作用的 TimerView 渲染用例保留在原套件中，但从后台批次排除，另待独立桌面执行。套件末尾额外检查测试宿主未激活、没有可见窗口；此采样不能独自证明全程无窗口。测试域的准备、运行和退出以文件锁串行化。此模式验证逻辑、资源和其余离屏渲染，不能替代真实窗口交互。可用 `--run test --prepare-only` 先生成可审查副本，不执行 Xcode 或导入偏好。

`--run ui-test` 会操作桌面鼠标与窗口，必须在可独占的测试桌面显式加 `--allow-desktop-ui`；当前使用中的桌面不运行这项。不得将 UI 测试的编译成功、跳过或被其他窗口干扰的结果记为交互验收通过。

## 本地安装包

`dist` 是维护者本机的交付目录，已被 Git 忽略，不会随代码仓库推送。历史本机验收包（不包含 2026-09-21 的功能更新）为：

```text
dist/NanaFlow-7d911b9-macOS-universal.zip
```

ZIP 内只有一个 `NanaFlow.app`。退出旧版后，将它拖入“应用程序”并选择替换。

当前公测安装包与校验摘要见 [v1.0-beta.1 Release](https://github.com/nana-fox/NanaFlow/releases/tag/v1.0-beta.1)。该标签保留发行时源码；后续文档说明只更新独立发行分支，不移动标签，也不代表 App Store 分支已更新。

## 签名边界

未签名或 ad-hoc 构建适合本机的核心功能与视觉验证。App Group、iCloud KVS、Calendar、系统通知、浏览器自动化和 Widget Gallery 的正式验收，需要 Apple Developer 证书、匹配的 provisioning profile，并由用户在 macOS 中授权。

当前审查证据见 [`CODE_AUDIT.md`](CODE_AUDIT.md)；第三方资源说明见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
