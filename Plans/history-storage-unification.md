# 历史记录统一与迁移安全

目标：把 `UserDefaults.standard` 明确为主记录，把 App Group defaults 限定为 Widget 镜像与恢复源；启动时合并两个来源并回写一致结果，避免签名/沙盒形态变化后历史看似消失。统计界面继续默认展示当前周期，不改变 D/W/M/Y 交互。

用户旅程：作为升级或重装 NanaFlow 的用户，我希望任一旧存储中仍存在的会话都能自动恢复，且不会被空白或损坏副本覆盖。

## L1.1 引用验证

| 符号 | 证据 (file:line) | 签名 | 用途 |
|-----|-----------------|-----|-----|
| `SessionHistoryPersisting.load` | Sources/NanaFocus/SessionHistory.swift:6 | `func load() -> [FocusSession]` | 应用启动读取历史的协议边界 |
| `SessionHistoryPersistence.init` | Sources/NanaFocus/SessionHistory.swift:16 | `init(defaults: UserDefaults = .standard, sharedDefaults: UserDefaults? = nil)` | 注入主记录与共享镜像 |
| `SessionHistoryPersistence.load` | Sources/NanaFocus/SessionHistory.swift:24 | `func load() -> [FocusSession]` | 合并、迁移和自修复入口 |
| `SessionHistoryPersistence.save` | Sources/NanaFocus/SessionHistory.swift:44 | `func save(_ sessions: [FocusSession]) throws` | 同步写入主记录和 Widget 镜像 |
| `SessionHistoryPersistence.merge` | Sources/NanaFocus/SessionHistory.swift:56 | `static func merge(local: [FocusSession], incoming: [FocusSession]) -> [FocusSession]` | UUID 去重并稳定排序 |
| `TimerController.init` | Sources/NanaFocus/TimerController.swift:60 | `init(configuration:persistence:preferencesPersistence:historyPersistence:tagPersistence:notifications:calendarRecorder:tickSound:now:)` | 生产启动调用 `load` 的位置 |
| `NanaFlowShared.defaults` | Sources/NanaShared/NanaFlowShared.swift:209 | `static var defaults: UserDefaults?` | App Group 镜像来源 |
| `testHistoryMirrorsSessionsForWidgets` | Tests/NanaFocusTests/SessionHistoryTests.swift:29 | `func testHistoryMirrorsSessionsForWidgets() throws` | 现有双写契约 |

## L1.2 同类路径对照

参考实现：`SessionHistoryPersistence.save`（Sources/NanaFocus/SessionHistory.swift:44）与云端合并（Sources/NanaFocus/TimerController.swift:657）

- [x] 主记录存在、共享镜像缺失：返回主记录并修复镜像。
- [x] 主记录缺失、共享镜像存在：恢复共享记录并回写主记录。
- [x] 两侧含不同 UUID：并集合并、去重、降序排列并回写两侧。
- [x] 同 UUID 内容冲突：主记录覆盖共享镜像，避免旧 Widget 镜像回滚用户编辑。
- [x] 单侧内部重复 UUID：后写记录胜出，不因 Dictionary 重复键崩溃。
- [x] 相同结束时间：按 UUID 稳定排序，避免无变化时重复回写。
- [x] 一侧 JSON 损坏：忽略损坏侧，保留并复制有效侧。
- [x] 两侧均缺失或损坏：返回空数组，不制造记录。
- [x] `sharedDefaults == nil`：保持单存储行为，不触发 Widget 刷新。

## L1.3 约定清单

| 约定 | 现状 | 我的选择 | 理由 |
|-----|-----|--------|------|
| 存储键 | `focusSessions.v1`（Sources/NanaFocus/SessionHistory.swift:11） | 不改键 | 无需破坏性格式迁移 |
| 编码 | `JSONEncoder` / `JSONDecoder` | 复用 | 已覆盖旧会话默认字段兼容 |
| 去重 | UUID + `merge` | 复用，调用顺序保证主记录胜出 | 最小变更且保持云同步语义 |
| Widget | 保存时写共享 defaults | 保留 | Widget 仍需读取共享数据 |
| 新依赖 | 无 | 不新增 | Foundation 足够 |

## L1.4 Return 语义

| return 形态 | caller 解读 | 测试名 |
|-----------|-----------|--------|
| 非空合并数组 | `TimerController` 直接展示完整历史 | `testLoadMergesPrimaryAndSharedHistoriesAndRepairsBothStores` |
| 仅共享侧有效的数组 | 自动恢复到主记录 | `testLoadRecoversFromSharedHistoryWhenPrimaryIsMissing` |
| 仅主侧有效的数组 | 主记录正常加载并修复镜像 | `testLoadKeepsPrimaryHistoryWhenSharedDataIsCorrupt` |
| 空数组 | 两侧均无可解码历史 | `testLoadReturnsEmptyWhenBothHistoriesAreInvalid` |

