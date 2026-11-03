# 1.0.1（4）官方商店下载复核

复核时间：2026-11-03 13:56 UTC。此记录补充当天已提交的官方下载结果（`12cb6b4`），只核对现有安装，不重新下载安装或运行测试。

| 项目 | 实际结果 |
| --- | --- |
| 安装路径 | `/Applications/NanaFlow.app` |
| 主程序 | `com.nanafox.NanaFlow`，1.0.1（4） |
| 内嵌 Widget | `com.nanafox.NanaFlow.Widget`，1.0.1（4） |
| 两目标签名 | `Apple Mac OS Application Signing`，Team `LTLULSL8A2` |
| 两目标严格验证 | `codesign --verify --strict --verbose=2` 均退出 0 |
| Gatekeeper | `spctl --assess --type execute --verbose=4` 退出 0，`accepted`，`source=Mac App Store` |
| 商店收据 | `Contents/_MASReceipt/receipt` 存在，4830 字节；未导出或公开收据内容 |
| 正在运行的主程序 | 一个主进程，路径为上述商店 App 的 `Contents/MacOS/NanaFlow` |
| Widget 注册 | 精确查询正式 Widget 身份只返回一个条目，来自上述商店 App 内嵌扩展 |

官方产物的可执行文件 SHA-256：

- 主程序：`79c96c3db312c6929c8c84ea1cffb74b45cf170775afba1f4731a8445474e35c`
- Widget：`64ddc0a3cc778ea58a8d1ec0c140260eb69078bef3c6519120f872c0ea98f24e`

这些结果确认本机实际取得并正在运行官方商店 1.0.1（4），不再是此前无收据的开发签名候选。Apple 重签后的摘要与开发候选不同是渠道差异，不能要求两者摘要相同。

本轮没有退出、重开或覆盖现用 App，没有读取真实偏好与历史内容，也没有恢复旧备份。此前开发签名 Release 候选的首启、退出重开和可见状态保留验收仍保留原范围；本轮不把它改称商店变体的重开或全历史迁移验收。通知动作、Widget 宿主画面刷新及实际发声也没有重测或记录为通过。

1.0.1 官方下载获取门已关闭。后续工作沿用 [现有 1.0.2 计划](../Plans/release-1.0.2.md) 和 [维护交接](../Plans/project-maintenance.md)，不由旧发行跟进再次派发。
