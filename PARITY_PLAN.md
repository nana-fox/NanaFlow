# NanaFlow 对 Flow 4.8.0 的复刻审查与后续计划

审查日期：2026-08-28

目标：不修改 `/Applications/Flow.app`，不复用 Flow 商标、音频和专有代码；以本机 Flow 4.8.0 的可观察行为、同尺寸截图和包内公开元数据为规格，完成 NanaFlow 的功能与界面等价实现。

当前结论：**核心计时、会话、统计、菜单、设置、帮助、欢迎页、独立休息全屏、通知/日历授权引导、日历选择、Pro 升级入口、Timer Sync、自动化和 Widget 已形成可运行闭环；2026-08-28 精修范围内的主窗（含长时间停顿同状态）、迷你计时器、Widget 四尺寸族、统计、会话列表/详情/编辑、设置、阻断器、About、帮助页、三种授权窗口与 Pro 窗口已通过同图设计 QA，但仍不能宣称整个产品“所有状态完全一致”。** Timer Sync 免费态入口与付费墙、公开帮助文案、同步字段和诊断字段已取得证据并实现；Flow Pro 权益态页面本身及休息全屏像素仍无法在不改变 Flow 设置/权益的前提下合法取得同状态证据。正式 iCloud/App Group、通知投递、全局快捷键和浏览器阻断仍需要用户授权或开发者签名环境。

正式签名与系统级能力的可执行完成矩阵见 `Plans/formal-signing-and-system-acceptance.md`。2026-08-29 本机只读检查为：0 个有效代码签名身份、0 个 provisioning profile、工程 `DEVELOPMENT_TEAM` 未设置；该计划已通过 plan-hygiene 引用校验，因此当前缺口是外部签名环境，不是未定位的代码问题。

## L1.1 引用验证

| 范围 | 代码证据 | 当前语义 |
|---|---|---|
| 会话模型 | `Sources/NanaShared/NanaFlowShared.swift:8` | focus/short break/long break、完成状态和中断数据向后兼容 |
| 计时生命周期 | `Sources/NanaFocus/TimerController.swift:120` | start/pause/resume/skip/reset/tick 汇合于 MainActor 控制器 |
| 会话记录 | `Sources/NanaFocus/TimerController.swift:436` | 超过 60 秒的未完成阶段保留；正常完成记录 focus 与 break |
| 统计导航 | `Sources/NanaFocus/StatisticsView.swift:22`、`Sources/NanaFocus/SessionHistory.swift:88` | 800×450 同窗概览、列表与详情；470×410 会话编辑面板；空态、删除/重置确认和周标题分隔符对齐 Flow 简体中文契约 |
| 标签 | `Sources/NanaFocus/SessionTags.swift:3`、`Sources/NanaFocus/TagManagementView.swift:4`、`Sources/NanaFocus/TimerController.swift:298` | 默认工作/个人/学习标签、蓝黄红颜色与旧数据迁移；管理页按 Flow 4.8 路由拆为概览/添加/编辑，可改标题和颜色；重命名、改色、删除都会原子更新活动选择及历史会话引用并持久化 |
| 主菜单 | `Sources/NanaFocus/TimerOptionsMenuContent.swift:4` | 时长、休息、周期、自动、同步、标签与会话标题 |
| Timer Sync | `Sources/NanaFocus/TimerSyncView.swift:3`、`Sources/NanaFocus/TimerController.swift:240` | 主菜单进入 380×272 同步页；只同步时长、周期和两项自动开始设置，统计独立通过 iCloud 合并；提供 Sync Key / Device Key 诊断 |
| 自定义时长 | `Sources/NanaFocus/CustomDurationView.swift:3` | Flow 主菜单的付费入口对应为主窗内 380×272 已解锁页面；专注、短休息、长休息均可编辑，不再生成 Flow 不存在的独立辅助窗 |
| Fullscreen 窗口 | `Sources/NanaFocus/FullscreenBreakView.swift:3`、`Sources/NanaFocus/TimerView.swift:322` | 自动休息和文件菜单手动命令共用可获得键盘焦点的独立无边框窗口，覆盖当前屏幕；Esc/关闭按钮退出，不再把 380×272 主窗切成系统全屏 |
| 文件菜单 | `Sources/NanaFocus/NanaFlowCommands.swift:6`、`Sources/NanaFocus/SessionNotificationScheduler.swift:210` | 顶级“文件”菜单、独立 Fullscreen 窗口、关闭与全部关闭；手动 Fullscreen 不会被自动休息偏好误关 |
| 设置 | `Sources/NanaFocus/TimerSettingsView.swift:5` | 启动、一般、快捷键、菜单栏、通知、声音、日历与承诺模式 |
| 全局快捷键 | `Sources/NanaFocus/GlobalHotkeyMonitor.swift:68` | Flow 默认 ⌃⌥⌘F/S/R/H、动态解析与系统监听；本地 ⌘, 直接进入主窗设置页且不向应用菜单增加 Flow 不存在的设置项 |
| 快捷键录制 | `Sources/NanaFocus/KeyboardShortcutRecorder.swift:4` | 原生按键录制、Esc 取消、至少一个修饰键、持久化与恢复默认 |
| About/帮助 | `Sources/NanaFocus/HelpViews.swift:4` | 510×306 About 外框与 400×592 使用说明外框，均使用透明标题栏；How It Works 禁用最小化并对齐 Flow 窗口语义 |
| 欢迎页 | `Sources/NanaFocus/WelcomeView.swift:4` | 首次启动、启动时显示复选框、420×460 内容区；420×492 原生外框的标题栏只做背景融合，不改变内容布局 |
| 启动窗口策略 | `Sources/NanaFocus/NanaFocusApp.swift:156` | 欢迎页优先，并真实执行“启动时显示窗口” |
| 快捷指令 / App Intents / AppleScript | `Sources/NanaFocus/AutomationIntents.swift:3`、`Sources/NanaFocus/NanaFlow.sdef:1` | 10 个 App Intent、三态 `Phase`、5 个系统快捷短语；11 个 AppleScript 命令的事件码、参数与结果说明对齐 Flow 公开字典 |
| 权限与日历 | `Sources/NanaFocus/PermissionViews.swift:4` | 通知/日历授权路由、300×272 提示窗、300×332 日历选择器与完整访问语义 |
| 通知 | `Sources/NanaFocus/SessionNotificationScheduler.swift:42`、`Sources/NanaFocus/BlockerView.swift:114` | 专注/休息各 10 组文案与 4 类完成通知动作；黑名单应用另用无动作、无声、0.5 秒延迟的 `notification_app_blocked`，按应用显示名复用进程内 UUID |
| Pro 已解锁窗口 | `Sources/NanaFocus/ProUnlockedView.swift:4` | 650×552 固定原生窗口；保留 Flow 两栏信息层级，以真实已解锁状态替代价格、购买与恢复购买 |
| Widget 配置 | `Sources/NanaFlowWidget/NanaFlowWidgets.swift:7` | 4 种颜色、数量/分钟单位；统计与引语均为 AppIntentConfiguration |
| Release entitlement | `Sources/NanaFocus/NanaFlow.entitlements:1`、`project.yml:43` | 主 App 沙盒、KVS/App Group、日历、浏览器 Apple Events、用户选择文件读写与网络客户端；Widget App Group 仅在 Release 配置 |

