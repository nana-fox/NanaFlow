# NanaFlow 设计 QA（2026-08-28 视觉精修）

## 范围与真值

- 源：本机 `/Applications/Flow.app` 4.8.0（126）及用户提供的 760×544 休息态截图；未修改 Flow 的数据、订阅或设置。
- 实现：`/Users/nio/Library/Developer/Xcode/DerivedData/NanaFlow-cmxejewtsqtmuyfzqwgmewnfaovb/Build/Products/Debug/NanaFlow.app`。
- 视口：主窗及其设置/阻断器/标签/同步/自定义页面 380×272；统计/会话列表/详情 800×450；会话编辑 470×410；帮助 400×592；About 外框 510×306；Welcome 外框 420×492；Pro 外框 650×552；Widget 内容按 158×158、338×158、338×338、720×338 原生尺寸渲染。
- 状态差异：早期主窗参考为休息 05:00，实机为暂停的专注 24:52；设置页“登录时启动”开关状态不同。新增长时间停顿证据已统一为 380×272、20:00、第四轮、暂停状态，不再用跨状态图片判断主窗字号与坐标。

## 同图对照证据

- 主窗：`References/audit-2026-08-28-main-refined-focus-comparison.jpg`
- 长时间停顿主窗：源图 `References/audit-2026-08-27/01-flow-main-long-break.jpeg`；实现图 `References/audit-2026-08-28-nanaflow-main-long-break-menu-final.png`；同状态对照 `References/audit-2026-08-28-main-long-break-menu-final-comparison.png`。两侧均为 380×272、20:00、第四轮、暂停状态。
- 设置：`References/audit-2026-08-28-settings-final-comparison.jpg`
- 设置最终复查：`References/audit-2026-08-28-settings-top-final-current-comparison.png`、`References/audit-2026-08-28-settings-bottom-final-current-comparison.png`。两侧均为 380×272；顶部内容平移误差为 0 px，底部通知卡与滚动末端约 1 px 的剩余差异归为 P3。开关状态不同，不把状态色差计为布局问题。
- 阻断器：`References/audit-2026-08-28-blocker-final-comparison.jpg`；应用空态最新同输入对照为 `References/audit-2026-08-28-blocked-app-notification/03-blocker-apps-empty-comparison.jpeg`（左 Flow / 右 NanaFlow）。两侧卡片、标题、说明、分页标签与底部帮助层级接近；Flow 网页标签的 Pro 锁在 NanaFlow 中按解锁目标移除。
- 拦截结果页：`References/audit-2026-08-28-remaining/06-blocked-comparison.jpeg`，左侧 Flow、右侧 NanaFlow，均为 Safari 988×768；标题、正文、颜色、垂直坐标和单行排版按同图判断，品牌图标按产品边界保持不同。
- About：`References/audit-2026-08-28-continuation/03-flow-about.jpeg` 与 `14-nana-about-final-sized.jpeg`，运行态均为 510×306；除 NanaFlow 品牌图标、版本和官方链接外，信息层级与按钮几何已按当前 Flow 复核。
- 帮助：`References/audit-2026-08-28-continuation/11-flow-how-it-works.jpeg` 与 `13-nana-how-it-works-final.jpeg`，运行态均为 400×592；窗口名、最小化状态、数字空格和尾部步骤节奏已对齐。
- 欢迎页：最终同尺寸对照 `References/audit-2026-08-28-welcome-titlebar-final-comparison.jpeg`，左 Flow / 右 NanaFlow，运行态均为 420×492；未改首启偏好，NanaFlow 使用自有图标与无文字波纹背景资产。该对照覆盖此前漏审的 32 px 原生标题栏和底部边缘，不再只比较内容区。
- 授权窗口：运行态同图为 `References/audit-2026-08-28-notification-copy-final.png`、`References/audit-2026-08-28-calendar-copy-final.png`、`References/audit-2026-08-28-calendar-chooser-final.png`；外框分别为 300×272、300×272、300×332，通知与日历提示的换行也已按各自源图复核。
- Pro 窗口：运行态 1:1 同图 `References/audit-2026-08-28-pro-outerframe-final.png`。两侧均为 650×552，左侧特性层级、分栏、卡片和底部操作区保持对应；NanaFlow 用真实已解锁状态替代价格和购买。
- Timer Sync：`References/audit-2026-08-28-remaining/01-flow-timer-sync-paywall.jpeg` 证明 Flow 免费态入口进入付费墙；`02-nanaflow-timer-sync-enabled.jpeg` 为 NanaFlow 已解锁同步页，`03-nanaflow-settings-no-duplicate-sync.jpeg` 证明一般设置不再保留重复入口。Flow Pro 同页无法合法捕获，因此这里只把运行路径、文案与结构列为证据，不冒充像素级同图。
- 自定义时长：`References/audit-2026-08-28-remaining/04-nanaflow-custom-durations-embedded.jpeg`。Flow 免费态专注/休息菜单中的“自定义”均进入 Pro Upgrade，权益态像素不可见；包内 `Duration.strings` 和路由元数据证明标题、说明及主窗内 `durations` 页面，因此仅验收 NanaFlow 的嵌入路径、文案、交互和设计系统一致性。
- Fullscreen：自动休息证据为 `References/audit-2026-08-28-remaining/05-nanaflow-fullscreen-break.jpeg`，文件菜单手动命令证据为 `References/audit-2026-08-28-continuation/15-nana-file-command-fullscreen.jpeg`。Flow 实机命令确实进入全屏覆盖，包内 `FullscreenWindow`、`FullscreenView` 和 `_fullscreenManuallyTriggered` 进一步证明独立窗口与手动触发边界；由于 Computer Use 在 Flow 覆盖后无法取得像素截图，这里验收运行路径、NanaFlow 真实屏幕覆盖、焦点和关闭恢复，不冒充 Flow 同状态像素对照。
- Widget 源图库：`References/audit-2026-08-28-flow-widgets-gallery.jpeg`；实现渲染：`References/audit-2026-08-28-nanaflow-widgets-refined-final.png`；同图对照：`References/audit-2026-08-28-widgets-full-comparison.png`。实现图直接渲染 Widget 正在使用的共享生产视图；未把测试替身当成实现证据。
- 统计源图：`References/audit-2026-08-28-flow-statistics-current.png`；实现图：`References/audit-2026-08-28-nanaflow-statistics-refined-final.png`；同图对照：`References/audit-2026-08-28-statistics-refined-comparison.png`。两侧外框均为 800×450。
- 会话列表源图/实现/对照：`References/audit-2026-08-28-flow-sessions-current.png`、`References/audit-2026-08-28-nanaflow-sessions-refined-final.png`、`References/audit-2026-08-28-sessions-refined-comparison.png`；会话详情源图/实现/对照：`References/audit-2026-08-28-flow-session-detail-current.png`、`References/audit-2026-08-28-nanaflow-session-detail-refined-final.png`、`References/audit-2026-08-28-session-detail-refined-comparison.png`。
- 会话列表工具栏终审：全图 `References/audit-2026-08-28-menu-final/04-sessions-normal-fixed-comparison.jpeg`，局部 `References/audit-2026-08-28-menu-final/05-sessions-toolbar-focused-comparison.jpeg`，均为左 Flow / 右 NanaFlow、800×450、1×、活动窗口，无缩放归一化。过滤与更多按钮的图标、间距、按钮背景和右侧边距在局部图中可直接判断；不同历史数据只影响列表内容，不影响工具栏结论。
- 统计窗口动态伸展：`References/audit-2026-08-28-menu-final/03-sessions-zoomed-fixed-comparison.jpeg`。两侧均为“所有会话”放大态，Flow 为 1224×768、NanaFlow 为 1262×768，因显示器可用宽度不同不做坐标级比较，只验证列表背景与内容容器都铺满可用窗口、没有固定 800×398 卡片居中和四周空白。
- 会话编辑源图：`References/audit-2026-08-28-flow-session-edit-current.png`；实现图：`References/audit-2026-08-28-nanaflow-session-edit-refined-final.png`；同图对照：`References/audit-2026-08-28-session-edit-refined-comparison.png`。Flow 源图为 470×411，NanaFlow 为 470×410；对照裁去源图底部 1 px 进行 1:1 并排。

## 迭代记录

初次对照发现：主标题上移约 15 px、主按钮 54 px 而参考为 42 px、休息态缺少跳过按钮、关闭按钮过重；设置卡片与滚动条位置偏差；阻断器分段控件仅约 94 px 而参考为 260 px；About/帮助窗口内容高度多 32 px；菜单仍混有英文。

本轮修正：主窗改为参考坐标契约并补齐休息态跳过控件；采样休息色 RGB 51/124/104；设置表面色、滚动条内缩和返回图标对齐；阻断器使用 260×28 原生风格分段控件；修正欢迎页图标透明边距；校正 About/帮助内容高度与步骤间距；补齐简体中文菜单并收紧菜单项目。

此前把带有“退出 NanaFocus”的截图误归类为 Flow 证据，并据此实现了迷你计时器；该判断和对应视觉验收已作废，最终实现已完整移除该功能。

