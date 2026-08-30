# 欢迎页正文逐字符对齐

## 范围

将已验收 420×492 欢迎窗口中的标题和正文对齐本机 Flow 4.8.0 简体中文资源；只替换品牌词，保持现有布局、图标、背景和交互不变。

## L1.1 引用验证

| 符号/入口 | 文件:行 | 当前签名/形状 | 本切片约束 |
|---|---|---|---|
| `NanaFlowWelcomeView` | `Sources/NanaFocus/WelcomeView.swift:10` | `struct NanaFlowWelcomeView: View` | 仅改可见正文字符串 |
| 欢迎标题 | `Sources/NanaFocus/WelcomeView.swift:28` | `Text("欢迎来到NanaFlow")` | 已与资源品牌适配值一致 |
| 欢迎正文 | `Sources/NanaFocus/WelcomeView.swift:33` | `Text(...)` | 对齐原资源全部字词与空格，仅替换品牌 |
| 欢迎页测试 | `Tests/NanaFocusTests/ViewRenderingTests.swift:930` | `testWelcomeRenders()` | 先增加精确正文红测 |

权威参考：`/Applications/Flow.app/Contents/Resources/zh-Hans.lproj/Welcome.strings` 中 `Welcome to Flow` 与 `Flow divides your work into sections with defined breaks to help you stay focused and productive.`。

## L1.3 约定清单

- 复用现有源码检查，不新增文案模型或本地化框架。
- 唯一允许的语义变化是 `Flow` -> `NanaFlow`。
- 不改已完成同尺寸验收的字体、宽度、行距、边距、背景与窗口大小。

## L1.4 返回语义

- `WelcomeDisplayPolicy.shouldPresent` 的首次启动/每次启动判定不变。
- “好的”仍关闭 Welcome、打开 timer 并将 NanaFlow 带到前台。
- “在启动时显示此窗口”仍通过同一 `@AppStorage` 键持久化。

## 验收

1. 精确正文检查先失败，再由一处生产字符串修复变绿。
2. 欢迎页定向测试通过；布局指标和渲染测试保持通过。
3. 后续全量门禁吸收该变化。