## 已通过验收

- [x] 25/5/30 默认计时、15–90 分钟预设、自定义时长、1–8 周期、自动开始。
- [x] 暂停/继续中断记录，skip/reset 的 60 秒阈值，休息会话记录，旧 JSON 兼容。
- [x] 统计只聚合已完成 focus；列表可显示休息与未完成记录；详情显示中断。
- [x] 统计、全部会话、详情和编辑在同一统计窗口内导航。
- [x] 标签、会话标题、CSV/Text 导出、添加/编辑/删除/重置会话。
- [x] 主窗、迷你窗、设置、统计、会话、About、帮助、欢迎页和阻断器均有运行态截图。
- [x] 3 种菜单栏图标、可选会话标题、休息彩色图标；4 个全局快捷键可编辑、可恢复默认并持久化。旧版误暴露的“列表”值只保留解码兼容，不再出现在设置菜单。
- [x] 全局快捷键默认值对齐 Flow 当前 defaults：⌃⌥⌘F/S/R/H；前台使用本地事件监听、后台使用全局事件监听，避免 NanaFlow 自身聚焦时快捷键失效；顶级菜单对齐为“NanaFlow / 文件 / 编辑 / 显示 / 窗口 / 帮助”。
- [x] 专注/休息独立声音、Flow 同范围的 0–100% 连续音量、励志名言；44 个 NanaFlow 自有 AIFF 文件进入 Release 包，系统通知按最接近的 25% 自有资源播放。
- [x] App Intents、URL scheme、SDEF、菜单命令、Widget extension 编译并进入主 App；App Intents 已去除 Flow 不存在的额外“重置”动作与打开参数。
- [x] 快捷指令生成元数据与 Flow 归一化逐项比对无差异：10 个 action identifier、前台策略、output flags/type、参数数量、supported modes、5 个 shortcut action/icon 与 `flow/shortBreak/longBreak` 枚举均一致。
- [x] AppleScript SDEF 在仅替换产品名和 Cocoa 类命名后与 Flow 公开字典 diff 为空；Release 包启用脚本并携带相同 11 个命令事件码，Script Editor 只读执行 `getPhase` 返回当前“长时间停顿”。
- [x] Widget 元数据包含统计 `颜色 + 数量/分钟`、引语 `颜色` 和 4 种颜色枚举。
- [x] 首次欢迎页用真实 Flow 截图做 420×492 外框对照；“好的”进入主计时器。
- [x] 迷你计时器按 Flow 实机 220×112 休息态重做，并完成透明圆角、图标、标题、时间、周期点和播放按钮的 1:1 对照。
- [x] Widget 按 Flow 实机图库重做：实色 4 色主题、浅色前景、居中每日统计、英文衬线励志语与作者署名，并支持小/中/大/超大尺寸族。
- [x] Flow 主包与 Widget 包的 `Quotes.json` 均为 521 条；NanaFlow 不复制该专有语料，保留四条已验收展示内容并以自有原创组合补足 521 条唯一引语。日期索引改为跨年份连续轮换，完成通知复用同一目录，不再出现四天一轮或每年后 156 条永远不可达的问题。
- [x] 统计、会话列表、详情与编辑重做尺寸、日期语义、环比/图表层级、边距与删除样式；会话菜单图标与“重置统计数据”文案也已对齐 Flow 的可观察契约。
- [x] 长时间停顿主窗按 Flow 的 20:00 同状态证据收紧：标题改为“长时间停顿”，与休息态共用背景，标题字号 20、计时字号 75，计时白色像素边界为 192×54（Flow 191×55）。
- [x] 主窗菜单图标不再交给原生 `Menu` 重绘；使用 3 个 5 pt SF Symbols 空心圆环、0 pt 额外间距作为白色竖向可见层，并保留透明 28×28 原生菜单点击层。实机菜单可打开，无障碍树只暴露一个“更多”菜单按钮；最终 380×272 同状态对照与运行截图 `References/audit-2026-08-28-continuation/16-nana-main-menu-rings-final.jpeg` 已复核。
- [x] 时长、休息、周期和标签菜单不再把 `✓` 字符拼进标题；全部改用 macOS 原生菜单状态标记。Flow 与 NanaFlow 最新 AX 标题均只包含“25 分钟 / 4 次 / 工作”等正文，文字缩进、基线、勾选列与辅助功能语义回到同一平台实现。
- [x] 重新以 Flow 实机 AX、命令运行态和二进制窗口类型核对顶级“文件”菜单：三项依次为“新Fullscreen窗口 / 关闭 / 全部关闭”。旧映射错误创建 Mini；现已改为真正覆盖当前屏幕的独立 Fullscreen 窗口，并让“关闭”准确退出该层、恢复主窗。
- [x] 顶级应用菜单已删除 Flow 不存在的“开始/跳过/重置/显示隐藏/设置”五个入口；去品牌化后与 Flow 的“关于 / 服务 / 隐藏 / 退出”AX 结构逐项一致。主窗继续使用无标题 380×272 外观，同时补上 `standardWindow` 无障碍子角色，不再被系统识别为泛化窗口。
- [x] “窗口”菜单不再自动暴露阻断器、标签和自定义时长等 NanaFlow 内部 scene；使用 SwiftUI 原生 `singleWindowList` 与 `commandsRemoved` 后，运行态窗口清单与 Flow 同顺序为 Welcome / About / Notification Alert / Calendar Alert / Calendar Chooser / Pro Upgrade / How It Works / Mini / 统计，末项仅按产品名显示 NanaFlow。
- [x] 主窗以一次性、延后到视图枚举结束后的标准窗配置获得原生填充、居中、半屏、四角和多窗口排列能力；外框仍为 380×272、无白色标题区，缩放项按 Flow 保持禁用，窗口菜单在相同显示器状态下除产品名外逐项一致。
- [x] “建议”子菜单补齐评分、复制链接、邮件、Facebook 与系统分享；五条目顺序和中文文案已通过运行态 AX 核对。复制、邮件、Facebook 与系统分享统一落到可公开访问的 `https://nanafox.com`，不再把只能在本机唤起 App 的 `nanaflow://show` 发给其他人；邮件主题与正文按 Flow 的完整推荐结构适配 NanaFlow。阻断器帮助改为本地原生说明，不再依赖 Flow 官网。
- [x] 通知与日历开关按系统授权状态路由；拒绝态使用 Flow 同尺寸原生提示窗，授权态可选择具体日历并持久化；日历授权图标使用 NanaFlow 自有透明 PNG 资产。
- [x] 完成通知从单一泛化文案扩展为 Flow 可观察的 10+10 文案族；保留 NanaFlow 品牌，不复用 Flow 音频或引语数据。
- [x] Flow arm64 二进制的通知注册与分类选择分支已逐条核对：`pending_flow → 开始`、`pending_break → 开始/跳过`、`autostarted_flow → 打开`、`autostarted_break → 开始/跳过`；NanaFlow 使用相同 identifier、前台动作选项和 `sessionCompletedNotification` 请求标识，并把响应路由到真实计时命令。
- [x] 黑名单应用反馈已接入实际阻断根路径：Flow 4.8 简体中文资源锁定“%@ 在你的黑名单上 / 在Flow期间，黑名单上的应用程序被阻止”，arm64 调用链锁定 `notification_app_blocked`、无动作、`sound = nil`、0.5 秒非重复触发及按应用显示名复用 UUID；NanaFlow 仅做品牌替换，并只在配置命中时排队通知。真实系统展示仍留待用户主动授权后验收。
- [x] 黑名单应用“添加”不再使用会卡住当前 SwiftUI 呈现链的阻塞式 `NSOpenPanel.runModal()`；改为系统原生 `.fileImporter`，单选 `.application` 并默认打开“应用程序”。Debug 实机已选择 `/System/Applications/Calculator.app`，列表显示“计算器”；启动专注后激活计算器会立即隐藏并把 NanaFlow 恢复到前台。验收后已删除临时规则并恢复 25:00、第一轮、暂停态。
- [x] Release 主 App 已启用沙盒，并补齐与现有代码路径对应的日历、用户选择文件读写、网络客户端、Apple Events 自动化和 8 个受支持浏览器临时例外；App Group 与 iCloud KVS 保持原配置。独立契约测试防止正式签名后系统集成功能因 entitlement 缺失失效。
- [x] 主菜单补齐“升级”入口；Flow 650×552 Pro 窗口已取得合法只读证据，NanaFlow 使用同尺寸两栏布局表达“全部已解锁”，不伪造价格、订阅或恢复购买流程。
- [x] Flow 免费态“定时器同步”入口已确认打开 Pro Upgrade；包内 `Timer Sync.strings`、Swift 字段元数据与官方说明共同锁定帮助文案、6 个同步字段和诊断信息。NanaFlow 改为主菜单进入独立同步页，设置页删除 Flow 不存在的重复开关，并避免远端同步覆盖外观、通知、快捷键、承诺模式和本机会话标题。
- [x] Flow 的两个“自定义”时长入口均已确认是付费锁，包内 `Duration.strings` 与 App Router 则确认其权益态为主窗内 `durations` 路由。NanaFlow 已把原 360×260 独立 scene 改成 380×272 主窗内页面，复用返回标题栏与设置卡片规格；取消不写入，保存只更新三种时长。
- [x] Flow 二进制中的 `MiniWindow`、`FullscreenWindow`、`FullscreenView`、`_fullscreenManuallyTriggered` 与 `enableFullscreenAtStartOfBreak` 证明 Mini 和 Fullscreen 是两套独立窗口。NanaFlow 已移除主窗 `toggleFullScreen`，统一用覆盖当前屏幕的独立无边框 Fullscreen 窗口承载自动休息和手动文件命令；红测额外锁定手动触发标记、关闭恢复、Esc 与按钮键盘焦点，并用真实运行态 AX、截图和窗口属性测试验收。
- [x] 标签删除链路已按 Flow 的确认文案补齐；实机验证“工作”行可选、删除按钮启用、确认框可取消且数据不变。控制器删除时同时清理全部历史会话标签并持久化，避免统计筛选继续引用已删标签。
- [x] 统计空态、无标签说明、会话删除与统计重置确认文案已按 Flow 简体中文资源收紧；周标题使用实机确认的 `U+2009 + U+2013 + U+2009` 分隔。
- [x] 浏览器拦截页以 Flow 包内 `zh-Hans/Blocked.html` 和相同 988×768 Safari 视口重新核对：标题、正文、字体、颜色、垂直居中和单行宽度对齐；NanaFlow 使用自有图标与独立生成的真实红色禁止徽标，不复用 Flow SVG。
- [x] 完成性复查清除统计、会话详情、Widget 和 Pro 窗口中的可见旧品牌名；统一为 NanaFlow / NanaFlows，不改动 SDEF 公开命令事件码等不可见兼容契约。
- [x] 菜单栏“设置…”不再依赖不存在的 SwiftUI `Settings` scene；现在先恢复主窗，再异步路由到主窗内设置页。统计概览补齐 Flow 同结构的“统计图表”、逐柱日期/单位和“显示所有会话”无障碍标签，真实 AX 复核通过。
- [x] 完成性截图量化发现标准窗配置把 380×272 内容撑成 380×304，并在底部留下 32 px 白带。主窗现在以 240 pt 内容布局补偿透明标题栏，外框恢复为 Flow 的 380×272；同时保留“填充 / 居中 / 左右上下 / 四角”等原生窗口菜单能力。设置页全部开关补齐与 Flow 相同的可读名称，“其他...”也改回三点文案。
- [x] 独立窗口重新按运行态外框逐一复测：最新同屏量测把 About 从先前误记的 520×312 收紧为 Flow 当前真实的 510×306，并补齐版本、开发者说明、支持/网站链接与版权层级；帮助保持 400×592、窗口名改为 How It Works、最小化禁用并对齐数字空格；Pro 保持 650×552；Welcome 保持 420×492，换用 NanaFlow 自有同构波纹背景并对齐标题、正文和按钮节奏；通知/日历提示 300×272、日历选择器 300×332 均与 Flow 一致。
- [x] 设置页按当前 Flow 380×272 实机重新逐屏审查：卡片末行不再画多余分隔线；不再显示 Flow 免费/关闭态不存在的独立“通知音量”标题行；顶部主体平移误差收敛到 0 px，底部通知卡与滚动末端收敛到约 1 px。快捷键弹层改用 Flow 包内完整的全局/本地说明，声音菜单按实机 11 项顺序显示且不暴露共享资源中的“无”。
- [x] 二次本地化审查收紧主菜单和辅助页：`自动启动NanaFlow会话`、`管理标签`、`编辑会话名称`、标题占位词、Timer Sync 区域警告、自定义时长说明、帮助页长休息标点、阻断器说明及统计导出的 `CSV... / Text...` 均按 Flow 实机或包内简体中文资源对齐。
- [x] 最终版本审查确认本机真值仍为 Flow 4.8.0（126），未误把官网 4.9.2 的标签预设/排序扩进本机复刻范围。Flow 4.8 Core Data 模型中的 `Tag.order / Tag.color`、实际标签色值与 4.8 更新说明共同锁定颜色语义；NanaFlow 现以 `#FF5B8CC0 / #FFE2B658 / #FFD96D5A` 保存工作/个人/学习颜色，旧 `sessionTags.v1` 自动补色，统计柱按标签堆叠、摘要圆环同步着色，无标签仍保持绿色渐变。
- [x] 状态栏改为与 Flow 4.8 相同的原生双键模型：普通左键显示/隐藏主计时器，右键或 Control+左键快速启停，悬停显示阶段/剩余时间；删除 `MenuBarExtra` 生成的非 Flow 下拉菜单，承诺模式继续由控制器统一拒绝暂停。
- [x] CSV 导出不再使用 NanaFlow 自拟的中文六列。Flow 4.8 二进制与会话模型反查锁定六列顺序、日期格式、未完成占位符、标签/标题引号、打断累计时长及扣除打断后的总用时；NanaFlow 已逐项对齐，并保留合法 CSV 的双引号转义。
- [x] Text 导出不再使用 NanaFlow 自拟的“标题 · 时长 · 状态”摘要。Flow 4.8 二进制反查锁定 `{标题或阶段} [标签]: {本地化开始时间} - {本地化完成时间或 ---}`，多条间空一行；NanaFlow 已逐项对齐，空集合按产品名返回 `0 NanaFlows`。
- [x] 统计/所有会话窗口的原生缩放按钮不再被固定内容尺寸禁用；scene 改为与 Flow 相同的可缩放窗口，并以红绿契约测试和最新运行态 AX 复核。
- [x] 阻断器完成第二次行为反查：应用始终使用黑名单，只有网页支持阻止/允许列表；浏览器选择严格收敛为 Flow 4.8 二进制中的 Safari、Chrome、Edge、Brave、Vivaldi、Opera、Sidekick。网页输入改为与 Flow 一致的内联行；浏览器脚本改为遍历所选浏览器所有窗口的全部标签页，并保留 `*` 精确 URL 语义与旧配置迁移。
- [x] 承诺模式不再存在设置旁路：活动专注期间，控制器拒绝关闭承诺模式；主窗、迷你窗、跳过/重置、设置开关和阻断器入口共 6 个现存可见控件同步禁用，状态栏右键启停也经过同一控制器守卫，空格快捷键由主按钮禁用状态覆盖。
- [x] 长历史列表按 Flow 实机精确收敛为每批 100 条并提供“载入更多”；筛选变化回到首批，“显示未完成”使用 Flow 同名 defaults 键持久化。只读核对时 Flow AX 明确显示 100 items，本机 Flow Core Data 共有 10,716 条会话，未修改任何原应用数据。
- [x] 本地快捷键页承诺的 `⌘,` 已接入主窗内设置路由；Flow 实机应用菜单无可见“设置…”项，因此 NanaFlow 使用本地事件监听而不是新增菜单命令。关闭主窗后再次点开 App 也已按 Flow 的 `applicationShouldHandleReopen:hasVisibleWindows:` 生命周期恢复计时器窗口；两条路径均完成真实运行态 AX 验收。
- [x] “全局快捷键”开启后不再只注册 `addGlobalMonitorForEvents`（该 API 不回送本应用事件）；同一套解析器现在同时服务 NanaFlow 前台本地监听与后台全局监听。真实运行态以 ⌃⌥⌘F 启动/暂停、⌃⌥⌘R 恢复 25:00，并在验收后将用户设置恢复为关闭。
- [x] 全局快捷键页写的是“重置循环”，旧动作却只重载当前阶段；⌃⌥⌘R 现改为调用 `resetCycle`。运行态先用 ⌃⌥⌘S 两次进入第 2 轮，再以 ⌃⌥⌘R 返回第 1 轮 25:00，确认不是仅重置剩余时间。
- [x] “计时器启动时隐藏窗口”不再由主视图观察后隐藏当前 `keyWindow`，避免从快捷键、通知或 URL 启动时误关统计/迷你等前台辅助窗。手动启动与阶段自动开始现共用控制器中的同一启动入口，只隐藏 ID 为 `timer` 的主计时器窗；启动时自动计时也遵守同一策略。真实运行态保持统计窗在前台，以 `nanaflow://start` 启动后确认统计窗仍可见、主窗隐藏，再恢复 25:00 暂停态。
- [x] 早期额外状态栏下拉菜单中的周期操作曾从“跳过 / 重新开始”收紧为阶段化文案；本轮确认 Flow 4.8 状态栏本身没有这套下拉菜单后已整体删除。跳过与重启仍由主窗悬停工具栏承载，其中“重新开始周期”调用整周期重置。
- [x] 标签管理不再把概览、创建和选择挤在同一页。Flow 4.8 包内 `TagsOverview / TagEditView / tags / addTag / editTag` 与简体中文资源锁定三段拓扑、标题字段和颜色选择；NanaFlow 已实现概览/添加/编辑路由、重命名、改色与删除，新增标签不会意外切换当前会话标签，历史会话引用随重命名或删除同步持久化。最新 Debug 实机已逐页检查 AX、布局、保存禁用态和三色选择，未改动现有“工作”标签。
- [x] 主窗悬停工具栏不再把 Flow 的“重新开始周期”回转按钮误接到 `previous`。当前 Flow 休息态 AX 逐项读出“跳过休息时间 / 重新开始周期 / 统计 / 菜单”，NanaFlow 现让同位置按钮调用 `resetCycle()`，并把主窗与全屏休息的跳过辅助文案统一为“跳过休息时间”。`previous` 继续只服务公开 AppleScript/自动化契约，不再混入主窗工具栏。
- [x] 状态栏默认标签不再额外显示计时器 SF Symbol 和默认会话标题。Flow 4.8 当前运行态确认倒计时位于 18 pt 紧凑胶囊描边内；NanaFlow 现使用等宽数字、6 pt 水平内边距和 1 pt 胶囊描边，并把会话标题默认关闭，可见样式收敛为“默认 / 圆形 / 进度条”。圆形样式使用 determinate circular progress（暂停时显示暂停符号），进度条样式使用 22 pt 原生 linear progress。目标红绿测试及同屏菜单栏截图已确认与 Flow 对齐。
- [x] 补齐周期完成庆祝动画。Flow 官方说明和 Changelog 明确它只在一轮最后一个专注自然完成、进入长休息时出现；本机 4.8 arm64 视图元数据进一步锁定 119 个白色粒子、1.5 秒 ease-out、0.1–0.3 透明度、3–6 pt 尺寸、20–220 pt 径向位移和 120° 旋转。NanaFlow 现按同一触发语义和参数覆盖长休息主窗，跳过最后一轮不会误触发，并在“减少动态效果”下不播放。
- [x] 补齐付费音量控制。Flow 官方说明明确 Mac 可分别调节通知与节拍器音量；本机 4.8 arm64 的 `SettingsVolumeView`、`_notificationsVolume` 与 `_metronomeVolume` 进一步锁定 0...2 滑杆、small 控件、5 pt 垂直/8 pt 水平留白及 `volume × 50` 百分比。NanaFlow 在对应功能开启时显示同构紧凑滑杆，滴答播放与通知预览统一把 0...2 归一化为系统 0...1 音量；未复制 Flow 专有滴答音频。
- [x] 完成通知不再只满足“10+10 条”的数量近似。本机 Flow 4.8 `zh-Hans.lproj/Notification.strings` 逐字符锁定全部标题、正文、标点、空格与顺序；NanaFlow 仅做 `Flow → NanaFlow` 品牌替换，并以完整数组红绿测试覆盖 20 条文案、阶段映射、循环与负索引语义。
- [x] 欢迎页不再停在“外框尺寸接近”。本机 Flow 4.8 `Welcome.strings` 锁定精确简体中文正文；最新 420×492 同尺寸对照发现 NanaFlow 多出 32 px 白色标题栏。现仅给原生 `NSTitlebarView` 铺欢迎背景顶色，保留交通灯、拖动和 420×460 固定内容布局，图标、标题、正文、按钮和复选框纵向节奏与 Flow 对齐，底部不再被窗口底色污染。
- [x] “所有会话”工具栏不再显示 SwiftUI `Menu` 默认附加的两个下拉箭头；过滤与更多按钮均显式隐藏原生菜单指示器。进一步用 Flow 与 NanaFlow 的缩放按钮做动态对照后，发现旧统计内容仍固定为 800×398 并在放大窗口中居中留白；外层现改为保留 800×398 最小尺寸、向可用宽高无限伸展，概览与会话列表都会像 Flow 一样铺满放大窗口。两处均先有失败契约测试，再以 800×450 正常态和放大态实机同图收口。
- [x] “所有会话”筛选菜单进一步按 Flow 运行态收敛为不可操作的“按标签过滤”分组标题、原生单选标记与仅在已筛选时出现的“清除过滤”减号入口；删除 NanaFlow 多出的“所有标签”动作并统一文案。运行态 AX 已确认默认态、选中态和清除后恢复，且未修改 Flow 数据。
- [x] CSV/Text 导出不再在 SwiftUI 菜单动作中同步调用 `NSSavePanel.runModal()`，也不再依赖会被菜单关闭时序吞掉的 `.fileExporter` 展示状态；现在先生成既有 Flow 等价格式，再在下一主线程周期用 `beginSheetModal` 异步挂载原生保存面板。最新运行态通过原生键盘导航真实触发两个叶子项，保存面板分别显示默认名 `NanaFlow 会话.csv` 与 `NanaFlow 会话.txt`；两次均点击“取消”，面板关闭且没有写文件。运行截图保存在 `References/audit-2026-08-28-export-panels/`。
- [x] 主窗运行态按钮的可访问名称不再使用 NanaFlow 自拟的“暂停”。Flow 4.8 当前运行态 AX 明确暴露“停止”，NanaFlow 已仅对有直接证据的主窗改为相同语义；定向红测先以 1/1 失败锁定差异，绿测与真实运行态 AX 再确认“停止”，随后恢复为 25:00、第一轮、暂停态。迷你窗和 Fullscreen 未在没有同状态证据时跟随猜改。
- [x] 主窗右上角菜单控件不再使用 NanaFlow 自拟的“更多”辅助语义。Flow 当前 AX 的 Help 为“菜单”；NanaFlow 已把无障碍标签与 tooltip 统一为“菜单”，定向红绿测试及 Debug 重启后的真实 AX 均通过。同期对照确认两边“窗口”菜单的内部窗口列表相同，App Intents 均为 9 个动作与 5 个 App Shortcut，无需误删或重构。
- [x] 主窗运行态视觉再收口：Flow 专注态暂停图标使用绿色强调色，NanaFlow 旧版仍沿用深色前景；低进度胶囊还会因 `Capsule` 自缩放退化成竖线。现以阶段色单独驱动主按钮前景，并用矩形进度填充后统一裁成胶囊，保留既有标题、计时、周期点、42 pt 按钮和顶部工具栏坐标。定向红绿测试、Debug 重载和 380×272 同尺寸合图均通过；专注态不显示跳过按钮与 Flow 当前行为一致，未误改。
- [x] 主窗悬停与低进度细节继续收口：Flow 只在指针进入顶部 50 pt 工具区时显示关闭、重置和统计，NanaFlow 旧版进入整窗就显示，造成计时区常驻杂乱控件；现把悬停命中区限制到顶部并加 0.12 秒淡入淡出。当前周期刚开始时，进度填充宽度至少等于 12 pt 高度，不再缩成一根竖线。目标测试先红后绿，380×272 运行态同图无剩余 P0/P1/P2。
- [x] 主菜单与设置页按当前运行态再审：两边菜单弹层都由 macOS 原生 `Menu` 承载，结构差异来自 Flow 免费态锁项与 NanaFlow 已解锁功能，不自绘另一套菜单皮肤。设置页顶部和中段分别在 380×272、窗口激活态同图复核；标题、返回按钮、卡片、行高、分隔线、滚动条、胶囊值和绿色开启态一致。首次看到的 NanaFlow 灰色开启态来自窗口未激活，点击激活后恢复绿色，因此未制造错误的生产改动，也未修改 Flow 或 NanaFlow 偏好。
- [x] 建立可运行的英文本地化第一切片：`en / zh-Hans` 已作为真正的 `Localizable.strings` Variant Group 编入 App Bundle；主窗阶段标题、菜单按钮、系统菜单、完整主菜单、推荐子菜单和周期辅助文案均在独立英文进程中通过 AX。周期数量使用 `.stringsdict`，真实输出 `1 session / 2 sessions`；新英文安装的三个默认标签按英文创建，既有标签不被改名。
- [x] 英文本地化第二切片覆盖设置、统计/所有会话、应用与网页阻断器、About、How It Works、Timer Sync、授权提示资源和 Widget 配置。日期格式改用当前区域，动态设置值、状态、分钟数、导出文件名和标签摘要均通过本地化格式串；Widget 扩展正式携带 `en / zh-Hans` 资源。独立 `AppleLanguages=en / AppleLocale=en_US` 进程的 AX 逐页确认英文正文、`8/24/2026–8/30/2026` 日期与 Back/Remove/Help 辅助语义；窗口菜单的统计入口也不再残留中文。授权提示页由英文 Bundle 契约与生产视图渲染测试覆盖，未借验收接受任何系统权限。
- [x] 英文本地化第三切片覆盖标签概览/新增编辑、自定义时长、Welcome 和 NanaFlow 自有的 Pro 已解锁页。动态标签删除文案、使用次数、标题栏与时长行改走原生本地化格式，分钟值复用既有 `localizedMinutes`；独立英文进程逐页 AX 确认文案、按钮和辅助语义，未保存标签或时长、未改变启动选项，验收后恢复简体中文 25:00 第一轮暂停态。
- [x] 英文本地化第四切片收口后台与系统表面：20 组专注/休息完成通知按 Flow 4.8 二进制英文原文建立稳定资源键，黑名单通知、保存/同步错误、日历备注、快捷键录制、分享正文和动态分钟菜单均走原生本地化；App Shortcut 短语改为 Flow 元数据中的精确英文模板，文件菜单运行配置改为按当前语言标题查找。源码与英文资源交叉扫描已无未覆盖的中文字符串字面量；通知横幅仍不冒充已获系统授权后的实机投递。
- [x] 多语言第五切片把 Flow 4.8 的 20 个实际语言区全部接入主 App 与 Widget：新增 `ca/de/es/fr/it/ja/ko/nb/nl/pl/pt-BR/pt-PT/ru/sv/tr/uk/vi/zh-Hant`，每个新语言文件都包含与英文相同的 340 个键，至少 250 个值不再回退英文，并禁止残留独立 Flow 品牌。繁中、日文、德文、韩文、法文独立进程已真实验证主窗、菜单、设置、Timer Sync 与 Pro 页；运行审查先后修复繁中 `New Fullscreen Window` 和“终身访问”、日文/德文周期菜单 `sessions`，以及德文 Pro 页 `Lifetime` 泄漏。繁中、韩文普通字符串已无英文回退；日文、德文、法文只保留目标语言中惯用或 Flow 4.8 同语言资源明确使用的同形短词，五种语言周期格式均已本地化。Flow 法文 Pro 资源本身将“网页阻断和日历同步”写成 `Webblokkering et kalendersynchronisatie`，NanaFlow 为忠实复刻保留该源文案而不擅自润色。
- [x] 多语言第六切片完成西班牙语、意大利语和加泰罗尼亚语：与英文相同的值分别从 69 项收敛到 11、10、11 项，余项均为 Flow 官方资源或目标语言中确实同形的词；周期格式改为 `sesión/sesiones`、`sessione/sessioni`、`sessió/sessions`。三个独立语言进程均实机检查主窗、菜单、设置、Timer Sync 与 Pro 页；西班牙语 Pro 功能行的截断通过既有单行文字最小缩放修复，不缩短 Flow 原文。Flow 加泰罗尼亚语资源本身包含 `Nach Anmeldung öffnen` 和 `Pausa llarg`，为源产品忠实度保留。验收后删除临时语言覆盖，中文 25:00 第一周期暂停态和中文主菜单已由 Computer Use 确认。剩余 10 个语言区各有 63–78 个与英文相同的值，周期格式仍是英文。
- [x] 多语言第七切片完成巴西葡萄牙语和葡萄牙葡萄牙语：两区与英文相同的值均从 68 项收敛到 12 项，保留项均为 Flow 官方资源或葡萄牙语中确实同形的词；周期格式改为 `sessão/sessões`，并清除 `Duração do flow`、`Iniciar flows automaticamente` 等产品名漂移。两区均在独立进程实机检查主窗、菜单、设置、Timer Sync 与 Pro 页，没有新增截断、重叠或拥挤；`app/aplicação`、`salvar/guardar`、`assinatura/subscrição`、`tela/ecrã` 等地区差异按各自语言保留。验收后删除临时语言覆盖并恢复中文 25:00 第一周期暂停态。剩余 8 个语言区各有 63–78 个与英文相同的值，周期格式仍是英文。
- [x] 多语言第八切片完成荷兰语和挪威语（Bokmål）：与英文相同的值分别从 78、68 项收敛到 22、12 项，余项均为 Flow 官方资源明确保留或目标语言中确实同形的词；周期格式改为荷兰语 `sessie/sessies` 与挪威语 `økt/økter`。两种独立语言进程均实机检查主窗、菜单、设置、Timer Sync 与 Pro 页，没有新增截断、重叠或拥挤；荷兰语自定义时长中的小写 `flows` 产品名漂移也已清除。验收后删除临时语言覆盖并恢复中文 25:00 第一周期暂停态。剩余 6 个语言区各有 63–70 个与英文相同的值，周期格式仍是英文。

