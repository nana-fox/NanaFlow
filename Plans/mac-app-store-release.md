# NanaFlow Mac App Store 发布计划

目标：把 NanaFlow 1.0 作为独立产品提交 Mac App Store，并保证从现有本机版本升级时历史记录可备份、可恢复、不可静默丢失。

当前结论（2026-09-21）：**代码准备进行中，尚未达到提交条件**。Apple Developer Program 已付款但会员仍待激活；因此 Team ID、正式证书、profile、Archive 验证和 App Store Connect 上传都不能宣称完成。

## 已锁定的产品与发布决策

- 产品名保持 `NanaFlow`。
- 公开文案、截图和商店材料只描述 NanaFlow 自身能力，不以竞品比较定位产品。
- 1.0 保留：计时器、同窗口 D/W/M/Y 统计、会话记录、完整备份/导入、菜单栏、通知、快捷键。
- Widget 只有通过真实签名、Widget Gallery 和 App Group 数据共享验收后才进入 1.0。
- 1.0 不包含：网页阻断器、洞察、标签、迷你计时器、付费墙、Calendar、iCloud 同步。
- 首发语言为简体中文和英文；其他翻译不作为 1.0 门禁。
- 1.0 由 Mac App Store 更新，不接入 Sparkle，也不把 GitHub Release 当正式更新通道。
- GitHub 用于源码、测试版和问题反馈；官网用于产品介绍、隐私政策和支持。

## 当前已完成

- Release entitlement 已收敛为 App Sandbox、用户选择文件读写和 App Group。
- 主 App 与 Widget 共用 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`。
- 已声明不使用受限加密，移除 1.0 未提供功能的权限说明。
- 会话历史已支持完整 JSON 备份与合并导入；落盘失败时不会替换当前内存数据。
- Debug 不依赖尚未激活的正式 App Group 签名；Release 仍使用正式 entitlement。

## 分阶段交付

| 阶段 | 交付物 | 完成条件 |
|---|---|---|
| R0 范围与代码 | 1.0 范围、最小权限、版本配置、数据备份 | 全量测试和 Release Analyze 通过 |
| R1 账号与签名 | Team ID、App ID、Widget ID、App Group、自动签名 | Release Archive 成功，主 App 与 Widget Team 一致 |
| R2 数据迁移 | 现有安装备份、商店候选覆盖/并存验证、恢复演练 | 升级前后会话 ID 集合一致；失败可恢复 |
| R3 商店材料 | App Icon、截图、描述、关键词、隐私、支持 URL、审核说明 | 中英文元数据完整且不承诺未发布功能 |
| R4 上传与 Beta | Validate App、上传 App Store Connect、内部安装 | 从商店候选首次启动、重启、计时、统计、备份均通过 |
| R5 提审 | 审核答复、版本说明、发布控制 | 无 P0/P1 数据或计时问题，审核门禁全部通过 |

## 发布门禁

1. `xcodebuild test` 全绿，Release `xcodebuild analyze` 无失败。
2. Archive 的主 App、Widget 和嵌套可执行文件由同一 Team 签名。
3. 包内 entitlement 与 allowlist 一致，不含 Apple Events、Calendar、网络客户端或 iCloud KVS。
4. 主 App 与 Widget 的版本号、构建号一致，App Store Connect 中构建号唯一。
5. Xcode Validate App 通过，App Store Connect 接收构建。
6. 商店候选安装后可启动、退出、重开，并可在菜单栏和主窗口完成完整计时流程。
7. 升级前后历史会话 ID 不减少；备份导入只合并，不删除本地独有记录。
8. Widget 若保留，必须能从 Widget Gallery 添加并读取与主 App 一致的数据；否则从 1.0 移除。
9. 隐私政策、支持 URL、分级、隐私问卷、截图和审核备注完整。
10. README、官网与商店文案使用 NanaFlow 自身定位，不包含竞品导向叙事。

## L1.1 代码引用

| 符号 | 证据 | 用途 |
|---|---|---|
| `SessionHistoryPersistence.load` | `Sources/NanaFocus/SessionHistory.swift:20` | 合并主存储与 Widget 镜像 |
| `SessionHistoryPersistence.merge` | `Sources/NanaFocus/SessionHistory.swift:56` | 以 UUID 去重并稳定排序 |
| `SessionExporter.backupData` | `Sources/NanaFocus/SessionExporter.swift:4` | 无损 JSON 备份 |
| `TimerController.importSessions` | `Sources/NanaFocus/TimerController.swift:485` | 保存成功后才替换当前历史 |
| 主 App Bundle ID | `project.yml:41` | `com.nanafox.NanaFlow` |
| Widget Bundle ID | `project.yml:68` | `com.nanafox.NanaFlow.Widget` |
| Release entitlement | `project.yml:47` | 正式权限文件入口 |
| 最小权限契约测试 | `Tests/NanaFocusTests/PermissionParityTests.swift:7` | 防止未发布权限重新混入 |
| 备份回归测试 | `Tests/NanaFocusTests/SessionExportTests.swift:5` | 保证全部会话字段可往返 |
| 导入安全测试 | `Tests/NanaFocusTests/SessionHistoryTests.swift:704` | 防止导入丢失本机历史 |

## L1.2 数据升级与回滚

升级正式候选前：

1. 退出当前 NanaFlow。
2. 复制现有偏好与会话存储到仓库外的时间戳备份目录。
3. 记录会话数量和匿名 UUID 集合摘要，不记录标题或标签正文。
4. 安装商店候选并启动，核对主存储与 App Group 镜像。
5. 若自动迁移未覆盖旧数据，使用完整 JSON 备份导入；导入只合并 UUID。
6. 核对数量、UUID、设置和正在运行的计时状态后，才允许该候选继续。

失败回滚：停止候选、保留新容器取证、恢复升级前备份并重新安装上一已验收版本。任何迁移代码都不得删除旧存储。

## L1.3 账号激活后的操作

1. 记录 Team ID；在 Xcode 登录同一个开发者账号。
2. 在 Identifiers 注册主 App、Widget 和 App Group，并建立关联。
3. 让 Xcode 自动管理签名；不把 `.p12`、`.cer`、`.mobileprovision` 或 API 私钥提交到 Git。
4. 设置 `DEVELOPMENT_TEAM`，创建 Release Archive。
5. 在 Organizer 执行 Validate App；修复所有错误后上传 App Store Connect。
6. 在 App Store Connect 建立 1.0 版本、元数据、隐私问卷和内部候选。

## L2.1 发布状态机

```text
源码与测试通过
  → Apple 会员 Active
  → 标识符与签名配置完成
  → Release Archive
  → Validate App
  → 上传 App Store Connect
  → 内部商店安装
  → 数据迁移与核心流程验收
  → 提交审核
  → 审核通过后手动发布
