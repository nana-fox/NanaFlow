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
| 6 | Session history with the More menu open | 完整备份，也能安全合并导入 | Back up history and safely merge an import | Capture only after the tag/filter UI is removed or hidden from the 1.0 candidate. Show backup/import actions without personal session text. |

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
| zh-Hans | 1 | `1.0.0 (2)` | `Screenshots/zh-Hans/main-1280x800.jpg` | ☑ | ☐ |
| zh-Hans | 2 | `1.0.0 (2)` | `Screenshots/zh-Hans/menu-1280x800.jpg` | ☑ | ☐ |
| zh-Hans | 3 | `1.0.0 (2)` | `Screenshots/zh-Hans/stats-year-1280x800.jpg` | ☑ | ☐ |
| en-US | 1 | `1.0.0 (2)` | `Screenshots/en-US/main-1280x800.jpg` | ☑ | ☐ |
| en-US | 2 | `1.0.0 (2)` | `Screenshots/en-US/menu-1280x800.jpg` | ☑ | ☐ |
| en-US | 3 | `1.0.0 (2)` | `Screenshots/en-US/stats-year-1280x800.jpg` | ☑ | ☐ |

The six files above are 1280×800 JPEG captures sourced from the installed
TestFlight candidate `/Applications/NanaFlow 2.app` (`1.0.0 (2)`). The English
locale currently reuses the same candidate UI capture because the binary was
verified under the user's Simplified Chinese macOS locale; do not claim English
visual localization until a separate English-locale capture is made.