Widget 审计发现旧实现使用浅色 14% 背景、计时器图标、加粗大数字、第二统计行和中文无衬线引语，且引语只支持小/中两档，与 Flow 图库构图不一致。现已改为原包公开颜色资源对应的实色主题底与浅色前景、居中“今天 / 数字 / Flows”层级、英文衬线引语与作者署名，并支持小/中/大/超大尺寸。二次同图复核又修正了中号文字截断、内容顶贴和大号错误换行。

Widget 的长期轮换也不再只看图库截图。Flow 主包与 Widget 扩展各自携带同一份 521 条引语资源，旧 NanaFlow 仅有 4 条且按年内日序取值，会四天重复，并让 365 之后的槽位永久不可达。当前实现保留四条视觉验收样例，以 NanaFlow 自有原创短句组合补齐 521 条唯一内容，使用自 1970 年起的连续日序跨年轮换；完成通知直接复用同一目录。规模、唯一性、连续两日不同和第 521 天回环均有红绿测试，未复制 Flow 的完整专有语料。第 521 条在 158×158 小组件上的真实渲染证据为 `References/audit-2026-08-28-widget-generated-quote-small.png`，五行正文和作者均未截断。

统计与会话链路审计发现旧实现存在外框尺寸、周起始日、日期标题、环比层级、图表颜色、列表边距与编辑面板高度偏差。现已改为 800×450、周一起始、`yyyy/M/d`、圆形前后导航、渐变绿柱图和 8 px 列表边距；编辑面板收至 470×410，无中断时不再显示“打断 0 分钟”，删除操作使用红色轻量样式。会话菜单也对齐了“显示未完成”的眼睛图标、“重置统计数据”文案与垃圾桶图标；添加/导出在 Flow 中显示付费锁，NanaFlow 则使用 plus/导出图标表达已解锁的真实功能。NanaFlow 保留标题和标签可编辑，而 Flow 参考图中这两项因 Pro 被锁；这是“解锁功能”的产品边界，不是样式缺陷。

版本终审先纠正了官网当前版本与本机复刻基线的混淆：本机包仍是 Flow 4.8.0（126），因此没有把 4.9.0 才新增的标签预设和排序误扩进实现。4.8 包内 Core Data 模型明确包含 `Tag.order / Tag.color`，本机只读标签记录与 Assets.car 又锁定工作/个人/学习所用的蓝黄红值。NanaFlow 现保存并迁移这三种颜色，标签管理页圆形状态、统计堆叠柱和摘要圆环使用同一颜色源；无标签柱继续保留此前同图验过的绿色渐变。测试渲染以工作 20 分钟、学习 10 分钟同时入桶，确认蓝/红分段、纵轴、日期和右侧卡片没有互相挤压。

同轮先补齐了右键状态栏计时器直接切换开始/暂停及悬停提示；后续本轮取得 Flow 4.8 左右键事件分支后，已进一步以原生 `NSStatusItem` 替换早期 `MenuBarExtra` 和本地右键监听，完整结论见下方“状态栏本体复查”。

长时间停顿同状态审计发现标题文案错误、单独蓝色背景、阶段标题约大 10%、计时数字约大 7%，且休息态菜单图标被系统菜单样式覆盖成黑色。现已统一文案与休息背景，将标题/计时字号收至 20/75；最终计时文字像素边界 192×54，Flow 为 191×55。主菜单“建议”也已补齐五项可观察动作；后续调用链复查发现旧实现把 `nanaflow://show` 当作公开推荐链接，复制给其他人或交给 Facebook 均无法作为产品页访问。现已将复制、邮件、Facebook 与系统分享统一到真实 HTTPS 公开地址，并按 Flow 的完整邮件主题/正文结构适配 NanaFlow；运行态只读核对了五条菜单结构，没有触发剪贴板、邮件或发布。阻断器帮助改为本地原生弹层并去除 Flow 官网依赖。

菜单细节复查还发现 NanaFlow 旧版把 `✓` 直接拼入时长、休息、周期和标签标题，导致文字缩进、基线与辅助功能标题都不同于 Flow 的原生菜单状态列。现已把这四组单选语义改为 macOS 原生状态标记；最新运行态 AX 中，Flow 与 NanaFlow 都只暴露“25 分钟 / 4 次 / 工作”等正文，不再出现手工勾号字符。改动后计时器恢复为第 1 轮 25:00 待开始，没有保留审查状态。

菜单图标首轮像素测试出现假绿：单独渲染的白色图标正确，但放进原生 `Menu` 标签后仍被 AppKit 重绘成黑色横向实心点。最终把 3 个原生 `circle` SF Symbols 作为独立可见层，原生 `Menu` 仅保留透明 28×28 点击层；后续同图又发现 7 pt/2 pt 的圆环偏大、偏松，现收紧为 5 pt/0 pt。实机点击可打开完整菜单，无障碍树只暴露一个“更多”菜单按钮；更新后的 `References/audit-2026-08-28-main-long-break-menu-rings-comparison.png` 两侧均为白色紧凑竖向空心圆环，未用 Flow 私有图标资产。

阻断器应用页帮助又做了一次真实弹层检查：Flow 只显示一行“黑名单上的应用只会在正在运行的 Flow 中被阻止”，NanaFlow 已按同一信息层级改为单行本地文案，并按应用/网页标签切换不同说明。两侧 AX 结构和文案已核对；NanaFlow 的原生 Popover 是独立窗口，Computer Use 的单窗口截图不会合成该子窗口，因此这里只记录结构证据，不冒充像素级弹层证据。

阻断器后续审查覆盖到真正发生跳转后的浏览器页面。旧页虽然颜色接近，但标题写成“已阻止”、正文换成两行、元素间距与 Flow 不同，图标也缺少右下角禁止徽标。现直接以 Flow 包内 `zh-Hans/Blocked.html` 为布局契约，改为“封锁”、同一字体栈和原始绝对居中规则，并针对更长的 NanaFlow 品牌名补一个 `white-space: nowrap`，确保相同视口保持单行。图标使用 NanaFlow 自有底图和图像生成得到的透明红色徽标合成，未复用 Flow 的内联 SVG。最终并排图中除品牌图形与名称外，视觉坐标和信息层级一致。

标签与统计文案审查发现两个功能性细节：标签行的控制器选中状态没有同步到页面本地选择，导致删除按钮始终禁用；删除标签也不会清理历史会话中的同名引用。现已让行点击同时更新本地选择与活动标签，删除前按 Flow 文案确认，控制器统一清理历史引用并持久化。统计空态、无标签说明、会话删除与重置确认文案同步收紧，周标题使用 Flow 实机确认的窄空格加 en dash。实机删除确认只走到“取消”，未改动用户现有“工作”标签。

完成性复查又发现三类容易被视觉截图漏掉的粗糙点：统计、详情与 Widget 仍显示旧的 `Flow/Flows` 名词；早期状态栏下拉菜单中的“设置…”使用了已经删除的 `Settings` scene；统计图表柱和工具栏沿用系统默认无障碍名称。品牌与统计无障碍问题已修复；设置入口随后接到主窗内真实设置路由，并在确认 Flow 4.8 没有该状态栏下拉菜单后随整套多余菜单删除。真实运行态 AX 已确认七个空柱均读为 `0 NanaFlows`，不是只靠源码断言。

同轮截图尺寸复查推翻了早先只量内容卡片的结论：加入标准窗口能力后，NanaFlow 实际窗口曾变成 380×304，绿色内容下方出现 32 px 白带，而 Flow 实机仍是 380×272。根因是 SwiftUI 以 272 pt 内容高度再叠加透明标题栏。现在外层内容布局改为 240 pt、可见页面仍从顶部完整绘制 272 pt，并将主 scene 改为 `contentMinSize`，最终同时满足三项实机证据：主窗与设置页截图均为 380×272、无白带；窗口菜单“填充 / 居中 / 左右上下 / 四角”保持启用；缩放仍按 Flow 禁用。设置开关也不再是无名称控件，AX 逐项读出对应行标题。

授权流程审计补齐了 Flow 的通知拒绝提示、日历拒绝提示和空日历选择器。NanaFlow 现按未决定/已授权/已拒绝三态路由，拒绝时保持开关关闭，获准后打开日历选择器并把选定标识传给会话记录器。首轮使用系统 Calendar 图标导致可见图形过小且配色错误；最终换成 NanaFlow 自有 1254×1254 Alpha 资产，并将日历图标槽从 68 pt 调至 82 pt，使 1:1 对照中的可见边界、位置和视觉重量贴近 Flow，同时避免复用 Flow 商标资产。

Pro 入口复查纠正了早先“升级窗口不可打开”的误判：Flow 主菜单首项可以只读打开 650×552 Pro Upgrade 页。NanaFlow 补齐同位置“升级”入口，并用原生固定窗口解决 SwiftUI scene 外框多 32 px 和内容被标题栏下压的根因。最终保留两栏色块、PRO 标识、四项权益、三张状态卡和底部主按钮，但明确显示“已解锁”，不复制价格、订阅、恢复购买或伪购买行为。

