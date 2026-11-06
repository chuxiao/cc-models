# CC Model UI 视觉优化 实现设计

> 读者：审查者与实施者。本文是本需求涉及接口变更与视觉规格值的唯一权威定义；plan.md 只引用章节号。

## 0. 形态声明

产物形态：桌面 App（既有应用视觉层迭代）。
章节裁剪推导：数据与状态设计——不设独立章，见 §2 声明（零新增持久化）；运行与部署——不设（沿用既有交付形态）。

## 1. 结构设计

零新增子系统；新增一个单文件基座类型 WindowPresenter（I-3）。触及的既有文件与职责：

| 文件 | 触及内容 |
|------|---------|
| `Sources/ccmodel/WindowPresenter.swift`（新增） | I-3 居中基座 |
| `Sources/ccmodel/StatusItemController.swift` | 状态项图标（模板图注入）、标题语义变更（去 ⇄ 前缀）、readEnv 失败标题 |
| `Sources/ccmodel/ProfileFields.swift` | `statusItemTitle(displayName:)` 语义变更（见 I-1） |
| `Sources/ccmodel/AppDelegate.swift` | 全局固定深色外观装配；偏好窗居中接线（Task 2） |
| `Sources/ccmodel/PreferencesWindow.swift` | 默认尺寸/最小尺寸、居中、排版密度 |
| `Sources/ccmodel/ProfileFormView.swift` | 四档横排四列、`hidesDefaultToggle` 参数、深色适配微调 |
| `Sources/ccmodel/FirstRunCoordinator.swift` | 首跑窗传 `hidesDefaultToggle: true`、窗口居中 |
| `Sources/ccmodel/WelcomeWindow.swift` | 居中、深色适配 |
| `Sources/ccmodel/ImportDialog.swift` | 弹窗居中、深色适配 |
| `Tests/ccmodelTests/ProfileFieldsTests.swift`、`ModelSwitcherTests.swift` | 标题语义变更的断言更新（I-1） |

基线模块（archived/2026-11-04-cc-model 计划的 Task 2–4：存储/写引擎/检测）零改动。依赖方向不变：视觉层改动全部位于 UI 层与基线 Task 1 纯函数的一处语义变更。

## 2. 数据与状态设计（声明）

零新增持久化、零 schema 变更、零状态新增（`isTokenSecure`/`validationErrors` 为 Task 6 既有；`hidesDefaultToggle` 是视图构造参数，不是状态）。

## 3. 接口设计（变更与新增）

### I-1 `ProfileFields.statusItemTitle(displayName:)` — 语义变更

- **职责：** 返回状态项按钮的文字标题（图标改为独立模板图后，文字仅承担模型名）。
- **签名：** 不变 `static func statusItemTitle(displayName: String) -> String`。
- **参数表：**

  | 参数 | 类型 | 含义 | 约束/非法值 |
  |------|------|------|------------|
  | displayName | String | 当前模型显示名 | 空串合法（返回空串）；超 12 字符截断 |
- **行为变更：** 返回值由 `"⇄ " + 截断名` 变更为 `截断名`（截断规则不变：超 12 字符取前 12 + 「…」）。
- **错误表：** 无（纯函数，无抛错路径）。
- **示例：** `statusItemTitle(displayName: "智谱")` → `"智谱"`；13 字符名 → 前 12 字符 + `"…"`。
- **被谁依赖：** StatusItemController（正常态与切换后刷新）；readEnv 失败态的「—」标题语义不变（I-2）。
- **连带断言更新：** ProfileFieldsTests 的 ⇄ 前缀断言、13 字符截断断言按新语义改写；ModelSwitcherTests 的 titleWriter 时序断言 `["⇄ —"]`/`["⇄ —", "⇄ 智谱"]` 改为 `["—"]`/`["—", "智谱"]`。此变更为内部行为破坏性变更（签名不变、返回值语义变化，既有断言全量改写）。

### I-2 StatusItemController 状态项图标 — 新增装配

- **职责：** 状态项按钮 = 系统符号「直线双向箭头」模板图 + 文字标题。
- **签名（注入缝）：** `var symbolProvider: () -> NSImage?`——默认 `{ NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil) }`；返回 nil 走纯文字回退（测试注入 nil 覆盖回退分支）。
- **参数表（装配行为）：**

  | 项 | 值 | 说明 |
  |----|-----|------|
  | button.image | symbolProvider() 结果 | `isTemplate = true`，点阵尺度适配状态栏 |
  | button.title | I-1 返回值 / `"—"`（失败/未命中态） | 既有 titleWriter 缝语义保留 |
- **错误表：**

  | 条件 | 行为 |
  |------|------|
  | symbolProvider 返回 nil | 无图像、仅文字标题，不崩溃（单测覆盖） |
  | readEnv 抛错/未命中 | 文字 `"—"`，图像不变 |
- **示例：** 正常态按钮呈现「[双向箭头图] 智谱」；失败态呈现「[双向箭头图] —」。
- **被谁依赖：** Main 装配链。

### I-3 窗口居中基座 — 新增

