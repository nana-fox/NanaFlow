# NanaFlow 正式签名与系统级验收计划

目标：在不改变 Flow 数据、不绕过 Flow 付费权益、不替用户接受系统权限的前提下，把当前本地可运行 NanaFlow 提升为带真实 App Group、iCloud、Calendar、通知、浏览器自动化和 Widget 宿主能力的开发者签名构建，并以真实运行证据关闭系统级缺口。

当前阻塞证据（2026-08-29）：本机 `security find-identity -v -p codesigning` 返回 `0 valid identities found`；两个标准 provisioning profile 目录合计 `0` 个 profile；Release build setting 的 `DEVELOPMENT_TEAM` 未设置。故当前 `dist/NanaFlow.app` 只能作为 ad-hoc 本地验收包，不能证明正式 entitlement 可用。

## 完成判定矩阵

| 要求 | 当前证据 | 判定 | 关闭条件 |
|---|---|---|---|
| 核心计时、菜单、设置、会话、统计、阻断器和辅助窗口 | 211/211 测试、Computer Use 运行态、`design-qa.md` 的同尺寸图 | 已证明当前实现可运行 | 保持全量门禁绿色 |
| 主 App 与 Widget 通用架构 | `dist/NanaFlow.app` 主 App 与 Widget 均为 `x86_64 arm64`，ad-hoc 深度校验通过 | 已证明本地包结构 | 正式签名后重新核对 |
| 主 App 沙盒与系统 entitlement | `Sources/NanaFocus/NanaFlow.entitlements:5` 至 `Sources/NanaFocus/NanaFlow.entitlements:30` 声明完整，但 ad-hoc 包没有这些已授权 entitlement | 未证明运行权限 | 开发者签名包内 entitlement 与源码逐项一致 |
| Widget App Group 与宿主发现 | `Sources/NanaFlowWidget/NanaFlowWidget.entitlements:5` 至 `Sources/NanaFlowWidget/NanaFlowWidget.entitlements:9` 声明同组；生产视图已渲染 | 宿主运行未证明 | Widget Gallery 可发现、添加、配置并读取共享数据 |
| iCloud KVS / Timer Sync | `TimerController.startCloudSync()` 在 `Sources/NanaFocus/TimerController.swift:296` 先读取 KVS entitlement，无 entitlement 时明确降级 unavailable | 未证明真实同步 | 两个同 iCloud 环境实例完成双向字段同步与统计合并 |
| 通知与动作 | `SessionNotificationContract` 在 `Sources/NanaFocus/SessionNotificationScheduler.swift:42` 注册五类分类；路由契约测试已绿 | 系统投递未证明 | 用户授权后真实收到专注/休息/黑名单通知并点击动作成功 |
| Calendar | `TimerSettingsView` 在 `Sources/NanaFocus/TimerSettingsView.swift:225` 按授权态路由 chooser/alert | 系统写入未证明 | 用户授权后选择日历并写入一条可核对会话 |
| 浏览器网页阻断 | `BrowserURLController.blockingScript` 在 `Sources/NanaFocus/BrowserURLController.swift:24` 覆盖 every tab/every window | Apple Events 运行未证明 | 用户授权指定浏览器后 block/allow 各做一次真实验收 |
| Flow Pro 权益态像素完全一致 | 仅免费态付费墙和公开资源可合法读取 | 缺少源真值 | 用户合法取得 Flow Pro 后再做同状态截图；此前不作像素等价声明 |

结论：目标尚未完成；本地核心产品已形成闭环，但正式签名与系统级能力缺少权威运行证据。

## L1.1 引用验证

