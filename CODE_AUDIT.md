# NanaFlow 代码审查记录

## 2026-09-21 Mac App Store 准备复查

- 全量 macOS 回归：228/228 通过，0 失败；新增覆盖最小发布权限、主 App/Widget 版本一致、完整会话备份往返和导入失败不丢数据。
- Release 静态分析：`CODE_SIGNING_ALLOWED=NO` 条件下通过。
- Web 视觉原型：production build 通过，Sites 测试 4/4 通过；目录和包名统一为 `nanaflow-ui-prototype`。
- Release entitlement 只保留 App Sandbox、用户选择文件读写和 App Group；Calendar、Apple Events、网络客户端与 iCloud KVS 已移出 1.0 发布包。
- 会话列表新增完整 JSON 备份与合并导入。导入先保存、后替换当前状态，存储失败不会缩减当前历史。
- README 与发布计划已改为 NanaFlow 独立产品定位，Mac App Store 为 1.0 唯一正式发布路线。
- 仍未证明：Apple 会员激活、正式 Team Archive、App Store Connect 上传、商店安装、真实沙盒数据迁移与 Widget Gallery。

## 2026-09-21 功能更新验证

- 新增可选菜单栏今日完成数，主动阶段跳转立即开始；保留自然结束与自动化的原有行为。
- 修正日期/图表桶边界为左闭右开，避免午夜或整点会话重复归属。
- 独立 Swift 回归检查通过：36 种主动跳转组合、通知替换、计时持久化、旧设置兼容、日期/时区边界、自然完成、自动化兼容与强制专注限制。
- 本机编译、应用及嵌入扩展的 ad-hoc 签名校验、工程文件格式校验通过；真实设置开关与重启保留已验证。
- 本机仅有 Swift 6.1.2 / macOS 15.5 SDK 命令行工具，使用不入库的兼容副本完成安装；macOS 26 控制中心 Widget 未包含在该本机包中。**本轮未运行完整 XCTest 或 Release 静态分析**，下方 214/214 结果属于历史基线。

详细范围见 [本次实现与验收记录](Plans/menu-bar-daily-count-and-skip-start.md)。

## 历史基线（2026-08-31）

## 结论

未发现阻断首次版本基线提交的 P0/P1 代码问题。核心代码、测试、工程配置与原型构建均通过；正式分发仍受 Apple Developer 签名和用户系统授权约束，不能由本地 ad-hoc 验证替代。

## 已验证

| 项目 | 结果 |
| --- | --- |
| macOS 全量测试 | 214/214 通过，0 失败 |
| Release 静态分析 | 干净 DerivedData、关闭签名后通过，0 条 warning |
| Info.plist / entitlements | 4 个文件均通过 `plutil -lint` |
| App Group / KVS 配置 | 主应用、Widget、共享代码与契约测试标识一致 |
| 通用架构包 | `arm64` + `x86_64`，ad-hoc 包通过 `codesign --verify --deep --strict` |
| 真实窗口切换 | 计时器、统计、返回计时器三次量测均为 `380×272` |
| Web 视觉原型 | Vite production build 通过；Sites 测试 4/4 通过 |
| 凭证与危险模式扫描 | 未发现硬编码私钥、API Token 或生产代码强制解包 |

2026-08-31 实机复查确认：`272` 是主窗口的完整可见表面，`240` 只是为 32 pt 透明标题栏做的 SwiftUI 根布局补偿。一度将统计页改为 `240` 会在底部暴露 32 pt 白带；最终修复显式定义 `TimerVisualMetrics.windowFrameHeight = 272`，所有已公开的主窗页都共用这一可见表面高度，而根布局补偿仍保持 `240`。Computer Use 实际切换已确认计时器、统计、设置、计时设置和关于页均完整填满 `380×272`、无白带；76 项视图回归及 214 项全量回归均通过。

同轮审查还修正了计时设置步进器/开关的无障碍名称、简体中文“新建全屏窗口”本地化，并删除原生菜单中多余的“关闭菜单”项。最终安装版 AX 与截图证据位于 `References/audit-2026-08-31-final-pass`。

测试环境曾输出 `com.apple.linkd.autoShortcut` 与 `FSFindFolder` 连接信息；它们来自测试进程无法连接对应 macOS 用户服务，未产生测试失败或编译警告。

## 已知边界

- Release entitlement 需要真实 Team、证书和 provisioning profile；当前只能证明声明和降级路径正确。
- 通知、Calendar、Apple Events、Widget Gallery 与 iCloud 跨设备同步，需要正式签名包及用户授权后单独验收。
- `References` 和 `design-qa.md` 是设计证据；`dist`、依赖目录、覆盖率与本机用户状态不进入版本库。

更完整的系统级验收矩阵见 [`Plans/formal-signing-and-system-acceptance.md`](Plans/formal-signing-and-system-acceptance.md)。
