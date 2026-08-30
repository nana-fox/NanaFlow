# 欢迎窗口标题栏融合

## 范围

修复同尺寸对照中新发现的欢迎窗口白色标题栏：让 420×492 外框继续保留原生交通灯，并用背景顶色融合标题栏。最终将标题栏与窗口背景分离后，同图证明主要内容原有 48 pt 顶距才与 Flow 对齐；不再为标题栏问题补偿性移动内容。图标、文案和交互不再改变。

## L1.1 引用验证

| 符号/入口 | 文件:行 | 当前签名/形状 | 本切片约束 |
|---|---|---|---|
| `NanaFlowWelcomeView` | `Sources/NanaFocus/WelcomeView.swift:10` | `struct NanaFlowWelcomeView: View` | 在现有根视图挂载原生窗口配置器 |
| 欢迎窗口背景 | `Sources/NanaFocus/WelcomeView.swift:54` | `.background { Image(...) }` | 继续使用 NanaFlow 自有背景资产；标题栏取资产顶部实测色 |
| Welcome scene | `Sources/NanaFocus/NanaFocusApp.swift:78` | `Window("Welcome", id: "welcome")` | 保持 420×460 内容声明与 420×492 外框 |
| 欢迎页测试 | `Tests/NanaFocusTests/ViewRenderingTests.swift:930` | `testWelcomeRenders()` | 新增真实 `NSWindow` chrome 契约红测 |

视觉参考：`References/audit-2026-08-28-continuation/07-flow-welcome.jpeg`。最新同尺寸比较 `References/audit-2026-08-28-welcome-copy-exact-comparison.jpeg` 明确显示 NanaFlow 顶部多出 32 px 白色标题栏。

## L1.3 约定清单

- 复用项目现有 `NSViewRepresentable` 窗口配置模式；不更换 SwiftUI scene 或自建标题栏。
- 保持原生标题栏的内容布局，只隐藏标题文字、设置透明标题栏与无分隔线；仅给原生 `NSTitlebarView` 铺资产顶部实测 RGB 90/150/144，窗口本体继续保持浅色背景；保留交通灯和窗口拖动。
- 不加入 `.fullSizeContentView`，也不用根视图 `ignoresSafeArea`/无限高度强行扩展固定高内容；两次同尺寸运行证明这些方案会在底部留下 32 px 绿带或压坏内部布局。主要内容保留顶部 48 pt，底部复选框继续由 `Spacer` 锁在原位置。
- 配置前后保存同一外框，避免再次出现内容修复导致窗口尺寸漂移。
- 不隐藏关闭、最小化按钮，不改 Flow 已可观察的窗口能力。

## L1.4 返回语义

- 配置器只修改承载它的 Welcome `NSWindow`，不影响主窗、About、帮助或权限窗口。
- 首次挂载后保持幂等；视图更新不重复改写窗口状态。
- 窗口关闭、打开主计时器和启动时显示偏好语义不变。

## 验收

1. 原生窗口测试在实现前因缺少 full-size/透明标题栏而失败。
2. 实现后断言外框不变、未引入 full-size content、标题隐藏、标题栏透明、分隔线移除、仅标题栏使用绿色底色、窗口本体保持浅色及按钮状态。
3. 重启最新 Debug，通过 Computer Use 获取 420×492 截图，并与 Flow 源图合并同图复核。
4. 通过欢迎页定向测试和后续全量门禁。