独立窗口最终复查不再信任声明尺寸，而是逐个以真实窗口截图量外框。最新运行态纠正了先前 About 的误量，当前 Flow 与 NanaFlow 都是 510×306；How It Works 保持 400×592，并禁用与 Flow 一样的最小化按钮；Pro 用真实 `show()` 红测锁定 650×552。Welcome 保持 420×492，并重做无文字背景波纹与正文节奏；通知/日历提示与日历选择器分别保持 300×272 / 300×272 / 300×332。

快捷指令审计不以“能编译”代替等价性，而是直接对比两个 Release 包的 `Metadata.appintents/extract.actionsdata`。旧 NanaFlow 将阶段输出降成普通文字，为开始/暂停/跳过返回额外对话，还多出 Flow 没有的“重置”快捷动作与带目标参数的打开动作。现已改为 Flow 的 10 动作结构、`Phase` 三态枚举、同样的前台/后台策略、输入输出形状和 5 个系统快捷短语；忽略产品名及中文文案后的归一化 diff 为空。本轮没有改动可见视图，因此不新增伪装成 UI 证据的截图。

通知文案审计发现旧实现只有“专注完成 / 休息结束”两组固定内容，而 Flow 的简体中文资源和二进制键名明确列出 `flowCompletedTitle/Body1...10` 与 `breakCompletedTitle/Body1...10`。NanaFlow 现已按“刚完成的阶段”在各 10 组中选择，并限制励志名言只替换专注完成正文。由于本轮没有代替用户授予通知权限，验收证据为纯内容红绿测试，不是冒充的系统通知截图。

通知动作审计进一步读取 Flow arm64 二进制中的原生分类注册和选择分支，确认四组精确拓扑：`notification_pending_flow` 仅“开始”，`notification_pending_break` 为“开始 / 跳过”，`notification_autostarted_flow` 仅“打开”，`notification_autostarted_break` 为“开始 / 跳过”，三种动作均带前台选项。NanaFlow 已用相同 identifier 与 `sessionCompletedNotification` 请求标识注册，并将响应集中映射到开始、跳过和显示窗口命令；计时器会依据下一阶段及对应自动开始偏好选择分类。这里仍只声明注册、选择与路由契约通过，不声称真实系统通知已投递或按钮已由用户点击。

AppleScript 审计发现 NanaFlow 虽已有 Flow 的 11 个命令名，但 suite/command 事件码、结果说明、`setTitle` 参数码及 `previous` 描述并未对齐。现已用单一红绿契约测试锁定公开 SDEF，Release 包在只替换产品名和 Cocoa 类命名后与 Flow 字典 diff 为空；Script Editor 对 NanaFlow 只读执行 `getPhase`，真实返回当前阶段“长时间停顿”。后续复核又用 Flow 官方 Changelog 的“reset or back button”“cycle navigation”记录和 arm64 状态分支锁定 `previous`：当前阶段一旦开始就重载当前阶段，处于待开始状态则退回上一阶段，全程不受自动开始设置影响。NanaFlow 已补齐独立状态迁移和 AppleScript 路由，并以红绿测试覆盖首轮、短休息、下一轮专注、长休息、自动开始偏好与承诺模式；主窗回转按钮则按本轮直接 AX 证据单独使用“重新开始周期”。

正式配置反查发现主 App 的日历写入、浏览器 Apple Events、导出面板和 KVS/App Group 代码虽已存在，但 Release entitlement 只有 KVS 与 App Group；按沙盒签名后会留下系统集成失效风险。现已启用主 App 沙盒，并补齐日历、用户选择文件读写、网络客户端、Apple Events 自动化和与 `BrowserURLController` 完全一致的 8 个浏览器例外。红测先复现 6 项缺失，修复后契约测试、Release build settings 和 entitlement plist 三层复核通过。本项不改变可见界面，因此没有新增伪装成视觉证据的截图。

顶级菜单复查先纠正了“文件菜单是多余入口”的误判，随后纠正了新 Fullscreen 的错误映射。Flow 实机明确为“Flow / 文件 / 编辑 / 显示 / 窗口 / 帮助”，文件菜单含“新Fullscreen窗口 / 关闭 / 全部关闭”；触发新建项后应用进入真实屏幕覆盖。NanaFlow 现以同一独立 Fullscreen 控制器承载自动休息和手动文件命令，手动标记可防止偏好变化误关窗口；“关闭”会准确退出覆盖层并恢复主窗，“全部关闭”也先清理该独立窗口。红绿契约、AX 菜单、真实覆盖截图与关闭恢复共同验收。

其余顶级菜单随后逐项复查：编辑、显示、帮助本来就与 Flow 一致；应用菜单则多出五个计时与设置入口。现已删除这组重复入口和独立 `Settings` scene，设置功能仍完整保留在主窗“更多 → 设置”，应用菜单去品牌化后与 Flow AX 结构一致。主窗补上 `standardWindow` AX 子角色后也与 Flow 同为“标准窗口”。窗口菜单再从 scene 声明源头修复：11 个辅助窗口用 `commandsRemoved` 取消自动注册，主 scene 以 `singleWindowList` 精确声明 Flow 的九个内部窗口入口，实机顺序、文案和末尾 NanaFlow 主窗项均已对齐。首次标准窗试验因同步修改 `styleMask` 触发 AppKit 视图枚举重入；最终改为以弱引用表对每个窗口只调度一次，并延后到当前枚举结束后再加入 titled/resizable/fullSize chrome。实机保持 380×272 无白边外观，同时原生启用填充、居中、半屏、四角和多窗口排列，缩放继续按 Flow 禁用；相同显示器状态下窗口菜单除产品名外逐项一致。

Timer Sync 复查纠正了两个问题。第一，Flow 的普通设置页并没有“定时器同步”开关，免费态只在主菜单出现锁定入口并打开 Pro Upgrade；NanaFlow 原来在主菜单和设置页各放一个开关，信息架构重复。现在主菜单进入独立 380×272 同步页，设置页删除重复项。第二，旧同步直接编码整份 `TimerPreferences`，会把外观、通知、快捷键、承诺模式和会话标题错误覆盖到其他设备。Flow 二进制字段元数据明确列出 `flowDurationInMinutes / shortBreakDurationInMinutes / longBreakDurationInMinutes / sessionCount / startBreakAutomatically / startFlowAutomatically` 六项；NanaFlow 现只应用这六项，统计继续独立合并，并补齐包内公开的使用说明、排障步骤与 Sync Key / Device Key 诊断。权益态像素仍无合法参考，因此页面沿用已验证的设置页卡片、字体、圆角和滚动规格，不声称未经观察的像素一致。

自定义时长复查发现 NanaFlow 原实现会从主菜单打开额外的 360×260 窗口，而 Flow 的 App Router 明确使用主窗内 `durations` 路由；菜单文案也应为无省略号的“自定义”。现已删除独立 scene，把专注和休息两个入口统一导向 380×272 主窗页面，标题与说明使用 Flow 包内公开键并完成 NanaFlow 品牌替换，三种时长保留原生步进器、取消和保存。由于 Flow Pro 权益态无法合法观察，具体输入控件不作像素等价声明，但主窗容器、返回标题栏、表面色、卡片圆角和行高均复用已验证设计系统。

Fullscreen 复查发现旧实现先直接对 380×272 主窗口调用 `toggleFullScreen`，随后文件命令又误接到错误窗口；两者都与 Flow 独立的 `FullscreenWindow` / `FullscreenView` 结构矛盾。现改为覆盖当前屏幕的独立无边框窗口：自动休息保留长休息标题、时间、周期、跳过、开始和关闭语义，文件命令则按当前阶段渲染并记录手动触发。首轮运行还发现普通无边框窗口不能成为 key window，Esc 和键盘焦点因此不可靠，现以只覆盖 `canBecomeKey` 的最小窗口子类修复。红测、真实运行 AX、1366×768 截图和文件菜单关闭恢复均通过；Flow 同状态像素图仍未取得，因此不作未经观察的像素等价声明。

设置与文案终审又发现共享资源不能直接等同于当前 macOS 免费/关闭态可见界面：Flow 实机没有独立“通知音量”标题行，三张卡片末行也没有底部分隔线；旧 NanaFlow 因此多出一个标题控件和三条边。现已删除该独立标题行，并让末行显式关闭分隔线。当前同尺寸复查进一步把顶部内容平移误差收敛到 0 px、底部通知卡收敛到约 1 px；声音菜单使用实机确认的 11 项顺序且不显示“无”。快捷键说明、主菜单间距/省略号、会话标题占位词、Timer Sync 区域警告、自定义时长说明、帮助页标点、阻断器说明和统计导出子菜单也都以实机或包内简体中文资源为准，不再用近似文案。

导出终审发现菜单文案虽已对齐，但 CSV 内容仍是 NanaFlow 自拟格式。Flow 4.8 二进制中的固定表头、日期格式，以及会话的开始/完成/打断/标签访问路径共同锁定真实契约；打断列是累计打断时长，总用时是完成时间减开始时间再减打断，未完成会话使用三个短横线和零总用时。NanaFlow 已按该契约实现并增加完整行断言，同时在 Flow 原实现基础上补齐嵌入双引号的标准 CSV 转义。