```

任何一步失败都停在当前阶段；不得用 ad-hoc 构建替代商店候选，也不得把本地通过描述为已上架。

## L2.2 商店材料清单

- 应用名称、副标题、长描述、关键词、类别和年龄分级。
- 简体中文与英文截图；截图只展示 1.0 实际可用界面。
- 1024×1024 App Icon 及完整 Asset Catalog 槽位。
- 可公开访问的隐私政策 URL、支持 URL 和联系邮箱。
- App Privacy 问卷；按本地存储、通知及未来可选能力如实填写。
- 审核备注：菜单栏应用的启动方式、主窗口入口、通知用途、Widget 验证步骤。
- 版本说明、版权主体和第三方许可。

## 剩余风险

| 风险 | 当前状态 | 处理 |
|---|---|---|
| Apple 会员尚未激活 | 外部阻塞 | 不重复付款；激活后继续 R1 |
| 旧 ad-hoc 数据进入商店沙盒尚未实包证明 | 未完成 | 使用真实数据副本和外部备份验收 |
| Widget 正式共享尚未证明 | 未完成 | 不通过则从 1.0 移除 |
| Intel 与 macOS 15 真机覆盖不足 | 未完成 | Beta 阶段补设备矩阵 |
| 隐私/支持网页尚未发布 | 未完成 | 提审前建立并验证公开访问 |

## 后续但不阻塞 1.0

- 独立官网下载和 Developer ID 分发。
- Sparkle 自动更新。
- iCloud、Calendar 或其他需要额外权限的能力。
- 扩展语言和高级统计。
