# Screenshot plan

Capture screenshots from the exact release candidate after the 1.0 UI scope is locked. Do not use the design prototype, composited controls, or a development build with excluded features visible. Use representative local sample sessions with no personal information.

## Required sequence

| Order | Screen and state | 简体中文 caption | English caption | Acceptance notes |
|---|---|---|---|---|
| 1 | Main timer, focus running | 专注，从一个清晰的计时器开始 | Focus starts with one clear timer | Show a running focus session, cycle indicators, and the compact main window. |
| 2 | macOS menu bar with NanaFlow menu open | 不离开当前工作，也能掌控节奏 | Stay in control without leaving your work | Show the readable countdown and menu commands. No logo badge or mini timer. |
| 3 | Weekly statistics in the main window | 一周七天，一眼看清专注节奏 | See your focus rhythm across seven days | Show seven bars and visible weekday labels. |
| 4 | Monthly statistics with one bar hovered | 每一天的完成数量，悬停即可查看 | Hover to see each day's completed count | Show the selected month with its real day count and the concise numeric tooltip. |
| 5 | Settings: menu bar and reminder sections | 按你的习惯设置菜单栏与提醒 | Tune menu-bar controls and reminders | Crop to actual 1.0 settings only; do not show Calendar or iCloud controls. |
| 6 | Reserved for a future build with an accessible history UI | — | — | Do not capture or upload for build 2; the history view has no UI entry point. |

## Capture rules

- Use the same signed candidate build intended for upload; record its version and build number beside the source images.
- Keep the main window at its shipped size. Do not stretch it to fill the screenshot.
- Verify Chinese screenshots under Simplified Chinese and English screenshots under English.
- Keep macOS system chrome consistent within each locale set.
- Use accessible contrast and a clean desktop background; avoid third-party app names, personal notifications, account names, file paths, and menu-bar clutter.
- Export losslessly, without alpha, at a currently accepted App Store Connect Mac screenshot size; confirm the live requirement at upload time.
- Widget screenshots are prohibited until Widget Gallery discovery and App Group data sharing pass on the signed candidate.
- Do not show the web/app blocker, insights, tags, mini timer, paywall, Calendar, or iCloud.

## Asset register

Fill this only after capture; a row without a source build is not upload-ready.

| Locale | Shot | Source build | Filename | Visual QA | Uploaded |
|---|---:|---|---|---|---|
| zh-Hans | 1 | `1.0.0 (2)` | `Screenshots/zh-Hans/main-1280x800.jpg` | ☑ | ☑ |
| zh-Hans | 2 | `1.0.0 (2)` | `Screenshots/zh-Hans/menu-1280x800.jpg` | ☑ | ☑ |
| zh-Hans | 3 | `1.0.0 (2)` | `Screenshots/zh-Hans/stats-year-1280x800.jpg` | ☑ | ☑ |
| en-US | 1 | `1.0.0 (2)` | `Screenshots/en-US/main-1280x800.jpg` | ☑ | ☑ |
| en-US | 2 | `1.0.0 (2)` | `Screenshots/en-US/menu-1280x800.jpg` | ☑ | ☑ |
| en-US | 3 | `1.0.0 (2)` | `Screenshots/en-US/stats-year-1280x800.jpg` | ☑ | ☑ |

The six files above are 1280×800 JPEG captures sourced from the installed
TestFlight candidate `/Applications/NanaFlow 2.app` (`1.0.0 (2)`). The English
locale currently reuses the same candidate UI capture because the binary was
verified under the user's Simplified Chinese macOS locale; do not claim English
visual localization until a separate English-locale capture is made.


## 1.0.2（5）截图登记 — 2026-11-03

本节使用 `Plans/release-1.0.2.md` 允许的独立身份和正式 SwiftUI 视图渲染方式；来源构建为 1.0.2（5），UI 源码提交 `8fd36e09eda6a8299e549058e544029e165f71de`。`script/render_release_screenshots.py` 复制正式源码，替换入口和 App Group，使用 `com.nanafox.NanaFlow.Screenshots` 与纯内存演示数据；没有启动生产身份。计时与统计采用 ImageRenderer 4×，原生菜单及真实滚动设置页采用 4× backing。关闭的只是不可见的 AppKit 配置/事件层，所有可见控件复用正式视图，没有重画或拼凑控件。最终品牌背景只添加 NanaFlow 品牌和一行对应语言标题。