## 最新闸门证据

| 闸门 | 结果 | 证据 |
|---|---|---|
| 全量测试 | 212/212，0 failures | `/tmp/nanaflow-final2-full-test.log`；包含主窗口可见表面完整填满的回归 |
| xcresult | 可复查 | `/tmp/nanaflow-final2-derived.MeY1le/Logs/Test/Test-NanaFlow-2026.08.31_08-56-31-+0800.xcresult` |
| 覆盖率 | 全 App 75.25%（7866/10453） | 同一 xcresult；本次尺寸派生与一致性断言已执行 |
| App Intents 元数据 | 归一化 diff 为空 | `/tmp/nanaflow-window-parity-final-appintents.diff` |
| AppleScript SDEF | 品牌与 Cocoa 类命名归一化后 diff 为空；自动化实机返回“长时间停顿” | `/tmp/nanaflow-window-parity-final-sdef.diff`；Script Editor 实机调用 |
| Release entitlement | 契约测试通过；`ENABLE_APP_SANDBOX=YES` | Flow 已签名 entitlement + NanaFlow Release build settings / plist 机器核对 |
| Analyze | `ANALYZE SUCCEEDED` | 干净 Release DerivedData、0 warning，日志 `/tmp/nanaflow-final2-analyze.log` |
| Release | 本地通用包可运行，主 App 与 Widget 均为 arm64 + x86_64 | `dist/NanaFlow-5c71d97-macOS-universal.zip`；解压后深度签名校验通过，ZIP SHA-256 为 `4bd9ed71621e4783ea4b984fd580d9c0cdc3665b99d6d6aa15cf0dc2a9dda10d` |
| Release 签名 | 未通过 | 本机无 Apple Developer identity；使用 `CODE_SIGNING_ALLOWED=NO` 构建 |
| 运行态资源 | 通过 | 44 AIFF、ICNS/PNG（含 1254×1254 Alpha 日历授权图标）、简体中文权限说明、SDEF、欢迎背景、Widget、App Intents 均在包内 |
| 稳态资源占用 | 通过 | 暂停且隐藏窗口时连续 6 次采样为 0.0–0.1% CPU、约 21 MB；运行态保持 1 Hz |

