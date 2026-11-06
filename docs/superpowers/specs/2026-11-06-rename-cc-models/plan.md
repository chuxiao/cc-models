# CC Models 改名 实施计划

> 读者：已读 design.md 与 implementation.md；不熟悉本项目实现。实现设计见同目录 implementation.md；本文件是唯一执行依据。

## 元数据

- **目标：** 需求方在全部用户可见面看到产品名「CC Models」，功能行为零变更。
- **架构：** 纯文案层替换（显示面字符串与打包元数据），零逻辑改动、零接口变更。
- **技术栈：** 既有栈，无新增。
- **设计文档（Spec）：** 同目录 design.md（2026-11-06 确认后回填）
- **实施前决策记录 + 日期：** 2026-11-06（decisions.md 两条：改名范围、红线豁免）。
- 验证方案见同目录 `verification.md`。

## 1. 改动地图

单任务（改名横切全部触点，机械替换 + 断言同步，一个实施者一次提交最稳——拆分会制造无意义的两个审查上下文）。

**实施顺序：** 单任务，无顺序约束。

## 2. 功能单元规格

### Task 1: 产品名全局替换

**职责：** 全部显示面「CC Model」→「CC Models」（含打包产物名与系统显示名），内部标识不动，钉住文案的断言同步。

**Files:**
- Modify: `Sources/ccmodel/MenuBuilder.swift`、`Sources/ccmodel/WelcomeWindow.swift`、`Sources/ccmodel/AppMenu.swift`、`Sources/ccmodel/Notifier.swift`、`Sources/ccmodel/AppDelegate.swift`、`Sources/ccmodel/PreferencesWindow.swift`、`scripts/make-app.sh`、`README.md`、`Tests/ccmodelTests/MenuBuilderTests.swift`
- Test: 上述 Tests 文件内更新

**Interfaces:**
- Consumes: 基线全部既有接口（零变更——只改字符串字面量与打包常量）。
- Produces: 全部显示面呈现「CC Models」；`MenuBuilder` 退出项 title 新逐字值「退出 CC Models」；打包产物 dist/CC Models.app。
- 调用示例：`bash scripts/make-app.sh` → `dist/CC Models.app` 存在且 `plutil -p dist/"CC Models.app"/Contents/Info.plist` 显示 CFBundleName=CC Models。

**边界条件：**
- 替换精确整词「CC Model」，**不得**触碰 cc-model / cc_model / ccmodel / com.ccmodel.app / CC_MODEL_CONFIG_DIR 字面量（❌ 模糊替换把配置目录引用改坏 / ✅ 改名范围检索「cc-model」「ccmodel」命中数与改前一致）。
- 逐字红线：通知正文、菜单结构、「（默认）」徽标、欢迎窗正文中的行为描述句零改动（仅产品名词面替换）；通知正文（「已切换到〈name〉，对新建会话生效」等）不含产品名，不受影响。
- 断言同步：仅 MenuBuilderTests 第 25 行 `quit` fixture 的一处 title 字面量更新为新逐字值；该 fixture 被 7 个既有测试的期望数组引用（第 41/60/79/95/110/121/139 行），随 fixture 生效、测试代码本身零改动；其余 136 个测试零改动。
- 打包脚本：APP_NAME 常量与 CFBundleName/CFBundleDisplayName 同步替换；CFBundleExecutable=ccmodel、CFBundleIdentifier=com.ccmodel.app 不变；产物路径含空格的引号包裹保持。
- 环境注意：`swift test` 失败 → 重跑一次 → 仍败 `swift package reset; swift test`。

**验收标准：**
- 检索验收（限定改名范围 + 排除新值）：`grep -rnw 'CC Model' Sources Tests scripts README.md | grep -v 'CC Model\.app'` 命中数为 0（`-w` 整词匹配保证不命中新值 CC Models；README 安装/卸载说明中对旧包的 2 处指称属有意保留；范围不含 docs/——archived 按 §3 第 4 条冻结，specs 为本规格自身文本，docs/superpowers/verification/ 登记册非显示面，其事实同步见终审修复）。
- swift test 全量通过（143 条，其中 MenuBuilderTests 退出项 fixture 的 title 为新逐字值）。
- `bash scripts/make-app.sh` exit 0 且产物为 dist/CC Models.app，plutil -p dist/"CC Models.app"/Contents/Info.plist 显示 CFBundleName=CC Models。
- README 无「CC Model」残留、无旧测试计数残留（README 计数应为 143，与本分支实际一致）。

## 3. 设计依据

1. **单任务不拆分**——改名是同一语义变更横切 9 个文件，拆分只会制造「改一半」的中间态与两次审查上下文；机械替换无独立可测的中间交付物。
2. **内部标识不动的范围裁决**——见 design.md §4 D1 与 decisions.md；改标识的成本（登录项重登记、数据迁移）无用户可见收益。
3. **测试断言同步而非删除**——钉住文案的断言是回归网，改名后其价值不变（钉住新名），删除断言会丢失回归保护。

## 4. 约束

- 行为零变更红线：143 条测试中仅 MenuBuilderTests 的 `quit` fixture 一处 title 字面量随改名更新（7 个测试的期望随之生效，测试逻辑零改动），其余零改动全绿。
- 逐字红线范围（decisions.md 条目 2）：应用名文案随本需求更新；通知正文、「（默认）」徽标、菜单结构零改动。
- 零新增依赖；macOS 13+。
- 分支：`feature/rename-cc-models`。

## 5. 风险清单

| 风险 | 触发条件 | 影响 | 缓解方式 |
|------|---------|------|---------|
| 模糊替换误伤内部标识 | 替换实现不精确（子串匹配） | 配置目录引用/构建标识坏，打包失败 | 精确整词替换 + 改名范围检索验收 |
| 显示面触点遗漏 | 扫描不全 | 部分界面仍显示旧名 | 改名范围检索验收（「CC Model」命中数为 0） |
| 打包脚本三处不同步 | 只改 APP_NAME 漏 plist 槽位 | 产物显示名与应用名不一致 | 同一提交内三处同步 + plutil -p 验收 |

## 执行交接

- **建议执行方式：会话内执行。** 理由：单任务机械替换、验收标准完全可判（改名范围检索 + 测试 + 打包产物检查），派发子代理的上下文成本超过收益。
- 必需子技能：会话内执行用 `superpowers:executing-plans`。
- 请需求方审查：改名范围（显示面全改、内部标识不动）与「明确不做」四条。
- 明确确认后才进入实施。
- 实施中发现设计必须改：停止实施，回到确认门。

## 附录：独立审读处置记录

统一审读（独立子代理，2026-11-06）共三轮：

1. 首轮：2 高、3 中、10 项低危；高/中项全部处置（A-1 mockups 与冻结禁令矛盾改为「不改文件、口径以 R1 为准」；其余按建议文本落实），低危批量处置。
2. 复读：退回，新发现/残留 7 条（④⑫ 为声称已改而未落地）——已全部补齐，提交 `6a59ab6`。
3. 复审：**通过**。剩余 2 条低危为记录精度问题，已修正：①「共 142 条」单位混用改为 fixture 口径（第 25 行 `quit` fixture 被 7 个测试引用、其余 136 个测试零改动）；② decisions.md 审读补注改为如实记载「裁决」栏枚举补全，「依据」栏未改。另顺手补 plan.md 边界条件枚举的 `cc_model`。
