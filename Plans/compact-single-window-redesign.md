# NanaFlow 单窗口精简重构

目标：按已确认的旧版 Flow 交互，把计时器与统计放回同一个 380×272 主窗口；状态栏只显示倒计时；统计按日 24、周 7、月实际天数、年 12 个柱展示；阻断器、标签和独立统计窗口不再出现在产品入口或后台运行链路。

## L1.1 引用验证

| 符号 | 证据 (file:line) | 签名 | 用途 |
|-----|-----------------|-----|-----|
| `NanaFlowApp` | `Sources/NanaFocus/NanaFocusApp.swift:14` | `struct NanaFlowApp: App` | 删除独立统计、阻断器、标签窗口，只保留主窗口路由 |
| `MenuBarStatusContent` | `Sources/NanaFocus/NanaFocusApp.swift:123` | `struct MenuBarStatusContent: View` | 收敛为纯倒计时文本 |
| `AppStatusItemService` | `Sources/NanaFocus/NanaFocusApp.swift:182` | `final class AppStatusItemService: NSObject` | 状态栏菜单进入主窗口统计页，移除阻断监控 |
| `TimerView` | `Sources/NanaFocus/TimerView.swift:5` | `struct TimerView: View` | 在现有页面状态中承载精简统计页 |
| `StatisticsView` | `Sources/NanaFocus/StatisticsView.swift:58` | `struct StatisticsView: View` | 改为主窗尺寸的柱状图与周期导航，不保留标签/会话子路由 |
| `SessionStatistics` | `Sources/NanaFocus/SessionHistory.swift:149` | `struct SessionStatistics: Equatable, Sendable` | 复用既有周期与桶计算，不重写数据层 |
| `NanaFlowAppDelegate` | `Sources/NanaFocus/SessionNotificationScheduler.swift:283` | `AppStatusItemService(...)` | 去掉 `BlockerController` 注入 |

## L1.2 同类路径对照

参考实现：`Sources/NanaFocus/TimerView.swift:28-81`

- [x] 设置、自定义时长等页面已通过 `TimerPage` 在主窗口切换
- [x] 统计复用同一路由，不再创建第二个 SwiftUI `Window`
- [x] 状态栏入口通过 `NotificationCenter` 唤起主窗口并切页，沿用设置页现有做法

## L1.3 约定清单

| 约定 | 现状 | 我的选择 | 理由 |
|-----|-----|--------|------|
| 状态源 | `TimerController` 由主窗和状态栏共享 | 保持 | 避免双状态和同步层 |
| 统计分桶 | `SessionStatistics.bucketIntervals` 按 Calendar 迭代 | 保持并补边界测试 | 已覆盖自然月天数和闰年 |
| 页面导航 | `TimerPage` 私有枚举 | 新增 `.statistics` | 最小改动且与设置页一致 |
| 状态栏外观 | 可选半圆/圆形/进度条/标题 | 强制纯时间 | 已锁定产品方向，设置项不再暴露 |
| 遗留功能 | 阻断器、标签仍有独立模块 | 断开可见入口与后台接线，暂不删文件 | 根目录无 Git，保留可恢复性 |

## L1.4 Return 语义

无新增返回协议。统计页读取 `SessionStatistics.buckets`；空历史仍返回对应周期的完整零值桶。

## L1.5 负向断言

| 输入 | 必须返回 | 测试断言 |
|-----|--------|--------|
| 2028 年 2 月（月统计） | 29 个桶 | `testStatisticsBucketsMatchCalendarPeriodLengths` |
| 主应用源码 | 无独立统计/阻断器/标签窗口 | `testCompactProductSurfaceUsesSingleTimerWindow` |
| 菜单栏视图 | 无半圆和替代进度图标 | `testMenuBarShowsTimeOnly` |
| 主窗口菜单 | 无标签和阻断器入口 | `testTimerMenuKeepsOnlyCoreProductSurfaces` |

## L1.6 回滚

| 类别 | 变更 | 回滚动作 | 顺序 |
|-----|-----|--------|------|
| 代码 | SwiftUI 路由、状态栏和统计视图 | 按本计划文件清单恢复修改前文件；目录无 Git，故不物理删除遗留模块 | 1 |
| 配置 | 无 | 无 | 2 |
| 数据 | 无持久化迁移 | 既有偏好与会话数据保持兼容 | 3 |

回滚后可接受状态：恢复现有独立统计窗口和状态栏图标，用户会话历史不丢失。

---

## L2.1 运行时假设（横切 feature 必填）

| 假设 | 验证路径 | 环境 | 假设不成立时行为 |
|-----|--------|-----|--------------|
| 主窗可接收通知切页 | 设置页已有 `.showSettings` 路径 | macOS Debug | 复用同一通知方式并加测试 |
| Calendar 能生成完整周期桶 | `SessionStatistics.bucketIntervals` | 固定 UTC Gregorian 单测 | 修复共享分桶函数，不在视图补丁 |
| 380×272 可容纳精简统计 | 原型与现有主窗尺寸均为 380×272 | 原生 ImageRenderer + 运行态 | 只调整内部密度，不新增窗口 |

## L2.2 状态机

```
TimerPage.timer
  → 工具栏/菜单/状态栏“统计” → TimerPage.statistics
TimerPage.statistics
  → 返回 → TimerPage.timer
  → D/W/M/Y → 同页刷新 buckets
  → 左右箭头 → 同页移动 anchor
TimerPage.settings/durations/timerSync
  → 返回 → TimerPage.timer
```

并发点：状态栏每秒 tick 与统计读取同处 `@MainActor` 的 `TimerController`。
防护：不复制会话数组，不新增异步缓存；SwiftUI 在主线程重算只读统计。

## L2.6 权限/安全

本次不新增身份、网络、凭证、SSRF 或租户边界。移除阻断器后台监控反而减少 Apple Events 与浏览器检查面；通知、日历等既有权限路径不变。

## 剩余风险登记

| 项 | 接受/已知/待后续 | Owner | Follow-up ticket |
|----|----------------|------|-----------------|
| 遗留阻断器/标签源码仍编译但不可达 | 已知：无 Git 回滚前不做物理删除 | NanaFlow | 建立版本控制后单独清理 |
| 历史高级统计/导出界面被移出产品入口 | 接受：当前目标是旧版简洁交互 | NanaFlow | 需求再次明确时再恢复 |