## 同尺寸视觉证据

- 主窗：`References/audit-2026-08-28-main-refined-focus-comparison.jpg`；本轮另将 Flow 与 NanaFlow 都调到休息 04:42、第三轮、暂停态实机复查，背景、标题、数字、分页与按钮未发现新的可执行视觉差异；该临时同状态检查未冒充保存的合图证据。
- 主窗运行态精修：`References/audit-2026-08-29-main-running-polish-comparison.png`；左 Flow / 右 NanaFlow，均为 380×272。两边处于不同倒计时和周期索引，因此只用于核对共享几何、阶段色、主按钮与进度填充，不把真实状态差异当作布局偏差。
- 设置页激活态：`References/audit-2026-08-29-settings-menu/06-settings-top-active-comparison.jpeg` 与 `09-settings-middle-active-comparison.jpeg`；左 Flow / 右 NanaFlow，均为 380×272。顶部“在登录时启动”开关反映各自真实用户偏好；中段用两边都开启的“计时器启动时隐藏窗口”核对绿色开启态。
- 长时间停顿主窗（20:00 同状态）：`References/audit-2026-08-28-main-long-break-menu-final-comparison.png`；5 pt/0 pt 菜单圆环复核为 `References/audit-2026-08-28-main-long-break-menu-rings-comparison.png`
- 迷你计时器：`References/audit-2026-08-28-mini-refined-comparison.jpg`
- Widget：`References/audit-2026-08-28-widgets-full-comparison.png`
- 统计：`References/audit-2026-08-28-statistics-refined-comparison.png`
- 会话列表：`References/audit-2026-08-28-sessions-refined-comparison.png`
- 会话列表工具栏终审：`References/audit-2026-08-28-menu-final/04-sessions-normal-fixed-comparison.jpeg`（左 Flow / 右 NanaFlow，均为 800×450 活动窗口）；局部工具栏同图为 `References/audit-2026-08-28-menu-final/05-sessions-toolbar-focused-comparison.jpeg`。放大态内容伸展对照为 `References/audit-2026-08-28-menu-final/03-sessions-zoomed-fixed-comparison.jpeg`；两侧位于不同显示器，宽度不同，因此只用于判断内容是否随窗口铺满，不用于像素坐标比较。
- 导出保存面板：`References/audit-2026-08-28-export-panels/01-csv-save-panel.jpeg`、`02-text-save-panel.jpeg`；均由“所有会话 → 更多 → 导出”真实触发，默认文件名和取消路径通过，没有写文件。
- 会话详情：`References/audit-2026-08-28-session-detail-refined-comparison.png`
- 会话编辑：`References/audit-2026-08-28-session-edit-refined-comparison.png`
- About：`References/audit-2026-08-28-continuation/03-flow-about.jpeg`、`14-nana-about-final-sized.jpeg`（运行态外框均为 510×306）
- How It Works：`References/audit-2026-08-28-continuation/11-flow-how-it-works.jpeg`、`13-nana-how-it-works-final.jpeg`（运行态外框均为 400×592）
- 设置：`References/audit-2026-08-28-settings-top-final-current-comparison.png`、`References/audit-2026-08-28-settings-bottom-final-current-comparison.png`（当前实机 380×272 左 Flow / 右 NanaFlow）
- 快捷键设置：`References/audit-2026-08-28-nanaflow-keyboard-shortcuts.jpeg`
- 阻断器：`References/audit-2026-08-28-blocker-final-comparison.jpg`；本轮只读应用空态同输入对照为 `References/audit-2026-08-28-blocked-app-notification/03-blocker-apps-empty-comparison.jpeg`（左 Flow / 右 NanaFlow）。Flow 网页标签上的 Pro 锁属于权益边界，NanaFlow 按“付费功能全部解锁”目标不保留该锁，不把产品边界差异误报为布局缺陷。
- 拦截结果页：`References/audit-2026-08-28-remaining/06-blocked-comparison.jpeg`（左 Flow / 右 NanaFlow，相同 Safari 988×768 视口）；单图为同目录 `06-flow-blocked-reference.jpeg` 与 `06-nanaflow-blocked-final.jpeg`。
- 授权窗口：`References/audit-2026-08-28-notification-copy-final.png`、`References/audit-2026-08-28-calendar-copy-final.png`、`References/audit-2026-08-28-calendar-chooser-final.png`（均为运行态左 Flow / 右 NanaFlow）
- Pro 窗口：`References/audit-2026-08-28-pro-outerframe-final.png`（运行态左 Flow 升级页 / 右 NanaFlow 已解锁页，均为 650×552）
- Timer Sync：`References/audit-2026-08-28-remaining/01-flow-timer-sync-paywall.jpeg`（Flow 免费态合法入口结果）、`02-nanaflow-timer-sync-enabled.jpeg`（已解锁同步页）、`03-nanaflow-settings-no-duplicate-sync.jpeg`（设置页去重）；因 Flow Pro 页面不可见，不把这组三图称为像素级同图对照。
- 自定义时长：`References/audit-2026-08-28-remaining/04-nanaflow-custom-durations-embedded.jpeg`；Flow 免费态两个入口均进入同一 Pro Upgrade 页，权益态像素不可见，因此本图只证明已解锁路径与主窗内布局，不冒充同图对照。
- 休息全屏：`References/audit-2026-08-28-remaining/05-nanaflow-fullscreen-break.jpeg`；Flow 当前“休息时全屏”设置保持关闭，未为取图修改 Flow 偏好，因此这里只证明 NanaFlow 独立窗口的实际覆盖、交互与设计系统复用，不冒充 Flow 同状态像素对照。
- 欢迎页：`References/audit-2026-08-28-welcome-titlebar-final-comparison.jpeg`（左 Flow / 右 NanaFlow，运行态外框均为 420×492；标题栏、主要内容与底部区域在同一输入中复核）