同一轮继续反查 Text 导出，发现旧实现仍是 NanaFlow 自拟的“标题 · 时长 · 状态”摘要。Flow 4.8 实际按系统中等日期/时间格式输出 `{标题或阶段} [标签]: {开始} - {完成或 ---}`，会话间空一行。NanaFlow 已改用同一格式并加入完成、未完成、标签、空集合的精确断言。运行态统计页对照还发现 NanaFlow 的缩放按钮是灰色，而 Flow 可用；统计 scene 改为 `contentMinSize` 后，统计与所有会话页的原生缩放按钮均在最新 AX 中恢复可用。

阻断器终审没有停在外观对照。Flow 4.8 二进制字段明确表明应用列表始终是黑名单，网页列表才支持 `block / allow`，浏览器枚举严格为 Safari、Chrome、Edge、Brave、Vivaldi、Opera、Sidekick；浏览器服务脚本还明确遍历 every tab of every window。NanaFlow 已删除应用页错误的允许列表模式和自动扫描所有浏览器的旁路，网页输入由弹窗改为内联行，并按所选浏览器处理全部标签页。旧 `blockerConfiguration.v1` 自动迁移到 Safari，不丢失现有列表和网页模式；生成的 AppleScript 还经过包含引号和反斜杠输入的真实编译测试。

承诺模式与长历史也完成行为级复核。Flow 官方更新记录和本机控制器结构共同要求承诺专注期间禁用空格和阻断器入口；删除非 Flow 的入口后，NanaFlow 现在锁住主窗、跳过/重置、设置开关和阻断器入口共 5 个现存可见控件，状态栏右键启停仍经过同一控制器守卫，并在 `updatePreferences` 根部阻止运行中关闭承诺模式。Flow“所有会话”AX 明确一次只载入 100 项，二进制有 `batchSize / currentOffset`，本地化含“载入更多”；本机数据库只读计数为 10,716 条。NanaFlow 因此改为 100 条分页、筛选后回首批，并用 `@AppStorage("showIncompleteSessions")` 持久化未完成会话显示偏好，避免每次打开窗口重置。

最终桌面生命周期复查又抓到两处截图无法证明的落差。快捷键页写有“打开设置 ⌘,”，旧实现却没有真实路由；直接增加 SwiftUI Settings 命令又会让应用菜单多出 Flow 实机不存在的“设置…”项。现改为只在 NanaFlow 前台生效的本地 `⌘,` 监听，先恢复主窗再进入内嵌设置页，应用菜单仍保持“关于 / 服务 / 隐藏 / 退出”。同时补齐 Flow 4.8 二进制明确存在的 `applicationShouldHandleReopen:hasVisibleWindows:`：关闭最后一个窗口后再次点开 App 会恢复 380×272 计时器。两条路径均以 Computer Use 实际关闭、重开、按键和 AX 树复核，不只做源码断言。

快捷键运行态审查继续发现 `addGlobalMonitorForEvents` 只接收其他应用聚焦时的事件，旧实现因此在 NanaFlow 自身前台时无法响应已启用的“全局快捷键”。现以同一解析器同时接入本地和全局监听，并集中复用四个动作路由。目标红绿测试与真实 ⌃⌥⌘F / ⌃⌥⌘R 按键均通过；测试后计时器恢复 25:00，`globalHotkeysEnabled` 恢复为原来的关闭状态。

同一页的“重置循环”动作也曾误接为只重载当前阶段。现将解析结果明确命名为 `resetCycle` 并调用控制器的整周期重置；真实运行态先用 ⌃⌥⌘S 从第 1 轮推进到第 2 轮，再以 ⌃⌥⌘R 回到第 1 轮 25:00。这样快捷键文案、动作与 Flow 的周期语义一致，而 AppleScript `reset` 仍保留“重置当前会话进度”的独立契约。

启动隐藏策略继续发现一处跨窗口差异。旧实现由 `TimerView` 监听运行态并对当前 `keyWindow` 调用隐藏，因此从通知、快捷键或 URL 启动时，最前面的统计等辅助窗可能被误关；主窗尚未建立时的“启动时启动计时器”也无法触发该观察。Flow 4.8 二进制明确保留独立 `AppWindowService.appWindow`，官方更新记录也反复修正各启动入口的隐藏一致性。NanaFlow 现把 ID 为 `timer` 的主窗查询与隐藏集中到同一入口，手动启动和阶段自动开始共用控制器中的同一启动函数，启动时自动计时则由窗口初始化策略补足。真实运行态将统计窗保持前台后执行 `nanaflow://start`，统计窗继续可见且主计时器窗隐藏；随后已恢复 25:00 暂停态并关闭验收辅助窗。

早期状态栏下拉菜单的周期动作曾从“跳过 / 重新开始”收紧为阶段化文案；本轮继续反查 Flow 4.8 后确认该下拉菜单本身就是 NanaFlow 多出的结构。现已整体删除，并将状态栏收敛为普通左键显示/隐藏主窗、右键或 Control+左键快速启停。跳过与重启仍由主窗悬停工具栏承载，其中“重新开始周期”继续调用 `resetCycle()`。

继续展开主窗悬停工具栏后又发现同一语义在另一个入口发生漂移：Flow 当前休息态 AX 将回转按钮明确读为“重新开始周期”，NanaFlow 旧实现却调用 `previous()` 并按状态读成“上一个 / 重新加载”。图标一致掩盖了动作不一致。现已将主窗回转按钮直接接到 `resetCycle()`，并把主窗及全屏休息的跳过辅助文案统一为 Flow 的“跳过休息时间”；独立 `previous` 仍只保留给 AppleScript/自动化。该改动不改变已同图验收的图标、坐标、字体、颜色或尺寸，因此复用既有 380×272 悬停同图作为视觉证据，同时以本轮 Flow AX 和红绿行为契约补足不可见语义证据。原生菜单弹层在 Computer Use 中只返回 AX 而没有截图，故本轮只声明菜单结构/文案通过，不虚构菜单弹层像素证据。

状态栏本体复查取得了比旧实现更直接的证据：Flow 4.8 的默认数字计时使用 18 pt 高的紧凑胶囊描边，而 NanaFlow 旧版只显示裸文本；早期截图中的半圆则来自仍在后台运行的旧 `NanaFocus.app`，不是当前 `NanaFlow.app`。NanaFlow 已关闭该旧实例，并把默认/兼容 `.list` 样式收敛为等宽倒计时、6 pt 水平内边距、18 pt 高度和 1 pt 胶囊描边，默认继续关闭会话标题；`circular` 与 `progressBar` 两个可选样式保持独立。目标测试先以缺少 padding/描边复现两项失败，修复后转绿。最终同一块 5120×2880 显示器同时捕获 NanaFlow 与 Flow，胶囊高度、圆角、描边和数字基线无剩余 P0/P1/P2；发布包单实例的 100 px 高局部同图为 `References/audit-2026-08-29-menubar-release-focus.png`。进一步的本机 Flow 事件分支仍表明右键或 Control+左键快速启停、普通左键显示/隐藏窗口；NanaFlow 保持同一交互模型。

后续独立运行态复查没有把“窗口”菜单里的 Welcome、About、授权窗、Pro Upgrade 和统计误删为调试入口：Flow 4.8 当前实机逐项显示相同窗口列表；两边 App Intents 元数据也同为 9 个动作、5 个 App Shortcut，参数、打开应用策略、输出标记和顺序一致。本轮实际抓到的是主窗右上角菜单控件仍使用 NanaFlow 自拟的“更多”语义且缺少 tooltip；现已改为 Flow 的“菜单”并补同名悬停提示，Debug 重启后的 AX 真实读为“菜单”。

多语言复刻已从主窗切片推进到次级功能、后台系统面和完整语言矩阵，而不是只增加工程地区声明。`en / zh-Hans` 先作为真正的 `Localizable.strings` Variant Group 同时编入主 App 与 Widget；独立英文进程已逐页检查主窗、主菜单、设置、统计/所有会话、阻断器、About、How It Works、Timer Sync、标签、自定义时长、Welcome 与 NanaFlow 自有 Pro 页。第五切片进一步接入 Flow 4.8 的全部 20 个实际语言区：18 个新增语言各携带 340 个完整键，主 App 与 Widget Bundle 均可解析，且没有残留独立 Flow 品牌。繁中、日文、德文、韩文、法文独立进程已真实检查主窗、菜单、设置、Timer Sync 与 Pro 页；运行检查先后修正繁中 `New Fullscreen Window` 和“终身访问”、日文/德文周期菜单 `sessions`，以及德文 Pro 页 `Lifetime` 泄漏。第六切片继续完成西班牙语、意大利语和加泰罗尼亚语，同形英文值分别收敛到 11、10、11 项，周期格式完成单复数本地化，三种语言也逐页通过同一组运行检查。西班牙语 Pro 页曾将 `Títulos de sesión y duraciones personalizadas` 截断，现通过单行文字最小缩放完整显示，不改写 Flow 原文；Flow 加泰罗尼亚语资源本身存在 `Nach Anmeldung öffnen` 与 `Pausa llarg`，本轮按源产品文案保留。第七切片完成巴西与葡萄牙两个葡萄牙语地区，同形英文值均从 68 项收敛到 12 项，周期格式改为 `sessão/sessões`，并清除产品名小写 `flow/flows` 漂移；两区主窗、菜单、设置、Timer Sync 与 Pro 页实机均未出现截断或拥挤，地区用词差异按各自官方资源和语法保留。第八切片完成荷兰语与挪威语（Bokmål），同形英文值分别从 78、68 项收敛到 22、12 项，周期格式改为 `sessie/sessies` 与 `økt/økter`，荷兰语小写 `flows` 品牌漂移也已清除；两种语言的五个关键页面实机均未出现截断或拥挤。其余 6 个语言区仍各有 63–70 个与英文相同的值，周期格式仍是英文，因此语言目录覆盖通过，但全部翻译与剩余语言逐页布局检查仍是阻塞项。授权提示、Calendar Chooser 和通知文案由 Bundle 契约与生产视图覆盖，未触发或接受系统权限。