- **职责：** 统一「窗口打开前居中」。
- **签名：** `enum WindowPresenter { static func prepare(_ window: NSWindow) }`——内容尺寸设置调用方自理，`prepare` 内执行居中。
- **参数表：**

  | 参数 | 类型 | 含义 | 约束/非法值 |
  |------|------|------|------------|
  | window | NSWindow | 待呈现窗口 | 须已完成内容尺寸设置 |
- **行为：** 执行 `window.center()`。多显示器复用路径（已裁决，2026-11-06）：窗口曾被拖往副屏时，prepare 先将窗口归位主屏可见范围再 center——「主屏为锚」在复用路径仍成立。
- **错误表：** 无抛错路径；window 未设 contentSize 时以系统默认尺寸居中（调用方顺序纪律覆盖）。
- **示例：** 偏好窗口 `makeKeyAndOrderFront` 前调用 `WindowPresenter.prepare(window)` → 窗口中心 == 所在屏中心。
- **被谁依赖：** PreferencesWindow（Task 2 接线，经 AppDelegate 两条路径）、FirstRunCoordinator（两窗）、ImportDialog（弹窗窗口）。

### I-4 `ProfileFormView` 参数 — 新增

- **职责：** 支持首跑窗隐藏「设为默认」行。
- **签名变更：** 视图初始化参数列表末尾增加 `hidesDefaultToggle: Bool = false`（默认值置末，保既有调用点零改动）。
- **参数表：**

  | 参数 | 类型 | 含义 | 约束/非法值 |
  |------|------|------|------------|
  | hidesDefaultToggle | Bool | true 隐藏「设为默认」勾选行 | 无非法值 |
- **行为：** `true` 不渲染该行；`false`（偏好窗）渲染不变。
- **错误表：** 无（视图构造参数，无抛错路径）。
- **示例：** `ProfileFormView(model: model, hidesDefaultToggle: true)` → 渲染的表单不含「设为默认」行。
- **被谁依赖：** PreferencesWindow（false/缺省）、FirstRunCoordinator（true）。

## 4. 流程设计

零新增链路。视觉变化全部发生在既有链路的呈现点：启动装配（外观+图标）、窗口打开（居中+尺寸）、表单渲染（横排/参数）。

## 5. 界面实现规格（视觉规格唯一权威值）

**全局**：`NSApp.appearance = NSAppearance(named: .darkAqua)`（启动时一次性设置，三窗口+弹窗统一继承深色；AppKit 深色常量为 `.darkAqua`）。

**色值表**（冻结稿 mockups/preferences.html 为准，实现取值如下）：

| 用途 | 值 |
|------|-----|
| 窗口卡面 | #1E1E24 |
| 侧栏/标题栏 | #24242C |
| 分隔线/描边 | rgba(255,255,255,0.06–0.10) |
| 输入框底 | #16161B |
| 选中行 | #3A3F4D |
| 主按钮渐变 | linear-gradient 135°，#4F8DFF → #7C5CFF |
| 「默认」徽标渐变 | 同主按钮渐变 |
| 系统勾选蓝 | #0A84FF |
| 主文字 | #E2E2EA |
| 辅助文字 | #8F8F9C |

**文案映射（已裁决，2026-11-06）**：表单标签与窗口标题按冻结稿逐字改写——「接入点 URL / API Token / 设为默认模型 / 保 存 / CC Model 设置」。属视觉层变更，不在既有逐字文案红线内（该红线仅辖通知/菜单/弹窗三出口与「（默认）」徽标）。

**符号名**：`arrow.left.arrow.right`（系统符号库，macOS 13 目标下有效）。

**状态项**：符号 `arrow.left.arrow.right`，模板图，点阵尺寸适配状态栏（约 16pt）；标题 = I-1。

**偏好窗口**：内容尺寸 720×480，最小 660×430；侧栏 200pt；表单内边距 20pt；行间距 14pt；档位横排四列等宽（HStack spacing 8）。

**图标/文字渲染、深色逐控件微调**：留给构建者（design §4），边界=不偏离冻结稿观感。

## 6. 规模评估

触及 8 个既有源文件 + 新增 1 个源文件 + 2 个测试文件；预估改动 ~200 行（视觉参数为主，逻辑增量仅 I-1/I-2/I-3/I-4 四个接口点）；零新增依赖。

## 7. 设计依据 / 约束 / 风险

- 依据：视觉稿冻结件（mockups/exploration.html、preferences.html）与 decisions.md 五条裁决；statusItemTitle 语义变更是图标化的必然配套，属内部行为破坏性变更（签名不变、返回值语义变化，既有断言全量改写）——已由本文件冻结，测试断言更新随 Task 1。
- 约束：139 条既有测试语义保持（仅 I-1 连带断言按新语义改写）；零新增依赖；行为零变更红线（design §3 第 1 条）。
- 风险：SF Symbol 渲染在不同菜单栏高度下的点阵微差（示意级）；深色固定外观在浅色系统下的观感（需求方已选定）。触发/影响/缓解三要素详表见 plan.md §5。

## 附：独立审读处置记录

待审读。