| 符号 | 证据 (file:line) | 签名 | 用途 |
|---|---|---|---|
| `TimerController.startCloudSync` | `Sources/NanaFocus/TimerController.swift:296` | `func startCloudSync()` | 只在签名包真实携带 KVS entitlement 时启动云同步 |
| `SessionNotificationContract.categoryIdentifier` | `Sources/NanaFocus/SessionNotificationScheduler.swift:51` | `static func categoryIdentifier(nextPhase: SessionPhase, autoStartsNext: Bool) -> String` | 选择四类完成通知拓扑 |
| `BrowserURLController.blockingScript` | `Sources/NanaFocus/BrowserURLController.swift:24` | `static func blockingScript(browser: WebBlockerBrowser, patterns: [String], mode: BlockerMode, blockedPageURL: String) -> String?` | 生成全部窗口/标签页的浏览器阻断脚本 |
| `TimerSettingsView.notificationPermissionBinding` | `Sources/NanaFocus/TimerSettingsView.swift:207` | `private var notificationPermissionBinding: Binding<Bool>` | 按系统授权状态打开、请求或拒绝通知 |
| `TimerSettingsView.calendarPermissionBinding` | `Sources/NanaFocus/TimerSettingsView.swift:225` | `private var calendarPermissionBinding: Binding<Bool>` | 按系统授权状态打开日历选择器或提示页 |
| Release entitlement 契约 | `Tests/NanaFocusTests/PermissionParityTests.swift:7` | `func testReleaseEntitlementsCoverSandboxedSystemIntegrations() throws` | 防止工程声明遗漏沙盒、日历、Apple Events、App Group 与 KVS |
| 浏览器全标签页契约 | `Tests/NanaFocusTests/BlockerConfigurationTests.swift:192` | `func testBrowserBlockingScriptMatchesFlowsAllTabsContract() throws` | 防止退化为仅处理活动标签页 |
| Widget 生产 Bundle 契约 | `Tests/NanaFocusTests/WidgetParityTests.swift:8` | `func testWidgetBundleShipsEnglishConfigurationStrings() throws` | 确认扩展进入 App Bundle 且资源可解析 |

## L1.2 同类路径对照

参考实现：`Sources/NanaFocus/TimerSettingsView.swift:207`

- [x] 已授权：保持开关开启并进入实际功能。
- [x] 未决定：只触发系统授权请求，不提前写成已开启。
- [x] 已拒绝：保持开关关闭并打开 Flow 同语义提示窗。
- [x] 关闭：直接关闭偏好，不再次请求系统权限。

参考实现：`Sources/NanaFocus/TimerController.swift:296`

- [x] KVS entitlement 存在：初始化 store、设备键、同步键和外部变化监听。
- [x] KVS entitlement 缺失：诊断状态为 unavailable，不伪造同步成功。
- [x] Timer Sync 开启：只同步六个已确认字段；统计使用独立合并路径。
- [x] Timer Sync 关闭：不以远端偏好覆盖本地外观、通知、快捷键或标题。

## L1.3 约定清单

| 约定 | 现状 | 我的选择 | 理由 |
|---|---|---|---|
| 主 Bundle ID | `com.nanafox.NanaFlow` | 保持 | 已进入 URL、脚本、资源和持久化契约 |
| Widget Bundle ID | `com.nanafox.NanaFlow.Widget` | 保持 | 与当前嵌入扩展一致 |
| App Group | `group.com.nanafox.NanaFlow` | 主 App/Widget 必须相同 | 共享会话与 Widget 数据 |
| KVS Identifier | `$(TeamIdentifierPrefix)com.nanafox.NanaFlow` | 由真实 Team 展开 | ad-hoc 不伪造 Team 前缀 |
| 权限确认 | 用户在系统弹窗最终确认 | 不代点、不预授权 | 保持系统安全边界 |
| Flow 数据 | 只读 | 不迁移、不修改 | 避免污染源应用数据 |

## L1.4 Return 语义

| return 形态 | caller 解读 | 测试名 |
|---|---|---|
| KVS entitlement 缺失，`startCloudSync()` 提前返回 | Timer Sync 显示 unavailable，不得宣称同步成功 | `TimerSyncParityTests` 全组 + 正式包运行诊断 |
| `blockingScript(...) == nil` | 无支持浏览器或空 block 规则时不执行 AppleScript | `testBrowserBlockingScriptMatchesFlowsAllTabsContract` |
| 通知 route 为 denied | 偏好保持关闭并打开拒绝提示 | `testPermissionRoutingKeepsDeniedFeaturesOff` |
| Calendar route 为 authorized | 打开 chooser，只有完成选择后记录标识 | `testPermissionRoutingKeepsDeniedFeaturesOff` + 正式包运行验收 |

## L1.5 负向断言

| 输入 | 必须返回 | 测试断言 |
|---|---|---|
| 没有开发者身份/profile | 正式 Release build 失败，不能降级宣称正式签名 | `security find-identity`、profile 计数和 `xcodebuild` 退出码 |
| 通知或 Calendar denied | 开关关闭并显示对应提示 | `testPermissionRoutingKeepsDeniedFeaturesOff` |
| block 模式且规则为空 | 不生成 AppleScript | `BlockerConfigurationTests` 的空规则路径 |
| 签名包缺少 KVS entitlement | Timer Sync 为 unavailable | `startCloudSync()` 运行诊断 |
| Widget 与主 App Group 不同 | 发布门禁失败 | 包内 entitlement diff + `testReleaseEntitlementsCoverSandboxedSystemIntegrations` |