标签审查发现旧实现把列表、新建和当前会话选择挤在一张卡片里，既缺少 Flow 4.8 明确存在的 `TagsOverview → addTag/editTag → TagEditView` 路由，也无法重命名或改色。现按包内类型、`Tags.strings` 文案、`_title / _color / _titleFocus` 状态与既有三色令牌重建概览、添加、编辑三页；新增标签只管理数据，不暗中改变当前会话标签。控制器在重命名、改色和删除时统一迁移活动选择与全部历史会话引用。最新 380×272 Debug 运行态逐页检查了返回、标题字段、三色选择、空标题禁用、编辑和删除入口，审查过程中未保存任何变更。Flow 的同状态页面受 Pro 权益限制，当前没有合法源图，因此本轮不把结构与运行通过冒充为像素级同图通过。

“为应用评分”也完成了结果级核对：Flow 会打开 App Store 的原生评论流程，而 NanaFlow 的本地构建没有可评论的商店条目；[Apple Lookup](https://itunes.apple.com/lookup?bundleId=com.nanafox.NanaFlow) 对当前 bundle ID 返回 `resultCount: 0`。在正式上架前保持无动作比把“评分”误接到官网或邮件更诚实；这项被记录为发布阻塞，而不是用假功能掩盖。

动态状态终审又发现此前完全缺失的周期完成反馈。Flow 的[官方功能说明](https://www.flow.app/blog/visionos-mini-mode-customizable-keyboard-shortcuts-and-more)和[官方 Changelog](https://www.flow.app/changelog)都明确：一轮最后一个 Flow Session 完成、开始长休息时显示短暂庆祝动画。本机 4.8 arm64 的 `CelebrationView` / `ParticlesGeometryEffect` 进一步锁定 119 个白色粒子、1.5 秒 ease-out、0.1–0.3 透明度、3–6 pt 尺寸、20–220 pt 径向位移、随机方向与 120° 旋转。NanaFlow 已把触发放在自然完成的控制器根路径，跳过同一阶段不会触发；首个渲染测试还真实暴露了简单线性散列造成的螺旋排列，随后改为均匀混合并以长休息绿底四象限粒子截图和像素采样收口，而不是只断言常量。

付费设置复查又补出一处此前被免费态界面遮住的功能。Flow 官方 Mac 功能说明明确支持分别调节通知与节拍器音量；本机 4.8 arm64 的 `SettingsVolumeView`、`_notificationsVolume`、`_metronomeVolume` 和常量反查锁定滑杆范围 0...2、small 控件、5 pt 垂直/8 pt 水平留白，以及 `volume × 50` 的 0–100% 显示。NanaFlow 现仅在对应功能开启时插入同构紧凑滑杆，滴答声与通知预览都从 Flow 的 0...2 比例归一化到系统 0...1；通知调度继续选取最接近的自有 25% AIFF 版本，未复制 Flow 专有 `Ticking.wav`。真实 `NSHostingView` 缓存渲染已确认系统滑杆和 50% 文案均进入像素图；先前会漏画平台控件的 `ImageRenderer` 验证已删除。

通知文案终审进一步发现，旧测试只检查了数量和每组第一条，因此把“是时候休息一下了”之类的顺写文案误当成 Flow 原文。现以本机 4.8 的 `zh-Hans.lproj/Notification.strings` 为只读真值，完整断言 10 条专注完成和 10 条休息完成通知；除产品名替换外，连原资源中的空格与标点都保留。该证据证明资源选择与调度文案一致，不等同于已经获得 macOS 通知权限或完成真实投递。

黑名单应用通知也补齐了此前只隐藏应用、不解释原因的行为差异。Flow 4.8 `Notification.strings` 锁定标题和正文，arm64 通知调用链继续证明分类为 `notification_app_blocked`、无动作、`sound = nil`、0.5 秒非重复触发，并以同一应用显示名查找或生成进程内稳定 UUID。NanaFlow 将反馈接到 `BlockerController` 的唯一应用命中入口，非黑名单不提交，命中后才通知并继续原有隐藏/回前台动作；目标测试先红后绿，并覆盖相同名称去重和不同名称隔离。应用页空态已用相同尺寸合图复核；真实系统横幅仍依赖用户主动授予通知权限，因此本轮只声明请求契约与根路径通过。

应用选择器运行审查进一步发现，旧 NanaFlow 的“添加”按钮使用阻塞式 `NSOpenPanel.runModal()`，在当前 SwiftUI 呈现链中没有显示任何面板；简单改成 `begin` 仍在真实运行中复现无响应，因此没有把源码测试绿误当成交付。最终直接使用系统 `.fileImporter`，单选 `.application` 并把默认目录设为 `/Applications`。真实面板现与 Flow 一样显示“打开 / 应用程序”；选取 `/System/Applications/Calculator.app` 后列表显示“计算器”，开始专注并激活计算器时目标应用立即被隐藏、NanaFlow 回到前台。临时规则、计时状态和测试用设置均已恢复。通知请求随同一命中根路径触发，但 macOS 通知偏好仍无 NanaFlow 授权条目，本轮没有替用户接受权限，也不把未出现的横幅写成通过。

欢迎页终审同样没有停在尺寸和单张截图。`Welcome.strings` 证明旧正文是顺写改译，现已逐字符改为品牌适配后的资源原文。同尺寸合图又暴露 32 px 白色标题栏；尝试让固定高度内容进入 full-size content 会压坏内部节奏，整窗铺绿则会在底部留下绿带，均被真实截图否决。最终只给原生标题栏视图铺背景顶色，窗口内容仍保持浅色底和原有 48 pt 顶距；交通灯、拖动、图标、标题、正文、按钮与复选框位置不受影响。真实 `NSWindow` 测试还锁定外框不变、未启用 full-size content、标题栏色和窗口底色分离；一次测试宿主退出动画崩溃已通过关闭测试窗动画与延后清理修复，随后 185 项全量回归无新增崩溃报告。

会话列表终审先在 800×450 同状态工具栏合图中发现两个 P2：NanaFlow 的过滤和更多 `Menu` 都被系统自动加上下拉箭头，按钮因此比 Flow 更宽；点击缩放后又发现外层视图仍固定 800×398，放大窗口只增加四周空白，而 Flow 会让列表铺满并显示更多行。修复分别复用 SwiftUI 原生 `.menuIndicator(.hidden)`，以及把固定外框改成相同最小尺寸加无限最大尺寸，没有引入自定义工具栏或窗口管理层。后续 800×450 全图、64 px 工具栏局部图和放大态对照均未发现剩余 P0/P1/P2；当前只保留历史数据不同和放大窗口宽度不同这两项非设计偏差。

同一会话工作流继续审查菜单状态与导出结果。Flow 的筛选弹层 AX 是“按标签过滤”分组标题、标签单选和筛选后才出现的“清除过滤 / minus.circle”；NanaFlow 旧版多出“所有标签”按钮并写成“清除筛选”。修复后 NanaFlow 默认、选中“工作”和清除三种 AX 状态均与 Flow 契约一致，当前列表截图为 `References/audit-2026-08-28-session-filter-export/01-nanaflow-all-sessions.jpeg`。导出审查真实发现旧 `runModal()` 没有显示面板；第一版 `.fileExporter` 即使源码测试为绿，在运行菜单中仍无可见结果，因此被否决。最终改为菜单关闭后的异步 `NSSavePanel.beginSheetModal`，并补齐默认扩展名、取消和写入错误路径。最新复查改用原生方向键进入嵌套菜单，CSV 与 Text 保存面板均真实出现，默认文件名分别为 `NanaFlow 会话.csv/.txt`；两次取消后正常返回且没有写文件，证据为 `References/audit-2026-08-28-export-panels/01-csv-save-panel.jpeg` 与 `02-text-save-panel.jpeg`。

## 五项检查

### 高频界面收口复查（2026-08-28）

- 主窗：通过 Computer Use 将 Flow 与 NanaFlow 同时置于 380×272、短休息 05:00、第一轮、暂停状态。休息绿、标题与数字基线、四个周期点、42 pt 播放按钮、14 pt 连续圆角和右上菜单位置未发现新的 P0/P1/P2；用户早期截图中的浅色卡片版已不再代表当前构建。
- 设置：只读打开两边的设置顶部；除“登录时启动”这一用户偏好状态不同外，标题、返回按钮、四行启动卡片、开关尺寸、分隔线、滚动条与下一节露出位置未发现新的 P0/P1/P2。未修改 Flow 偏好。
- 统计与会话：复查当前 800×450 统计页及所有会话页；窗口外框、左右分栏、周期选择、日期导航、图表基线、空态层级、列表行、工具栏尺寸与已有同图证据一致。真实历史数据不同，且 NanaFlow 按解锁目标显示标签空态与额外会话操作，因此不把内容差异误判为布局差异。
- 主窗运行态发现两项可执行视觉差异：专注态暂停图标仍是深色，低进度胶囊填充会退化成一条竖线。现分别改为 Flow 的绿色强调色，以及矩形填充后统一胶囊裁切并保证填充宽度不小于胶囊高度；标题、计时、周期点、主按钮与顶部工具栏坐标均保留。最终发布版 380×272 左 Flow / 右 NanaFlow 合图为 `References/audit-2026-08-29-main-roughness/12-release-final-comparison.png`；两边倒计时与周期索引不同，不把状态差异误判为布局差异。
- 主菜单与设置页复审没有确认新的 P0/P1/P2。两边菜单弹层均为 macOS 原生 `Menu`；NanaFlow 展开时多出的周期、标签、标题编辑和同步入口属于“付费功能全部解锁”的产品边界，不是样式漂移。设置页顶部激活态合图为 `References/audit-2026-08-29-settings-menu/06-settings-top-active-comparison.jpeg`，中段激活态为 `09-settings-middle-active-comparison.jpeg`；标题、返回按钮、卡片圆角、行高、分隔线、滚动条、胶囊值与绿色开启态一致。首次捕获到的灰色开启态是窗口未激活造成的系统表现，激活后消失，因此没有据此改代码或改变任一应用偏好。

- 字体与排版：长时间停顿同状态下标题与计时数字已量化贴齐；欢迎页标题、精确正文与按钮层级、帮助步骤标题、Pro 特性/卡片层级和 Widget 衬线引语无可见 P0/P1/P2 偏差。
- 间距与布局：主窗关键 y 坐标、42 px 主按钮、欢迎页 420×492 外框及 48 pt 内容顶距、统计/会话 800×450、编辑面板 470×410、Pro 650×552 两栏布局、设置行高、阻断器分段控件、帮助步骤、Widget 四尺寸族与底部文案已与源图同图复核；统计与会话内容在放大态也随窗口铺满，不再固定居中留白。
- 颜色与令牌：休息绿为源图采样值；设置表面 RGB 241/242/244 与源图一致；Widget 使用原包公开 `WidgetBackground` #267866 与 `WidgetAccent` #E9F2F0；图库中的系统预览会附加宿主渲染效果，因此不把 JPEG 取样色误当原始资产色。
- 图标、控件与动态效果：播放/暂停使用描边图标，专注运行态暂停图标按 Flow 使用绿色强调色；当前周期进度以矩形填充统一胶囊裁切，并把最小填充宽度限制为胶囊高度，刚开始时呈圆点而不是竖线。关闭、重置和统计仅在顶部 50 pt 命中区悬停时以 0.12 秒淡入淡出，指针位于计时区时不再常驻。其余关闭、返回、分段控件尺寸和位置已收紧；所有会话的过滤与更多菜单隐藏 Flow 不显示的系统下拉指示器，64 px 工具栏局部同图中按钮宽度和间距一致；欢迎页保留原生交通灯和拖动，只融合标题栏底色而不自建窗口控件；休息态菜单图标保持 3 个 5 pt、0 pt 额外间距的白色竖向空心 SF Symbols 圆环。状态栏默认数字已补齐 Flow 的紧凑胶囊描边。周期完成的 119 粒子动画使用 Flow 原参数并通过真实渲染取证，系统“减少动态效果”开启时不播放。
- 辅助功能：最新同状态运行态 AX 发现主窗计时按钮在 Flow 中读作“停止”、NanaFlow 旧实现读作“暂停”。现仅对已有直接证据的主窗修正为“停止”，定向红测、绿测与真实运行态均通过；Fullscreen 不依据主窗结果外推。
- 文案与本地化：菜单栏为“NanaFlow / 文件 / 编辑 / 显示 / 窗口 / 帮助”，文件菜单三项与 Flow 可见文案一致，应用菜单已去除重复计时/设置入口；欢迎页正文、20 条完成通知及黑名单应用通知均除品牌外逐字符对齐本机 4.8 简体中文资源；统计、详情和 Widget 的可见单位统一为 NanaFlows；Widget 名称与描述对齐“每日统计 / 显示您的每日统计数据。”和“每日励志 / 以励志名言开始新的一天。”；通知与完整日历访问的 InfoPlist 说明已提供简体中文。

## 验证结果

- 全量测试：207/207，0 failures；新增主窗顶部悬停区、低进度圆角填充、工具栏原生图标与 1× 菜单圆环回归，并保留此前全部界面、通知、自动化和行为回归。
- xcresult：`/tmp/NanaFlowFull-20260829-icon-polish-2.xcresult`；全量门禁覆盖状态栏及主窗视觉契约、20 语言资源、Widget、区域化日期、会话筛选、异步保存面板、欢迎窗口、通知与阻断入口。
- 覆盖率：全 App 75.43%（8530/11309）；整体 83.03%（15092/18176）。
- App Intents 元数据：Flow 与 NanaFlow Release 包的 action identifiers、flags/types、参数数量、supported modes、shortcut action/icons 和 `Phase` cases 归一化 diff 为空；`/tmp/nanaflow-window-parity-final-appintents.diff`。
- AppleScript：Release SDEF 品牌归一化 diff 为空，`NSAppleScriptEnabled=true`、`OSAScriptingDefinition=NanaFlow`；`/tmp/nanaflow-window-parity-final-sdef.diff`。Script Editor 公开命令实机成功并将最终阶段恢复为“长时间停顿”。
- Release entitlement：主 App `ENABLE_APP_SANDBOX=YES`；KVS/App Group、日历、文件读写、网络客户端、Apple Events 与 8 个受支持浏览器例外的契约测试通过。
- 静态分析：最新 Debug/arm64 串行 `xcodebuild analyze -quiet` 返回 0 且无诊断。
- Release：`dist/NanaFlow.app` 与 `dist/NanaFlow-macOS-universal.zip` 已生成；`lipo -archs` 确认主 App 与 Widget 均为 arm64 + x86_64，`codesign --verify --deep --strict` 通过，Computer Use 实际启动到 25:00 主窗。当前是本地 ad-hoc 签名，不把它冒充具备 App Group/iCloud/Calendar/通知/浏览器自动化和稳定 Widget Gallery 资格的正式开发者签名包。

## 本次主计时页 UI 复查

- 源视觉真值：`References/audit-2026-08-29-main-roughness/01-flow-current.jpeg`；实现截图：`References/audit-2026-08-29-main-roughness/11-nana-release-final.jpeg`；均为 380×272 px、1× 密度、浅色专注暂停态。倒计时与周期索引属于真实状态差异。
- 全图同输入：`References/audit-2026-08-29-main-roughness/12-release-final-comparison.png`。窗口本身已足够小且标题、数字、周期点、按钮和顶部入口清晰可读，因此不需要额外局部裁图。
- 首轮 P2：整窗悬停暴露关闭/重置/统计，造成计时区持续杂乱；低进度填充缩成竖线。修复后工具仅在顶部 50 pt 命中区显示并平滑淡入淡出，低进度以 12 pt 圆润起点呈现。
- 字体与排版、间距节奏、颜色令牌、图标清晰度和品牌文案均复用 Flow 已锁定的现有尺寸与系统资产；本轮没有擅改字号、坐标、窗口圆角或菜单结构。复查无剩余 P0/P1/P2。

## 本次图标与字体精修复查

- 视觉规范：`Design/NanaFlowTimerVisualSpec.md`；按本机 Flow 4.8 的 380×272 主窗量化标题、倒计时、周期点、主按钮与顶部工具栏，不引入与计时体验无关的图片或装饰。
- 图标根因：旧关闭按钮由 8 pt `xmark` 与手工圆形背景拼接，轮廓和抗锯齿不稳定。现改为原生 `xmark.circle.fill`，跳过、重置、统计统一为单色 SF Symbols；可见字号分别为 14/18/18/19 pt，命中区统一为 28 pt。
- 字体判断：同状态实机图确认 20 pt / 75 pt SF Pro Rounded、Regular 与 Flow 的字重和基线已贴齐，因此没有为了“显得设计过”而擅改主字体。倒计时继续使用等宽数字。
- 状态层级：专注态工具栏使用正文色 88% 不透明度，休息态使用白色 96%；关闭按钮单独降低不透明度，工具入口仍仅在顶部 50 pt 悬停区显示。
- 1× 回归真实抓到菜单空心圆改为 Regular 后亮像素归零；最终恢复为 5 pt Semibold，保证低密度屏幕也不会消失。
- 同状态合图：`References/audit-2026-08-29-icon-typography-polish/flow-vs-nanaflow-toolbar-comparison.png`。左为 Flow 源图，右为生产 `TimerView` 强制悬停渲染，并以最终 Release 的真实菜单图标和 sRGB 边缘替换 `ImageRenderer` 的系统菜单伪影；窗口尺寸、阶段、倒计时、周期索引与悬停状态一致。复查无剩余 P0/P1/P2。
- 最终 Release 实机截图：`References/audit-2026-08-29-icon-typography-polish/nanaflow-final-release.png`；AX 仍完整暴露“菜单 / 休息 05:00 / 第 1 轮，共 4 轮 / 开始”，核心交互未因视觉调整退化。

## 范围外限制（不影响本次主计时页通过）

- Flow Pro Upgrade 页和 Timer Sync 免费态入口已取得合法只读证据；Timer Sync 的文案、同步字段、诊断字段与导航已实现并留存运行截图，但购买后 Flow 同页仍无法合法取得同状态视觉证据。Flow 的手动 Fullscreen 运行路径与独立窗口结构已确认，但没有修改自动休息全屏偏好，也没有在 Computer Use 超时后伪造像素参考。
- 通知动作与分类映射已有 Flow 二进制注册/选择逻辑和 NanaFlow 红绿测试证据；应用选择与黑名单隐藏/回前台已完成实机端到端，但真实通知投递及用户点击动作仍依赖系统授权，本轮没有替用户接受通知权限。
- 日历写入、全局快捷键、浏览器自动化阻断、App Group/iCloud 跨设备同步仍依赖用户系统授权或 Apple Developer 签名；本轮没有替用户接受任何权限。
- 未签名 Debug Widget 不会被系统小组件图库稳定发现；本轮以 Widget 生产视图的原生尺寸渲染完成设计 QA，正式宿主内交互仍归入签名验收。
- Flow 的标签权益态页面无法在不购买或绕过付费的前提下取得同状态源图；NanaFlow 已完成结构、文案、行为和运行态检查，但标签页像素级同图验收仍被源证据阻塞。
- NanaFlow 尚无 App Store 条目，评分入口无法完成真实商店评论链路；正式上架并取得 App Store ID 后才可接入和验收。
- Flow 4.8 的 Base 与 20 个实际语言区已全部进入 NanaFlow 主 App 与 Widget；繁中、日文、德文、韩文、法文、西班牙文、意大利文、加泰罗尼亚文、葡萄牙语两区、荷兰文和挪威文主窗、菜单及关键次级页已完成运行抽查，十二种语言的周期格式也已本地化。其余 6 个语言区仍各有 63–70 个与英文相同的值需要逐项判断，周期格式仍是英文，且尚未逐页做布局回归；因此不能把“语言区已接入”描述成“全部语言已完全复刻”。
- 这些不构成本轮已审查页面的视觉缺陷，但仍阻止“整个产品所有状态完全一致”的结论。

## 用户复核后的对齐纠偏（2026-08-29）

- 前一版 `References/audit-2026-08-29-icon-typography-polish/flow-vs-nanaflow-toolbar-comparison.png` 的“通过”结论作废：它只做了主观观感判断，没有逐元素量化，且菜单栏错误地做成了计时胶囊。
- 主窗重新以 Flow 的 380×272、短休息 05:00、第一轮、暂停、工具栏显示状态为唯一真值。标题改为 19.5 pt Light Rounded；倒计时改为 75.5 pt Regular SF Pro；关闭、跳过、重置、统计和菜单图标分别做了 1× 光学边界与中心校准；标题、周期点和主按钮也重新锁定基线。
- 最终同状态合图为 `References/audit-2026-08-29-alignment-final/flow-vs-nanaflow-main-final.png`。关闭、标题、菜单和主按钮边界与中心完全重合；其余可见元素边界/中心偏差不超过 1 px。全图归一化像素 MSE 为 0.002004；不再把“看起来差不多”当作通过依据。
- 菜单栏按用户截图纠正为 `05:00` 文本加 `circle.righthalf.filled` 半圆，不再显示错误的描边胶囊。左键打开与 Flow 同结构的原生菜单，包含状态、暂停/开始、显示计时器、跳过、重新开始周期、设置和退出；右键或 Control-单击继续保留快速开始/暂停。
- 全量回归 `207/207`、0 failures，结果包为 `/tmp/NanaFlowFull-20260829-alignment-2.xcresult`。最终 universal Release 主 App 与 Widget 均为 `x86_64 arm64`，严格签名验证通过；压缩包 SHA-256 为 `263006a418e58016bc10a2b73c262588fa06779a15e18192a91e07fd2e224e5c`，并已从 `dist/NanaFlow.app` 实际启动。

## 菜单栏对比度纠偏（2026-08-29）

- 用户实机截图证明休息绿同时污染了时间和半圆，在蓝色菜单栏上对比度不足；此前只对齐形状、没有检查真实桌面背景上的可读性，原结论作废。
- 默认菜单栏样式现改用 AppKit 动态 `labelColor`，并在刷新时同步 `NSStatusBarButton.effectiveAppearance`。时间、右半圆和可选会话标题会随菜单栏深浅自动切换高对比前景色；休息彩色偏好只继续作用于另两种纯图标样式。
- 生产 `MenuBarStatusContent` 在同蓝色背景、dark Aqua 外观下的缓存渲染为 `References/audit-2026-08-29-menubar-contrast/final/A4BFE285-B33E-4F81-B40B-53F2C38B690B.png`，显示白色 `05:00` 与白色右半圆；测试同时逐像素确认至少 20 个高亮像素，避免再次退回暗色。
- 全量回归 `207/207`、0 failures，结果包为 `/tmp/NanaFlowFull-20260829-menubar-contrast-2.xcresult`。最终 universal Release 与 Widget 均为 `x86_64 arm64`，严格签名验证通过；ZIP SHA-256 为 `86fa1e749800d6b32b5df988df81e5ee36e56f769a068d0cae789b98c0ee7873`，并已从 `dist/NanaFlow.app` 重启到新进程。

## 迷你计时器误判纠正（2026-08-29）

- 用户提供的菜单截图底部明确写着“退出 NanaFocus”，不是 Flow；此前将其当成 Flow 功能证据属于来源归类错误。
- 已删除迷你计时器的 SwiftUI scene、状态栏菜单项、通知路由、窗口命令、源码文件及 Xcode 工程引用，并增加反向契约测试防止再次引入。
- 全量回归 `205/205`、0 failures，结果包为 `/tmp/NanaFlowFull-20260829-remove-mini-green.xcresult`。
- 最终 universal Release 主 App 与 Widget 均为 `x86_64 arm64`，严格签名验证通过；ZIP SHA-256 为 `12ae5e6943691580b4b04ba9840a99b7033c26319c17ad579bb5b66496428dc9`。

## 用户指出后的主窗设计稿同状态纠偏（2026-08-30）

- 上一版“已对齐”的结论作废。根因是把设计稿当成方向参考，没有把设计稿与运行版归一到同一 380×272 画布、同一 25:00 暂停状态逐元素比较；同时保留了设计稿不存在的动态进度填充。
- 源视觉真值为用户附件底部设计区域，经原比例裁切并从 760×544 @2x 归一为 `References/audit-2026-08-30-main-fidelity/00-target.png`（380×272）；最终运行版为 `References/audit-2026-08-30-main-fidelity/15-delivery.png`（380×272）。
- 最终全图同输入对照为 `References/audit-2026-08-30-main-fidelity/16-delivery-compare.png`，左侧设计稿、右侧运行版；工具栏局部对照为 `References/audit-2026-08-30-main-fidelity/17-delivery-toolbar-zoom.png`。两侧均为专注、暂停、25:00、第一轮状态。
- 布局已按设计稿重新量尺：窗口圆角 26 pt，标题 20 pt，计时 70 pt、字距 -1.5 pt，周期点中心 y=168.5，主按钮中心 y=220；关闭、重置、统计、更多入口均重新校准光学中心。
- 行为已纠正：第一轮专注状态固定显示 27×12 的完整绿色胶囊，不再把实时进度画进设计稿未要求的胶囊；播放使用填充三角形，运行态切换为暂停图标。
- 颜色已从设计稿取样：窗口表面 `#F8F9FA`，专注强调色 `#3E927A`；标题、数字、周期点和按钮层级在同图中无剩余 P0/P1/P2。
- 此轮把工具栏与主按钮的明显差异归为“SF Symbols 的 P3 残差”是错误结论，已由下方按钮专项纠偏作废。
- 主交互用真实运行版复查：开始后主按钮辅助功能标题由“开始”变为“停止”，重新开始后回到 25:00 暂停态；运行证据为 `References/audit-2026-08-30-main-fidelity/18-delivery-running.png`。
- 全量回归：207/207，0 failures；日志 `/tmp/nanaflow-main-fidelity-full.log`。最终 universal Release 构建成功，`dist/NanaFlow.app` 为 x86_64 + arm64，ad-hoc 严格签名验证通过并已从该产物实际启动。

### 五项终审

- 字体与排版：通过。标题、数字、等宽数字、字距和基线按同状态 1:1 合图复核。
- 间距与布局：通过。窗口外框、四角圆角、工具栏、标题、计时、周期点、主按钮均按 380×272 坐标契约锁定。
- 颜色与令牌：通过。表面色与专注色直接使用设计稿采样值。
- 图标与资产：通过。最终版本直接复用视觉稿所选 Phosphor Icons 的官方矢量资源，并保留模板渲染和辅助功能语义。
- 文案与交互：通过。`NanaFlow`、`25:00`、周期状态与开始/暂停/重新开始行为一致。

## 按钮样式专项纠偏（2026-08-30）

**Findings**

- [P2] 工具栏图标家族错误。设计稿实际使用 Phosphor Icons；旧实现用 SF Symbols 代替，导致重置箭头、统计柱底线和菜单圆点轮廓全部不同。证据：修正前局部合图 `References/audit-2026-08-30-button-fidelity/01-toolbar-before.png`。
- [P2] 按钮颜色层级错误。设计稿工具栏为 `#202522`，关闭按钮 42%；旧实现又叠加 88%/28% 透明度，整体偏灰。主按钮设计稿为实色 `#DFECE8` + `#2F7B67`，旧实现用强调色 13% 透明混合，背景过淡。证据：修正前主按钮局部 `References/audit-2026-08-30-button-fidelity/02-primary-before.png`。
- [P2] 图标尺寸与按钮反馈缺失。旧实现播放图标为 20 pt，而视觉稿为 25 pt；工具按钮缺少视觉稿的 hover 背景和 96% 按压反馈。

**Fixes**

- 从视觉稿已经安装的 `@phosphor-icons/react` 2.1.10 直接导出 `XCircle/ArrowCounterClockwise/ChartBar/DotsThreeVertical/Play/Pause` 官方 SVG，作为保留矢量和模板渲染的 Asset Catalog 资源进入生产应用；没有手绘或临摹图标。
- 工具栏命中区调整为 29 pt，图标按视觉稿分别使用 17/19/20/20 pt；主按钮使用 25 pt Fill Play 与 22 pt Regular Pause。
- 工具栏、关闭按钮、主按钮背景/前景、hover 和 pressed 状态全部采用视觉稿的明确令牌。

**Post-fix evidence**

- 源视觉真值：`References/audit-2026-08-30-main-fidelity/00-target.png`，380×272，归一后的 1× 专注暂停 25:00 状态。
- 生产运行截图：`References/audit-2026-08-30-button-fidelity/04-active-after.png`，380×272，同状态。
- 全图同输入：`References/audit-2026-08-30-button-fidelity/05-after-comparison.png`，左设计稿 / 右运行版。
- 工具栏局部：`References/audit-2026-08-30-button-fidelity/06-toolbar-after.png`，上设计稿 / 下运行版；图标家族、轮廓、尺寸、间距和前景层级一致，无剩余 P0/P1/P2。
- 主按钮局部：`References/audit-2026-08-30-button-fidelity/07-primary-after.png`，左设计稿 / 右运行版；42 pt 圆形、实色背景、填充播放图标和光学偏移一致，无剩余 P0/P1/P2。局部图的轻微锐度差来自 PNG 设计稿与 Computer Use JPEG 捕获格式，不作为视觉偏差。
- 交互：真实运行版开始后辅助功能标题由“开始”变为“停止”，随后点击“重新开始周期”恢复 25:00 暂停态；运行证据 `References/audit-2026-08-30-button-fidelity/08-running-after.png`。
- 测试：针对性测试先以缺失 Phosphor 资产和令牌产生有效 RED，修复后 GREEN；全量 207/207、0 failures，日志 `/tmp/nanaflow-button-style-full.log`。最终 universal Release 仍为 x86_64 + arm64，严格签名验证通过。

**Required fidelity surfaces**

- Fonts/typography：通过，本轮未改变已锁定的标题与计时排版。
- Spacing/layout rhythm：通过，按钮中心坐标不变，命中区与视觉稿统一为 29 pt。
- Colors/tokens：通过，按钮令牌直接对应视觉稿 CSS。
- Image quality/asset fidelity：通过，使用视觉稿同源官方矢量图标，无替代绘制。
- Copy/content：通过，按钮标签与辅助功能语义保持完整。

final result: passed

## 统计柱状图精确数量交互（2026-08-30）

> 本节中的长文案与点击固定方案已由下方“统计刻度与悬浮提示精简纠偏”取代，仅保留为迭代记录。

**Findings**

- [P2] 原柱子只有高度比较，没有可见的精确数量反馈；鼠标用户无法确认某天具体完成了多少个 Flow。
- [P2] 当前周期的前进按钮仅比较 `anchor < Date()`，同一天、同一周、同一月和同一年内仍可能错误进入未来空周期。
- [P3] 日统计缺少最后一个 23 点刻度；辅助功能树又把所有柱子压成同一个“统计图表”标签。

**Fixes and evidence**

- 悬浮柱子即时显示 `日期/时段 · N 个 Flow`；点击可固定提示，再次点击取消。空柱同样可以查看 0 个 Flow，不新增详情窗口。
- 提示使用现有专注强调色、10 pt Rounded Semibold 和紧凑胶囊；周视图实机证据为 `References/audit-2026-08-30-statistics-interaction/07-week-pinned-clean.png`，修正前/点击固定后的同尺寸对照为 `References/audit-2026-08-30-statistics-interaction/08-before-after.png`，显示“8月29日 · 3 个 Flow”。
- 实机辅助功能树已确认 D/W/M/Y 分别生成 24/7/31/12 个可操作柱子；8 月月视图为 31 柱，周视图为 7 柱，年视图为 12 柱。每柱均暴露日期、数量和“点击固定此数据”提示。
- 当前周期的右箭头在四个周期均为 disabled；日轴补充 23 点终点刻度，月轴保留首日、每 5 日和末日。
- 全量测试 211/211、0 failures，日志 `/tmp/nanaflow-statistics-full-test.log`。最终 `dist/NanaFlow.app` 为 x86_64 + arm64，严格签名验证通过并已从该产物实际启动。

**Required fidelity surfaces**

- Fonts/typography：通过，提示文字沿用现有 Rounded 字体体系，没有改变统计页标题和刻度字号。
- Spacing/layout rhythm：通过，提示覆盖在图表顶部留白，不扩窗、不挤压柱子或周期切换器。
- Colors/tokens：通过，只复用现有窗口底色与专注强调色。
- Image quality/asset fidelity：通过，本轮没有新增位图或替代图标。
- Copy/content：通过，四个周期的日期粒度和 Flow 数量一一对应，辅助功能信息完整。

final result: passed

## 统计刻度与悬浮提示精简纠偏（2026-08-30）

**Findings**

- [P2] 日/月统计的文字被单柱宽度约束，`0 / 6 / 12 / 18 / 23` 等刻度被渲染成省略号，等同于刻度不可用。
- [P2] 上一轮悬浮提示包含日期、单位并增加点击固定状态，超过了快速读取单柱数量所需的信息量。

**Fixes and evidence**

- 刻度文字保留柱子原宽，但允许文字按自身宽度绘制；日视图现在显示裸数字 `0 / 6 / 12 / 18 / 23`，月视图同样显示日期数字，不再附加“时/日”或省略号。完整单位仍保留在辅助功能标签中。
- 悬浮气泡只显示该柱的数量数字，宽度从 126 pt 收敛到 32 pt；删除点击固定、选中描边和相关提示，离开柱子即隐藏。
- 源视觉真值：`References/audit-2026-08-30-statistics-concise/00-source-original.png`（718×514）；按相同比例归一到 380×272 后为 `00-source-normalized.png`。
- 最终运行截图：`References/audit-2026-08-30-statistics-concise/05-day-labels-final.png`（380×272）；同尺寸全图对照：`06-source-vs-final.png`。两侧数据量分别为 1 次和 2 次，只比较布局、刻度和视觉层级。
- 全图已经足以清楚辨认本轮关键细节，不需要额外局部裁图。源图中的省略号已在最终图中替换为完整数字刻度，未引入新的布局漂移。
- 悬浮文本契约与无点击固定状态由针对性测试覆盖；全量回归 211/211、0 failures，日志 `/tmp/nanaflow-statistics-concise-full.log`。最终 `dist/NanaFlow.app` 为 x86_64 + arm64，严格签名验证通过并已实际启动。

**Required fidelity surfaces**

- Fonts/typography：通过，刻度仍使用原 8 pt Rounded Semibold，只修复截断并去掉视觉单位。
- Spacing/layout rhythm：通过，柱宽、柱距、图表高度和周期切换器未改变。
- Colors/tokens：通过，数字气泡继续复用专注强调色。
- Image quality/asset fidelity：通过，本轮没有新增图像资产。
- Copy/content：通过，气泡只保留数量数字；时间和日期语义继续由轴刻度及辅助功能标签承担。

final result: passed
