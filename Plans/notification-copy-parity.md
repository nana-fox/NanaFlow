# 通知文案逐字符对齐

## 范围

将 NanaFlow 的 10 组专注完成通知和 10 组休息完成通知，逐字符对齐本机已安装 Flow 4.8.0 的简体中文资源；仅把品牌词 `Flow` 替换为 `NanaFlow`。不新增通知架构、权限流程或资产。

## L1.1 引用验证

| 符号/入口 | 文件:行 | 当前签名/形状 | 本切片约束 |
|---|---|---|---|
| `SessionNotificationMessage` | `Sources/NanaFocus/SessionNotificationScheduler.swift:85` | `struct SessionNotificationMessage: Equatable, Sendable` | 标题与正文都按完整值比较 |
| `focusCompleted` | `Sources/NanaFocus/SessionNotificationScheduler.swift:91` | `static let focusCompleted = [...]` | 顺序固定，共 10 条 |
| `breakCompleted` | `Sources/NanaFocus/SessionNotificationScheduler.swift:104` | `static let breakCompleted = [...]` | 顺序固定，共 10 条 |
| `message(nextPhase:index:)` | `Sources/NanaFocus/SessionNotificationScheduler.swift:117` | `(SessionPhase, Int) -> SessionNotificationMessage` | 阶段映射和循环索引语义不变 |
| 通知文案测试 | `Tests/NanaFocusTests/NotificationCopyTests.swift:43` | `testProvidesFlowsTenFocusAndBreakCompletionVariants()` | 先用完整数组红测锁定全部标点、空格和顺序 |

权威参考：`/Applications/Flow.app/Contents/Resources/zh-Hans.lproj/Notification.strings`。源应用只读；品牌适配是唯一允许的文案变化。

## L1.3 约定清单

- 复用现有 `SessionNotificationMessage` 与静态数组，不引入本地化加载层。
- 除 `Flow` -> `NanaFlow` 外，保留参考资源中的中文、标点、空格和排列顺序。
- 不复制 Flow 的专有声音或其他二进制资产。
- 测试先红后绿；完成后运行全量测试、Analyze 和 Release 构建。

## L1.4 返回语义

- `nextPhase == .focus` 表示刚完成休息，返回 `breakCompleted`。
- `nextPhase == .shortBreak/.longBreak` 表示刚完成专注，返回 `focusCompleted`。
- `index` 继续按现有双模归一化循环，正数、超界值和负数都必须安全映射。
- `content` 仅在刚完成专注且存在激励语时替换正文；标题和休息完成正文保持选中文案。

## 验收

1. 完整数组测试在生产修改前失败，并指出当前逐字符差异。
2. 生产数组只做文案值替换后，定向测试和全量测试通过。
3. Analyze 无新增警告，Release 可构建。
4. 完成性审计注明：系统通知真实投递仍取决于用户授予 macOS 通知权限，本切片不把资源/单测证据冒充真实投递证据。