## L1.5 负向断言

| 输入 | 必须返回 | 测试断言 |
|-----|--------|--------|
| 主记录为空、共享侧非空 | 共享记录，不是空数组 | 恢复结果及两侧落盘相等 |
| 共享镜像为空、主记录非空 | 主记录，不被空镜像覆盖 | 主记录保留且镜像补齐 |
| 共享镜像为非法 JSON | 主记录 | 不崩溃、不清空主记录 |
| 同 UUID 内容冲突 | 主记录版本 | 标题或标签保持主记录值 |
| 两侧各有唯一记录 | 两条记录 | UUID 集合完整、无重复 |
| 单侧 JSON 含重复 UUID | 单条后写记录 | 不崩溃且 incoming 语义不变 |
| 多条记录结束时间相同 | 每次顺序一致 | UUID tie-break 与原始输入顺序无关 |

## L1.6 回滚

| 类别 | 变更 | 回滚动作 | 顺序 |
|-----|-----|--------|------|
| 代码 | 启动合并与自修复、测试、文档 | `git revert` 对应修复提交 | 1 |
| 配置 | 无 | 无 | 2 |
| 数据 | 首次启动只做两个现有副本的无损并集合并 | 保留合并结果；不自动删除任何副本 | 3 |
| 告警 | 无 | 无 | 4 |

回滚后可接受状态：历史数据仍保留在原有 defaults 中，只失去自动合并能力；不得清理任何用户数据文件。

## L2.1 运行时假设

| 假设 | 验证路径 | 环境 | 假设不成立时行为 |
|-----|--------|-----|-----------|
| 主记录与共享镜像都使用 `focusSessions.v1` JSON | 单元测试注入两个独立 suite | XCTest | 仅使用可解码来源 |
| App Group 在 ad-hoc 与正式签名下可能解析到不同物理位置 | 检查签名权限及本机 preference 路径 | 本机安装包 | 不硬编码物理路径，依赖注入并合并当前可访问来源 |
| 当前 223 条主记录未丢失 | 只读解析现有 plist 并检查 UI 上一周 | 本机真实数据 | 停止迁移，不覆盖现有文件 |
| Widget 镜像可能比主记录旧 | 冲突单元测试 | XCTest | 同 UUID 时主记录胜出 |

## L2.2 状态机

```text
启动 → 分别解码主记录与共享镜像
  A: 两侧有效 → 合并，主记录在 UUID 冲突时胜出 → 必要时回写两侧 → 展示
  B: 仅一侧有效 → 复制到另一侧 → 展示
  C: 两侧均缺失/损坏 → 返回空数组
运行中新增/编辑/删除 → 复用 save → 同步写两侧 → 刷新 Widget
并发点：UserDefaults 写入为同一 MainActor 内串行调用；不新增后台写入。
防护：不删除键、不清空有效数组、不扫描或硬编码用户目录。
```

## L2.6 权限/安全

| 维度 | 回答 | 证据 |
|-----|-----|-----|
| 身份来源 | 本机当前 macOS 用户 | UserDefaults 容器边界 |
| 授权边界 | 仅访问系统授予的 standard 与 App Group defaults | `NanaFlowShared.defaults` |
| 凭证泄漏面 | 无凭证 | 历史模型不含认证信息 |
| SSRF | 不适用 | 无网络请求 |
| 租户隔离 | 单机单用户域 | bundle ID / suite name |
| 日志脱敏 | 不输出标题、标签或完整 JSON | 测试仅比较结构与 ID |

## 验收与提交门禁

1. RED：新增迁移测试在现实现上因 `load` 忽略共享镜像而失败，并提交本地 `test:` 检查点。
2. GREEN：最小实现使迁移测试通过，并修复当前 `main` 上 18 项本地化/结构契约失败。
3. 完整运行 `xcodebuild test`、Release build、`codesign --verify --deep --strict`。
4. 用临时 defaults 验证，不在测试中读取或改写用户真实的 223 条记录。
5. 我独立审查 Claude 的提交与测试证据；只有无高严重度问题才推送 `origin/main`。

## 剩余风险登记

| 项 | 接受/已知/待后续 | Owner | Follow-up ticket |
|----|----------------|------|-----------------|
| 无 Apple Developer 证书时无法验证正式 App Group 容器 | 已知；本次验证依赖注入的两个 suite 和 ad-hoc 实包 | NanaFlow maintainer | 正式签名发布前执行 App Group 迁移验收 |
| `UserDefaults` 不适合超大历史库 | 接受；当前 223 条且无性能问题 | NanaFlow maintainer | 达到 10,000 条或出现启动延迟后评估文件/SQLite |