这些证据证明布局接近，不等于所有动态状态已经像素级一致；主窗、统计与会话对照包含不同计时/历史数据，必须与“同状态”验收分开报告。会话编辑中标题/标签保持可编辑，Pro 窗口不显示价格/购买而显示已解锁，都是对“解锁付费功能”的明确产品边界。

## 未通过与后续顺序

1. **后续不可合法触达的视觉证据**：Pro Upgrade 页与 Timer Sync 免费态入口已捕获；同步页依据 Flow 包内完整本地化、Swift 字段元数据、公开产品说明和现有 380×272 设计系统实现，但 Flow Pro 权益态页面仍无法在未购买/未绕过付费的前提下打开。休息全屏也只取得了 Flow 的独立窗口结构证据，没有修改其当前关闭的偏好来取图；两者均不宣称像素级一致。
2. **系统级运行验收**：授权分支、提示窗、日历选择和通知按钮的注册/响应路由已完成；应用选择、黑名单命中、隐藏目标应用与恢复 NanaFlow 前台已用“计算器”真实验收。macOS 通知偏好中仍没有 NanaFlow 授权条目，因此黑名单横幅、其他真实通知投递与按钮点击，以及日历写入、全局快捷键的 Input Monitoring、Safari/Chrome Apple Events 阻断仍需用户主动授权后再验。通知分类拓扑来自 Flow 二进制注册与选择逻辑，不把已排队的请求冒充为系统已展示。
   AppleScript 的公开 SDEF 与只读 `getPhase` 已验；`previous` 现已结合 Flow 官方 Changelog 的“back button / cycle navigation”记录与 arm64 状态迁移分支完成复核：已开始的阶段重载当前计时，尚未开始的阶段退回上一阶段，且两种路径都不自动开始。该命令保留为独立自动化契约；当前 Flow 主窗回转按钮的 AX 明确为“重新开始周期”，因此主窗已改回 `resetCycle()`，不再误复用 `previous`。