## L1.6 回滚

| 类别 | 变更 | 回滚动作 | 顺序 |
|---|---|---|---|
| 代码 | 本计划不要求先改生产代码 | 无代码回滚 | 1 |
| 配置 | Xcode Team / provisioning | 恢复工程未设置 Team；删除仅为验收生成的 Archive | 2 |
| 数据 | 仅创建 NanaFlow 测试会话、日历项和浏览器测试规则 | 删除测试规则/日历项，恢复 NanaFlow 25:00 第一轮暂停态 | 3 |
| 系统权限 | 用户主动授予通知、Calendar、自动化 | 由用户在系统设置撤销；不由自动化代替决定 | 4 |

回滚后可接受状态：保留当前 `dist/NanaFlow.app` ad-hoc 本地包与 211 项绿色回归；所有依赖正式 entitlement 的能力继续明确显示 unavailable 或未验收。

---

## L2.1 运行时假设

| 假设 | 验证路径 | 环境 | 假设不成立时行为 |
|---|---|---|---|
| 用户 Team 可创建主 App、Widget、App Group 与 KVS profile | Xcode Signing & Capabilities + `xcodebuild archive` | 本机真实 Apple Developer 账号 | 停止正式签名，不删除 ad-hoc 包 |
| 通知和 Calendar 权限由用户接受 | Computer Use 停在系统弹窗，由用户确认后继续 | 正式签名包 | 保持功能关闭并记录未验收 |
| 浏览器允许 Apple Events | 对 Safari 或 Chrome 做一条临时 block 规则 | 正式签名包 + 测试标签页 | 不循环重试，记录浏览器级未授权 |
| Widget Gallery 能发现扩展 | 打开图库、添加并配置四种主题 | 正式签名包 | 保留生产视图渲染证据，不冒充宿主通过 |
| 两端使用同一 iCloud 账户 | 修改六字段中的一个并观察另一端 | 两个签名运行实例 | 保持本地状态，Timer Sync 显示诊断信息 |

## L2.2 状态机

```text
State0: 本地 ad-hoc 包
  -> 发现有效 Team、证书和 profile
State1: Archive 正式签名包
  A: codesign entitlement 与源码一致 -> State2
  B: profile/App Group/KVS 不匹配 -> 回到 State0，保留本地包
State2: 用户逐项授予权限
  A: 通知/Calendar/Apple Events 允许 -> State3
  B: 用户拒绝 -> 功能保持关闭，记录未验收
State3: 真实系统验收
  -> 通知动作、Calendar 写入、浏览器 block/allow、Widget、iCloud Sync
State4: 删除临时规则/数据，恢复 25:00 第一轮暂停态

并发点：计时器、浏览器监控和云同步均由同一 MainActor 控制器/状态项生命周期驱动。
防护：每个外部能力独立验收；单项失败不改写其他偏好，不把请求已提交当作系统已成功。
```

## L2.6 权限/安全

| 维度 | 回答 | 证据 |
|---|---|---|
| 身份来源 | Apple Developer Team 和 provisioning profile；当前不存在 | 本机只读签名检查 |
| 授权边界 | 通知、Calendar、Apple Events 均由 macOS 最终裁决 | `Sources/NanaFocus/TimerSettingsView.swift:207` |
| 凭证泄漏面 | 工程与计划不记录 Apple ID、证书私钥或 profile 内容 | 只记录计数和 Team 是否设置 |
| SSRF | 不适用；浏览器阻断只操作本机受支持应用标签页 | `Sources/NanaFocus/BrowserURLController.swift:10` |
| 租户隔离 | 不适用；本地单用户 macOS App | 本地产品边界 |
| 日志脱敏 | 验收记录不写 Sync Key、Device Key、Apple ID 或证书哈希 | 只记录状态与通过/失败 |

---

## 剩余风险登记

| 项 | 接受/已知/待后续 | Owner | Follow-up ticket |
|---|---|---|---|
| Apple Developer 证书和 profiles 缺失 | 待后续 | 用户 | SIGN-01 |
| 系统权限尚未由用户确认 | 待后续 | 用户 + Codex | PERM-01 |
| Flow Pro 权益态源图不可合法触达 | 已知 | 用户 | VISUAL-PRO-01 |
| Widget Gallery 与 iCloud 双端环境缺失 | 待后续 | 用户 + Codex | HOST-01 |
