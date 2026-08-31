# NanaFlow

NanaFlow 是一个原生 macOS 专注计时器。当前产品采用紧凑的单主窗：计时器与 D/W/M/Y 统计在同一窗口内切换，状态栏仅显示倒计时文本。设计参考 Flow 的克制与易用性，但代码、品牌和资源均为独立实现。

## 当前范围

- 25/5/30 默认周期、暂停、继续、跳过、重置与自动开始。
- 主窗口内统计：日 24 小时、周 7 天、月按实际天数、年 12 个月；柱形支持悬浮查看数量。
- 会话记录、设置、通知、日历、快捷键、自动化与 Widget 代码。
- 状态栏倒计时及快速命令；不显示品牌半圆标记。
- 旧版阻断器、标签与迷你计时器模块仅保留兼容代码，不在当前产品入口中展示或启动。

## 工程结构

| 路径 | 内容 |
| --- | --- |
| `Sources/NanaFocus` | 主应用、计时器、窗口与系统集成 |
| `Sources/NanaShared` | 主应用与 Widget 共用模型 |
| `Sources/NanaFlowWidget` | Widget extension |
| `Tests/NanaFocusTests` | 单元、契约与视图回归测试 |
| `Design/flow-ui-prototype` | 可运行的视觉交互原型 |
| `References` | 设计 QA 的截图证据 |
| `project.yml` | XcodeGen 工程定义 |

## 本地开发

要求：macOS 15 或更高版本，以及支持 Swift 6 和 macOS 15 SDK 的 Xcode。

```sh
xcodegen generate
xcodebuild test -project NanaFlow.xcodeproj -scheme NanaFlow -destination 'platform=macOS'
```

无需开发者证书的静态分析：

```sh
xcodebuild analyze \
  -project NanaFlow.xcodeproj \
  -scheme NanaFlow \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

视觉原型：

```sh
cd Design/flow-ui-prototype
npm ci
npm run build
npm run test:sites
```

## 本地安装包

`dist` 只保留一个版本化 ZIP，避免把松散 App、旧 ZIP 和已安装副本混为一谈。当前包为：

```text
dist/NanaFlow-5c71d97-macOS-universal.zip
```

ZIP 内只有一个 `NanaFlow.app`。退出旧版后，将它拖入“应用程序”并选择替换。

## 签名边界

未签名或 ad-hoc 构建适合本机的核心功能与视觉验证。App Group、iCloud KVS、Calendar、系统通知、浏览器自动化和 Widget Gallery 的正式验收，需要 Apple Developer 证书、匹配的 provisioning profile，并由用户在 macOS 中授权。

当前审查证据见 [`CODE_AUDIT.md`](CODE_AUDIT.md)。功能与视觉审查见 [`PARITY_PLAN.md`](PARITY_PLAN.md) 和 [`design-qa.md`](design-qa.md)；第三方资源说明见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