3. **生产签名与跨设备**：提供 Apple Developer Team 后，执行正式签名、App Group/iCloud KVS 双设备同步和 Widget 数据共享验收。
4. **Widget 宿主验收**：四尺寸生产视图已完成原生尺寸渲染和同图设计 QA；未签名 Debug extension 无法在系统小组件图库稳定发现，仍需生产签名后验证拖放、配置面板与 App Group 数据刷新。
5. **本地 Release 与正式签名边界**：当前 `dist/NanaFlow-5c71d97-macOS-universal.zip` 内的 App 已以 ad-hoc 签名通过 `codesign --verify --deep --strict`；它适合本机功能与视觉验收。App Group、iCloud、Calendar、通知、浏览器自动化权限和 Widget Gallery 仍需 Apple Developer 证书及 provisioning profile，不能把本地可运行包冒充正式分发签名。
5. **评分入口**：Flow 的“为应用评分”会打开 App Store 原生评论流程；NanaFlow 当前本地构建保持无动作，因为 [Apple Lookup](https://itunes.apple.com/lookup?bundleId=com.nanafox.NanaFlow) 对 `com.nanafox.NanaFlow` 返回 `resultCount: 0`。在正式上架并取得 App Store ID 前，不把该文案错误接到官网、邮件或伪评论页；上架后补接真实商店评论地址并做运行验收。
6. **标签权益态像素**：标签三段路由、字段、颜色语义和行为已经由 Flow 4.8 包内类型/文案与 NanaFlow 运行态证明，但 Flow 侧标签管理被 Pro 权益挡住，尚无合法同状态源截图，因此只声明结构与功能等价，不声明该新增页面已完成像素级同图验收。
7. **多语言覆盖**：Flow 4.8 的 Base 与 20 个实际语言区均已在 NanaFlow 工程声明，全部 20 个 `Localizable.strings` 已进入主 App 与 Widget。繁中、日文、德文、韩文、法文、西班牙文、意大利文、加泰罗尼亚文、葡萄牙语两区、荷兰文和挪威文已完成主窗、菜单、设置、Timer Sync 与 Pro 页运行抽查，周期格式也已本地化；保留的英文同形词均有 Flow 官方资源或目标语言语义依据。其余 6 个语言区仍各有 63–70 个与英文相同的值需要逐项判断，周期格式仍是英文，且尚未完成逐页布局回归。因此语言目录覆盖已经闭环，但全部文案翻译与逐语言视觉验收尚未闭环。

## 权限与回滚边界

- 不替用户接受通知、辅助功能/Input Monitoring、日历或 Apple Events 权限。
- 不修改 Flow 的计时、会话、订阅或许可数据。欢迎页审查只临时覆盖 `showWelcomeWindow`，捕获后已恢复为原值 `false` 并再次读取原偏好确认。
- 工程已于 2026-08-30 建立 Git 基线。数据模型保持 `focusSessions.v1` 和 `timerPreferences.v1` 向后兼容，后续变更继续以红测、最小实现、全量闸门和可回滚提交为单位。
