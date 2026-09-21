# App Review notes

Use the base note below, then append exactly one Widget variant matching the submitted binary. Replace all bracketed values.

## Base note — English, copy-ready after placeholders are resolved

```text
NanaFlow is a menu-bar focus timer for macOS. It does not require an account or sign-in.

Accessing the app:
1. Launch NanaFlow.
2. On first launch, choose “OK” in the welcome window to open the timer.
3. NanaFlow also places a countdown in the macOS menu bar. On later launches the main window may remain hidden, depending on the saved launch preference. NanaFlow intentionally has no Dock icon.
4. Left-click the countdown to open the NanaFlow menu, then choose “Show Timer” to open the main window.
5. Right-click or Control-click the countdown to quickly start or pause the timer.

Core review path:
1. In the main window, use the circular button to start or pause a focus session.
2. Use the reset control or the menu-bar commands to reset or switch stages.
3. Select the chart button to open D/W/M/Y statistics in the same window. Hover over a bar to display its session count.
4. From the session history More menu, “Full Backup” exports JSON and “Import Backup…” merges a selected JSON backup with local history.
5. Open Settings to configure the menu-bar completed count, completion sounds, and notifications.

Notifications are used only to announce timer stage completion and offer the next timer action. Permission is requested from the Settings notification control. If the switch is already on in a fresh review environment but macOS has not shown a prompt, switch it off and on once before testing. NanaFlow remains usable if notification permission is denied.

No web/app blocker, insights, tag workflow, mini timer, paywall, Calendar integration, or iCloud sync is included in version 1.0.

Contact for review questions: [REVIEW_CONTACT_NAME], [REVIEW_CONTACT_EMAIL], [REVIEW_CONTACT_PHONE]
```

## Base note — 简体中文内部对照

```text
NanaFlow 是一款 macOS 菜单栏专注计时器，无需账号或登录。

打开应用：
1. 启动 NanaFlow。
2. 首次启动时，在欢迎窗口点击“好的”打开计时器。
3. NanaFlow 也会在 macOS 菜单栏显示倒计时。之后启动时，主窗口是否显示取决于已保存的启动偏好；应用按设计不显示 Dock 图标。
4. 左键点击倒计时打开 NanaFlow 菜单，然后选择“显示计时器”打开主窗口。
5. 右键或按住 Control 点击倒计时可快速开始或暂停计时。

主要审核路径：
1. 在主窗口使用圆形按钮开始或暂停专注。
2. 使用重置按钮或菜单栏命令重置或切换阶段。
3. 点击柱状图按钮，在同一窗口查看 D/W/M/Y 统计；悬停柱形可显示会话数量。
4. 在会话历史的“更多”菜单中，“完整备份”导出 JSON，“导入备份…”将所选 JSON 备份与本机历史合并。
5. 打开设置，配置菜单栏完成数、完成声音和通知。

通知只用于提示计时阶段结束并提供下一步计时操作。通知权限由设置中的通知开关触发；如果全新审核环境中开关已经打开但 macOS 未弹出授权，请先关闭再打开一次。拒绝通知权限不影响计时器使用。

1.0 不包含网页或应用阻断、洞察、标签工作流、迷你计时器、付费墙、日历集成或 iCloud 同步。
```

## Widget variant A — use unless the signed gate passes

```text
The submitted version does not advertise or rely on a Widget. No Widget behavior is required to review the app.
```

Before using this variant, confirm that the release archive does not expose an unverified Widget extension. If it does, either pass the signed Widget gate and use variant B or remove the extension from 1.0.

## Widget variant B — use only after signed verification

Do not paste this until the signed App Store candidate has passed Widget Gallery discovery and App Group data-sharing verification.

```text
NanaFlow includes a Widget extension. To review it, open the macOS Widget Gallery, search for “NanaFlow,” and add the Daily Statistics widget. Complete a focus session in the main app, then confirm that the widget displays the same completed count or focused minutes. The widget reads local history shared through the NanaFlow App Group; it does not require an account or network access.
```

Record the evidence before selecting variant B:

- signed candidate version/build: `[VERSION] ([BUILD])`
- test Mac and macOS version: `[DEVICE / OS]`
- Widget Gallery discovery: `PASS / FAIL`
- completed count/minutes matches main app: `PASS / FAIL`
- relaunch and timeline refresh: `PASS / FAIL`
