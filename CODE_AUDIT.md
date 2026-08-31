# NanaFlow 代码审查记录

审查日期：2026-08-31

## 结论

未发现阻断首次版本基线提交的 P0/P1 代码问题。核心代码、测试、工程配置与原型构建均通过；正式分发仍受 Apple Developer 签名和用户系统授权约束，不能由本地 ad-hoc 验证替代。

## 已验证

| 项目 | 结果 |
| --- | --- |
| macOS 全量测试 | 212/212 通过，0 失败 |
| Release 静态分析 | 干净 DerivedData、关闭签名后通过，0 条 warning |
| Info.plist / entitlements | 4 个文件均通过 `plutil -lint` |
| App Group / KVS 配置 | 主应用、Widget、共享代码与契约测试标识一致 |
| 通用架构包 | `arm64` + `x86_64`，ad-hoc 包通过 `codesign --verify --deep --strict` |
| 真实窗口切换 | 计时器、统计、返回计时器三次量测均为 `380×272` |
| Web 视觉原型 | Vite production build 通过；Sites 测试 4/4 通过 |
| 凭证与危险模式扫描 | 未发现硬编码私钥、API Token 或生产代码强制解包 |

2026-08-31 发现统计页内容高度 `272` 与主窗口内容高度 `240` 不一致。已通过失败测试复现并修正为共用 `TimerVisualMetrics.windowContentHeight`；同一测试、74 项视图回归及 212 项全量回归均通过。

测试环境曾输出 `com.apple.linkd.autoShortcut` 与 `FSFindFolder` 连接信息；它们来自测试进程无法连接对应 macOS 用户服务，未产生测试失败或编译警告。

## 已知边界

- Release entitlement 需要真实 Team、证书和 provisioning profile；当前只能证明声明和降级路径正确。
- 通知、Calendar、Apple Events、Widget Gallery 与 iCloud 跨设备同步，需要正式签名包及用户授权后单独验收。
- `References` 和 `design-qa.md` 是设计证据；`dist`、依赖目录、覆盖率与本机用户状态不进入版本库。

更完整的系统级验收矩阵见 [`Plans/formal-signing-and-system-acceptance.md`](Plans/formal-signing-and-system-acceptance.md)。
