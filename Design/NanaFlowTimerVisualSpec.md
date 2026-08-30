# NanaFlow 主计时页视觉规范

## 设计目标

以 `Design/flow-ui-prototype` 的 380×272 主窗和用户确认的截图为视觉真值。视觉稿采用 Phosphor Icons，因此生产应用复用同一套官方矢量图标，不再用相似但轮廓不同的 SF Symbols 代替。

## 版式

| 元素 | 规格 |
| --- | --- |
| 内容区域 | 380×240 pt，窗口外观 380×272 px（1×） |
| 窗口圆角 | 26 pt continuous |
| 标题 | SF Pro Rounded，20 pt Regular，中心 y=60.5 |
| 倒计时 | SF Pro，70 pt Regular，等宽数字，字距 -1.5 pt，中心 y=120 |
| 周期指示 | 12 pt 圆点 / 27×12 pt 胶囊，间距 5 pt，中心 y=168.5 |
| 主按钮 | 42×42 pt，中心 y=220 |
| 顶部工具栏 | 中心 y=26；29 pt 命中区；关闭、重置、统计、菜单中心 x=28.5/286/318.5/351.5 |

## 按钮与图标

| 功能 | Phosphor Icon | 图标尺寸 |
| --- | --- | --- |
| 关闭 | `XCircle` Fill | 17 pt |
| 重置 | `ArrowCounterClockwise` Regular | 19 pt |
| 统计 | `ChartBar` Regular | 20 pt |
| 菜单 | `DotsThreeVertical` Bold | 20 pt |
| 开始 | `Play` Fill | 25 pt |
| 暂停 | `Pause` Regular | 22 pt |

- 工具栏专注态使用 `#202522`，关闭按钮为该颜色的 42%；休息态工具按钮为白色，关闭按钮为白色的 55%。
- 工具按钮 hover 背景为正文色 7%，休息态为白色 12%；按下缩放至 96%。
- 主按钮专注态背景为 `#DFECE8`、前景为 `#2F7B67`；hover 亮度降低 3%，按下缩放至 96%。
- 所有图标来自已安装的 `@phosphor-icons/react` 2.1.10，并以保留矢量的模板资源进入 Asset Catalog；不手绘、不转成字符图标。

## 验收

以 380×272、专注、暂停、25:00、第一轮为基准状态，同时检查全图、工具栏局部和主按钮局部；按钮的图标轮廓、前景层级、背景填充、尺寸、位置和交互状态不得存在 P0/P1/P2 差异。
