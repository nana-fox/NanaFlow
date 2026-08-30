# 黑名单应用反馈通知等价

用户旅程：作为正在专注的用户，当我切到黑名单应用时，我希望应用被立即挡回并收到明确、不过度重复的系统通知，从而知道为什么该应用无法打开。

权威参考：本机只读 Flow 4.8 `zh-Hans.lproj/Notification.strings` 与 arm64 二进制。二进制证据包含 `_TtC4Flow18NotificationClient`、`blockedAppNotificationIdentifiers`、`notification_app_blocked`，并在通知请求调用链中设置 0.5 秒非重复触发、`sound = nil`；同一份应用显示名同时进入标题构造和进程内 UUID 查找。

## L1.1 引用验证

| 符号 | 证据 (file:line) | 签名 | 用途 |
|-----|-----------------|-----|-----|
| `BlockerController.init` | `Sources/NanaFocus/BlockerView.swift:20` | `(persistence:browserController:blockedAppNotifications:)` | 注入已有持久化、浏览器阻断与通知依赖 |
| `BlockerController.handleActivation` | `Sources/NanaFocus/BlockerView.swift:123` | `(processIdentifier: pid_t) -> Void` | 唯一应用激活阻断入口 |
| `BlockerConfiguration.shouldBlockApp` | `Sources/NanaFocus/BlockerConfiguration.swift:86` | `(bundleIdentifier: String) -> Bool` | 继续作为是否阻断的唯一判断 |
| `SessionNotificationContract.categories` | `Sources/NanaFocus/SessionNotificationScheduler.swift:43` | `[SessionNotificationCategory]` | 注册 Flow 的通知分类拓扑 |
| `SessionNotificationMessage` | `Sources/NanaFocus/SessionNotificationScheduler.swift:86` | `Equatable, Sendable` 值类型 | 复用标题/正文值契约 |
| `SessionNotificationScheduler.scheduleCompletion` | `Sources/NanaFocus/SessionNotificationScheduler.swift:232` | `(at:nextPhase:autoStartsNext:sound:volume:quote:) -> Void` | 对照现有 UserNotifications 请求构造与异步提交方式 |
| 阻断器控制器测试 | `Tests/NanaFocusTests/BlockerConfigurationTests.swift:6` | `BlockerConfigurationTests` | 锁定只在黑名单命中时触发反馈 |
| 通知契约测试 | `Tests/NanaFocusTests/NotificationCopyTests.swift:4` | `NotificationCopyTests` | 锁定分类、文案、触发器与稳定标识 |

## L1.2 同类路径对照

参考实现：`Sources/NanaFocus/SessionNotificationScheduler.swift:176`

- [x] 使用 `UNMutableNotificationContent` 设置标题、正文和分类。
- [x] 使用 `UNTimeIntervalNotificationTrigger`；本功能按 Flow 二进制固定为 0.5 秒且不重复。
- [x] 使用 `UNUserNotificationCenter.current().add` 异步提交，不在阻断主路径等待系统结果。
- [x] 应用阻断通知显式无声音；不复用会话完成声音设置。
- [x] 每个应用在进程生命周期内复用 UUID，不与固定的 `sessionCompletedNotification` 冲突。
- [x] 通知提交失败不改变阻断结果；权限缺失时仍隐藏黑名单应用并恢复 NanaFlow。

## L1.3 约定清单

| 约定 | 现状 | 我的选择 | 理由 |
|-----|-----|--------|------|
| 通知分类 | 4 个会话完成分类 | 新增无动作的 `notification_app_blocked` | Flow 二进制精确 identifier |
| 文案容器 | `SessionNotificationMessage` | 复用 | 不创建第二个等价值类型 |
| 外部依赖 | 构造器协议注入 | 给 `BlockerController` 注入 `BlockedAppNotificationScheduling` | 可验证且不触发真实系统通知 |
| 阻断判断 | `configuration.shouldBlockApp` | 保持唯一真值 | 避免通知与隐藏分支漂移 |
| 去重 | 会话完成固定 request ID | 每个应用显示名在进程内映射稳定 UUID | Flow 的标题参数与 `blockedAppNotificationIdentifiers` 共用同一字符串 |

## L1.4 Return 语义

