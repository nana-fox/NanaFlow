# NanaFlow

NanaFlow 是一个原生 macOS 专注计时器，目标是用尽可能少的界面帮助用户开始专注、完成休息，并看清自己的节奏。计时器与 D/W/M/Y 统计在同一紧凑主窗口内切换，菜单栏提供随手可用的倒计时和控制。

## 当前范围

- 25/5/30 默认周期、暂停、继续、跳过、重置与自动开始。
- 主窗口内统计：日 24 小时、周 7 天、月按实际天数、年 12 个月；柱形支持悬浮查看数量。
- 会话记录、完整 JSON 备份与安全合并导入。
- 设置、通知、快捷键、自动化与 Widget。
- 状态栏倒计时及快速命令；可显示 `25:00 | 3`，不显示品牌半圆标记。
- 手动「跳到专注 / 跳到休息」立即开始下一阶段；自然结束仍遵循自动开始设置。
- 1.0 不包含网页阻断器、洞察、标签、迷你计时器和付费墙。

## 菜单栏与阶段跳转

在「设置 → 菜单栏」开启「显示今日完成数」后，菜单栏显示 `倒计时 | 数量`，不额外显示“今日”。开关默认关闭，修改立即生效并在重启后保留；当天尚无已完成专注时显示 `0`。

数量按本地日期和会话结束时间统计，仅包括已完成的专注，不包括休息与中途跳过；与当天统计采用相同口径。日期区间采用左闭右开边界，午夜结束的会话只计入新的一天。

菜单栏、主窗口按钮及菜单、全屏休息界面和全局快捷键中的主动跳转，会从下一阶段的完整时长立即开始。运行、暂停、尚未开始时都适用；强制专注期间仍不能跳过。自然结束以及 URL / AppleScript / App Intents 的既有跳转命令继续遵循自动开始偏好。

设计、实现范围和验收边界见 [菜单栏今日完成数与跳转即开始](Plans/menu-bar-daily-count-and-skip-start.md)。

## 工程结构

| 路径 | 内容 |
| --- | --- |
| `Sources/NanaFocus` | 主应用、计时器、窗口与系统集成 |
| `Sources/NanaShared` | 主应用与 Widget 共用模型 |
| `Sources/NanaFlowWidget` | Widget extension |
| `Tests/NanaFocusTests` | 单元、契约与视图回归测试 |
| `Design/nanaflow-ui-prototype` | 可运行的视觉交互原型 |
| `project.yml` | XcodeGen 工程定义 |

## 本地开发

要求：macOS 15 或更高版本，支持 Swift 6 和 macOS 26 SDK 的 Xcode（控制中心 Widget 使用 macOS 26 API，主应用最低运行版本仍为 macOS 15），以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```sh
git clone https://github.com/nana-fox/NanaFlow.git
cd NanaFlow
```

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
cd Design/nanaflow-ui-prototype
npm ci
npm run build
npm run test:sites
```

## 本地验收构建

没有 Apple Developer 证书时，可以构建并 ad-hoc 签名一份仅供本机验收的 App：

```sh
xcodebuild build \
  -project NanaFlow.xcodeproj \
  -scheme NanaFlow \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath ./DerivedData \
  CODE_SIGNING_ALLOWED=NO

APP=./DerivedData/Build/Products/Release/NanaFlow.app
codesign --force --sign - --timestamp=none "$APP/Contents/PlugIns/NanaFlowWidget.appex"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
open "$APP"
```

## 发布状态

NanaFlow 1.0 以 Mac App Store 为主发布渠道。当前仍处于发布准备阶段：源码可构建测试，但正式签名、App Store Connect 构建和商店安装尚未完成，因此仓库暂不提供“正式版”下载声明。

发布范围、数据迁移和门禁见 [`Plans/mac-app-store-release.md`](Plans/mac-app-store-release.md)。代码审查见 [`CODE_AUDIT.md`](CODE_AUDIT.md)，第三方资源说明见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
