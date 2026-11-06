# CC Models 改名 实现设计

> 读者：审查者与实施者。本文是改名触点与替换规则的权威定义；plan.md 只引用章节号（执行依据的「唯一」地位在 plan.md）。

## 0. 形态声明

产物形态：桌面 App（文案层迭代）。
章节裁剪推导：数据与状态设计——不设独立章（零数据变更，见 §2 声明）；运行与部署——不设（交付形态不变，脚本触点见 §1 表）。

## 1. 结构设计

零新增模块、零接口变更、零行为变更。触及文件与替换规则（全部为显示面，内部标识不动）：

| 文件 | 触及内容 | 替换规则 |
|------|---------|---------|
| `Sources/ccmodel/MenuBuilder.swift` | 退出菜单项 title | 「退出 CC Model」→「退出 CC Models」 |
| `Sources/ccmodel/WelcomeWindow.swift` | 窗口 title、标题 Text、正文 Text | 三处「CC Model」→「CC Models」 |
| `Sources/ccmodel/AppMenu.swift` | 应用菜单 item title、NSMenu title、退出项 title、第 8 行文档注释 | 四处「CC Model」→「CC Models」 |
| `Sources/ccmodel/Notifier.swift` | 通知 content.title | 「CC Model」→「CC Models」 |
| `Sources/ccmodel/AppDelegate.swift` | 配置损坏弹窗 messageText | 「CC Model 配置文件已损坏」→「CC Models 配置文件已损坏」 |
| `Sources/ccmodel/PreferencesWindow.swift` | 窗口 title | 「CC Model 设置」→「CC Models 设置」 |
| `scripts/make-app.sh` | APP_NAME 常量、heredoc 内 CFBundleName/CFBundleDisplayName 槽位、头注释、结尾 echo 安装提示（第 74 行）——共 5 处 | 「CC Model」→「CC Models」（注意：CFBundleExecutable=ccmodel 与 CFBundleIdentifier=com.ccmodel.app 不变） |
| `README.md` | 标题与正文 7 处 | 「CC Model」→「CC Models」（不含 cc-model 路径、ccmodel 代码标识） |
| `Tests/ccmodelTests/MenuBuilderTests.swift` | 退出项逐字断言 | 「退出 CC Model」→「退出 CC Models」 |

依赖方向不变：纯文案层，无逻辑改动；`MenuBuilderTests` 的逐字断言更新是唯一测试改动。

## 2. 数据与状态设计（声明）

零新增持久化、零 schema 变更。配置目录 cc-model、配置文件名、settings.json 全部不变；既有用户配置无需迁移。

## 3. 接口设计（声明）

零接口变更——`statusItemTitle`、`WindowPresenter.prepare`、`ProfileFormView` 参数等既有接口的签名与语义不变；本需求只改字符串字面量与打包元数据。

## 4. 流程设计

零新增链路。

## 5. 界面实现规格

- 替换语义：全量触点逐字替换「CC Model」→「CC Models」，**不得**误伤内部标识（cc-model、ccmodel、com.ccmodel.app、CC_MODEL_CONFIG_DIR 字面量——替换用精确整词匹配「CC Model」而非模糊替换）。
- 检索验收：改名范围内「CC Model」命中为 0（内部标识不在检索范围）。
- 通知标题：UNNotificationContent.title 由「CC Model」改「CC Models」；通知正文（模型名相关）零改动。
- 打包脚本：APP_NAME 常量与 CFBundleName/CFBundleDisplayName 同步；产物变为 dist/CC Models.app（路径含空格，脚本已有引号包裹，核验即可）。

## 6. 规模评估

24 处字符串替换、9 个文件；零逻辑改动；预估 ~25 行 diff。

## 7. 设计依据 / 约束 / 风险

- 依据：需求方定名「CC Models」；decisions.md 范围裁决。
- 约束：行为零变更红线（143 条测试除 MenuBuilderTests 改名断言外零改动全绿）；逐字红线范围裁定（decisions.md 条目 2）。
- 风险：模糊替换误伤内部标识（触发：替换实现为子串匹配而非整词。影响：配置目录引用/构建标识损坏。缓解：精确整词替换 + 检索验收，见 §5 检索口径）；README 计数（143）不受影响。

## 附：独立审读处置记录

待审读。