| return 形态 | caller 解读 | 测试名 |
|-----------|-----------|--------|
| `handleBlockedApplicationActivation(...) == false` | 非黑名单，不通知、不隐藏 | `testBlockedApplicationFeedbackRunsOnlyForConfiguredApp()` |
| `handleBlockedApplicationActivation(...) == true` | 已排队反馈，调用者继续隐藏应用并激活 NanaFlow | `testBlockedApplicationFeedbackRunsOnlyForConfiguredApp()` |
| `request(...)` 连续返回相同 identifier | 同一应用后一次请求替换前一次未投递请求 | `testBlockedAppNotificationRequestMatchesFlowContract()` |
| `request(...)` 对不同应用显示名返回不同 identifier | 不同名称的应用反馈互不覆盖 | `testBlockedAppNotificationRequestMatchesFlowContract()` |

## L1.5 负向断言

| 输入 | 必须返回 | 测试断言 |
|-----|--------|--------|
| 未列入黑名单的 bundle | `false` 且 spy 无调用 | `XCTAssertFalse` + `requests.isEmpty` |
| 同一应用显示名连续触发 | 稳定 identifier | 两次 request identifier 相等 |
| 不同应用显示名连续触发 | 独立 identifier | request identifier 不相等 |
| 应用阻断通知 | 无声音、无动作 | `content.sound == nil` + category actions 为空 |

## L1.6 回滚

| 类别 | 变更 | 回滚动作 | 顺序 |
|-----|-----|--------|------|
| 代码 | 通知契约/调度器与阻断入口注入 | 工程无 Git；按本计划反向删除新增协议、调度器和调用 | 1 |
| 配置 | 无 | 无 | 2 |
| 数据 | 仅进程内 UUID 映射 | 退出 App 即清空 | 3 |
| 告警 | 无 | 无 | 4 |

回滚后可接受状态：应用仍会被隐藏并返回 NanaFlow，但恢复为没有“为何被挡回”反馈的旧行为。

---

## L2.1 运行时假设

| 假设 | 验证路径 | 环境 | 假设不成立时行为 |
|-----|--------|-----|--------------|
| 系统允许 NanaFlow 通知 | 由用户主动授权后做真实黑名单应用验收 | macOS Debug/Release | 请求可能不展示，但阻断继续生效，不主动弹权限 |
| `UNNotificationRequest` 同 identifier 会替换未投递请求 | Apple UserNotifications 平台契约 + request 单测 | macOS 单测 | 最坏出现相邻重复反馈，不影响阻断 |
| `localizedName` 可用 | 运行态 `NSRunningApplication.localizedName` | macOS | 回退 bundle identifier，标题仍有可识别名称 |

## L2.2 状态机

```text
State0: macOS 激活应用通知
  -> 非专注运行 / 当前 App / 无 bundle -> End_NoAction
State1: 检查浏览器 URL 阻断
  -> bundle 不在应用黑名单 -> End_NoAction
  -> bundle 在黑名单 -> 以应用显示名构造或复用 UUID
State2: 异步提交 0.5 秒无声通知
  -> 立即隐藏目标应用并激活 NanaFlow -> End_Blocked
  -> 通知提交失败 -> 仍 End_Blocked
并发点：同一应用快速重复激活会提交多个请求。
防护：同应用显示名复用 request identifier，由系统保留最后一条待投递请求。
```

## L2.6 权限/安全

| 维度 | 回答 | 证据 |
|-----|-----|-----|
| 身份来源 | 不适用；本机进程事件 | `NSWorkspace.didActivateApplicationNotification` |
| 授权边界 | 不新增或接受通知权限 | 只调用 `UNUserNotificationCenter.add` |
| 凭证泄漏面 | 无 | 通知仅含本地应用显示名 |
| SSRF | 无 | 不访问网络 |
| 租户隔离 | 不适用 | 数据只在当前 App 进程内 |
| 日志脱敏 | 无日志 | 不记录 bundle、应用名或通知内容 |

---

## 剩余风险登记

| 项 | 接受/已知/待后续 | Owner | Follow-up ticket |
|----|----------------|------|-----------------|
| 真实通知展示和系统样式仍依赖用户授权 | 待用户授权后验收 | 用户 / NanaFlow | `PARITY_PLAN.md` 系统级运行验收 |
| Flow 权益态无法安全添加测试黑名单应用 | 已知；以本机资源、二进制调用链和 NanaFlow 单测组合取证 | NanaFlow | 本切片审计记录 |