英语参数 `-AppleLanguages (en) -AppleLocale en_US`；简中参数 `-AppleLanguages (zh-Hans) -AppleLocale zh_Hans`。月份固定为虚构的 2026 年 10 月，完成记录无标题、账号或路径；菜单栏只渲染 NanaFlow 自身状态。月统计使用正式 hover 状态的初始注入，提示 10 月 22 日的 2 小时 50 分钟。设置为原生滚动到底状态，专注/休息声音分别为 Chime/风铃 和 Bowl/唱钵，音量 50%。

全部图片已逐张目视检查；英语四个页面及额外“⋯”菜单证据无中文残留，周图 7 根柱与星期标签、次数/时长切换可见，月图选中时长并显示 tooltip，设置两种声音及音量均完整可读。截图不包含日历、iCloud、阻断器、标签、历史列表、导入/备份、全局快捷键面板或 Widget。尺寸均为 2880×1800 PNG、无透明通道；计时数字实测 ink 高 203px。清理结果见 `build/release-1.0.2/evidence/cleanup.txt`；两个独立身份的偏好、容器、App Group、LaunchServices 与 Widget 注册已清理/确认不存在。此处没有执行上传。

| Locale | 顺序 | 来源构建 | 文件 | 字节数 | 尺寸/Alpha | 目视检查 | Uploaded |
|---|---:|---|---|---:|---|---|---|
| en-US | 1 | 1.0.2（5） | `Screenshots/1.0.2/en-US/01-focus-menu.png` | 2,943,743 | 2880×1800 / no | 通过 | 未上传 |
| en-US | 2 | 1.0.2（5） | `Screenshots/1.0.2/en-US/02-week-count.png` | 3,437,327 | 2880×1800 / no | 通过 | 未上传 |
| en-US | 3 | 1.0.2（5） | `Screenshots/1.0.2/en-US/03-month-duration.png` | 3,454,742 | 2880×1800 / no | 通过 | 未上传 |
| en-US | 4 | 1.0.2（5） | `Screenshots/1.0.2/en-US/04-completion-sounds.png` | 3,486,715 | 2880×1800 / no | 通过 | 未上传 |
| zh-Hans | 1 | 1.0.2（5） | `Screenshots/1.0.2/zh-Hans/01-focus-menu.png` | 2,934,027 | 2880×1800 / no | 通过 | 未上传 |
| zh-Hans | 2 | 1.0.2（5） | `Screenshots/1.0.2/zh-Hans/02-week-count.png` | 3,429,106 | 2880×1800 / no | 通过 | 未上传 |
| zh-Hans | 3 | 1.0.2（5） | `Screenshots/1.0.2/zh-Hans/03-month-duration.png` | 3,464,150 | 2880×1800 / no | 通过 | 未上传 |
| zh-Hans | 4 | 1.0.2（5） | `Screenshots/1.0.2/zh-Hans/04-completion-sounds.png` | 3,485,815 | 2880×1800 / no | 通过 | 未上传 |

文件 SHA-256 与来源记录：`Screenshots/1.0.2/manifest.json`。额外英文“⋯”菜单证据：`../Plans/evidence-1.0.2/A-en-timer-options.png`（只作本地化验收，不列入商店四张序列）。


## 1.0.2 独立复核修订 — 2026-11-03

本节为上方 1.0.2 图片登记的当前版本。03 已重拍，31 天月份的末尾只标 31，不再同时标相邻的 30。04 通过独立截图窗口的 key/main 外观与 controlActiveState.key 显示绿色 ON，按真实通知开关位置连续裁切，两个语言均 1520×700 源像素、顶部 12px 留白，不显示分节/页标题；通知、两种声音、音量与说明完整可见。没有拼接或重画控件，生产设置路径不变。

菜单说明更正：本机 macOS 27 SDK 的 NSMenuItem.h 指明 Automatic 图标可见性通常隐藏图像。经协调者 `msg_a66af162a2ad` / `msg_64ec22b960d2` 更正，本版不覆盖该系统策略，01 沿用进程内的正式原生菜单渲染。曾尝试窗口 ID 捕获，但不请求/依赖独立截图身份的 Screen Recording 权限；最终工具无该捕获路径，已仅对 `com.nanafox.NanaFlow.Screenshots` 执行 ScreenCapture 重置并精确注销身份。

来源正式代码 `d706c738379a5570a1d4fdc83556b6aa5631bf55`，截图工具 `eed2e7b55a39b131fa0a7e0631fb2398136ce87a`；版本 1.0.2（5）不变。全套仍为 2880×1800、opaque PNG，计时数字 ink 203px；04 的 ON 开关两种语言各 6969 个强调色像素。下表与 manifest 为当前字节数；早期登记保留历史含义，所有图片均未上传。

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
