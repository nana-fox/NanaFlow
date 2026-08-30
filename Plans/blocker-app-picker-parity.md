# 黑名单应用选择器等价

用户旅程：作为配置专注阻断的用户，我点击“添加”后应立即看到 macOS 原生应用选择器，选择一个 `.app` 后加入黑名单，取消则不修改配置。

权威参考：本机只读 Flow 4.8 运行态。相同应用空态中点击“添加”后，Flow 打开标题为“打开”的原生 `NSOpenPanel`，默认位置“应用程序”，取消后列表保持为空；NanaFlow 当前相同操作无可见结果。

## L1.1 引用验证

| 符号 | 证据 (file:line) | 签名 | 用途 |
|---|---|---|---|
| `BlockerView.applicationList` | `Sources/NanaFocus/BlockerView.swift:268` | `some View` | 保持现有应用列表、选择与移除交互 |
| `BlockerView.addItem` | `Sources/NanaFocus/BlockerView.swift:304` | `() -> Void` | 当前按钮入口；网页分支继续直接提交文本 |
| `BlockerController.addApplication` | `Sources/NanaFocus/BlockerView.swift:41` | `(at: URL) -> Void` | 复用 bundle 校验、去重、持久化与错误反馈 |
| 阻断器 UI 契约测试 | `Tests/NanaFocusTests/BlockerConfigurationTests.swift:250` | `testBlockerAppPickerUsesNonblockingNativeImporter()` | 锁定原生异步选择器、应用类型、单选和默认目录 |

## L1.2 同类路径对照

- [x] 不改应用列表模型、bundle 校验或持久化格式。
- [x] 复用 SwiftUI 原生 `.fileImporter`，不新增选择器服务、协议或依赖；实际打开后再核对默认位置与 Flow。
- [x] 仅应用页的“添加”打开选择器；网页页仍复用现有内联输入。
- [x] 只允许单选 `.application`；成功后调用现有 `addApplication(at:)`。
- [x] 用户取消不写入；非取消错误沿用现有“无法保存”反馈面。

## L1.4 Return 语义

| 结果 | caller 解读 | 验证 |
|---|---|---|
| `.success(url)` | 调用 `addApplication(at:)` | 目标测试 + Computer Use 实选 |
| 用户取消 | 不修改配置 | Flow 只读取消 + NanaFlow 取消实测 |
| 其他失败 | 设置本地错误信息，不改变列表 | 既有 alert 路由 |

## L1.5 负向断言

| 输入 | 必须行为 | 验证 |
|---|---|---|
| 网页标签点击添加 | 不打开应用选择器 | 源码分支契约 |
| 重复应用 | 不产生重复 bundle | 既有控制器测试 |
| 非应用 URL | 不加入列表并显示错误 | 既有 `testControllerRejectsNonBundleApplicationURL()` |

## L2.1 运行时假设

| 假设 | 验证路径 | 不成立时行为 |
|---|---|---|
| `.fileImporter` 在当前主窗口能非阻塞展示 | 已由 Debug 实机点击并读到“打开”面板 | 已验证 |
| 默认目录能与 Flow 一样落在“应用程序” | 已由 Debug 实机读取面板位置 | 已验证 |
| 应用包由 `.application` 类型筛选 | 已选择 `/System/Applications/Calculator.app` | 已验证 |
| 选择器授权足以读取 bundle identifier | 选择后列表已出现“计算器” | 已验证 |

## L2.6 权限/安全

选择器只读取用户明确选择的本地 `.app` 包元数据；不上传、不联网、不改变系统权限。端到端验收结束后移除临时“计算器”规则并恢复计时器/快捷键测试状态。

## 剩余风险登记

| 项 | 接受/已知/待后续 | Owner |
|---|---|---|
| 真实应用阻断与回前台 | 已用“计算器”完成端到端实测，临时规则已删除 | NanaFlow |
| 黑名单系统通知横幅 | 请求契约与命中根路径已通过；macOS 尚未授予 NanaFlow 通知权限，本轮不代用户接受权限 | 用户授权后联测 |
