# CC Models 改名 验证方案

> 出处标注约定：`§N` 指 design.md、`I-N` 指 implementation.md、`Task N` 指 plan.md。

## 1. 集成面声明与双向映射

| 集成面 | 说明 | 覆盖场景 |
|--------|------|---------|
| I-A 显示面文案替换 | 源码 6 文件 11 处 | R1-01 |
| I-B 打包产物名与系统显示名 | 脚本常量 + plist 槽位 + 产物目录名 | R1-02 |
| I-C README 文档 | 7 处 | R1-03 |
| I-D 行为零变更回归 | 143 条测试（含改名断言同步） | R1-04 |

无「有面无场景」或「有场景无面」缺口。

## 2. 场景清单

### R1-01 显示面文案替换【自动化（改名范围检索 + swift test）】
- 步骤：`grep -rnw 'CC Model' Sources Tests scripts README.md | grep -v 'CC Model\.app'`（限定改名范围、-w 整词排除新值 CC Models；README 安装/卸载说明中对旧包的 2 处指称属有意保留，按 `.app` 后缀排除）——命中数应为 0；`swift test` 全量通过（MenuBuilderTests 退出项断言为新逐字值）。
- 期望：命中 0（上述 2 处升级说明除外）；143/143 通过。出处：design §R1、§5。

### R1-02 打包产物名【自动化（脚本验收）】
- 步骤：`bash scripts/make-app.sh` → 检查产物路径与 plutil。
- 期望：exit 0；产物 dist/CC Models.app；plutil -p dist/"CC Models.app"/Contents/Info.plist 显示 CFBundleName=CC Models、CFBundleExecutable=ccmodel（不变）、CFBundleIdentifier=com.ccmodel.app（不变）。出处：design §R1、§3 第 1 条。
- 判据：全部命令按期望退出。

### R1-03 README【自动化（检索）】
- 期望：无「CC Model」残留；无旧测试计数残留（README 计数应为 143，与本分支实际一致）。出处：design §R1。
- 判据：检索命中 0。

### R1-04 运行时观察【人工——需求方自验】
- 步骤：(a) 打包并替换 /Applications 旧应用后启动：核对退出菜单项、偏好窗口标题、欢迎窗正文与标题、应用菜单标题；(b) 执行一次模型切换：核对通知标题；(c) 临时将 settings.json 置为非法内容并重启：核对损坏弹窗，核验后恢复原配置。
- 期望：全部显示面产品名为「CC Models」——退出菜单项「退出 CC Models」；偏好窗口标题「CC Models 设置」；欢迎窗「欢迎使用 CC Models」；通知标题「CC Models」；损坏弹窗「CC Models 配置文件已损坏」。出处：design §R1、界面规格章。
- **随改名副作用核对**：产物名变化使 /Applications 路径改变——既有开机自启登记随之失效，安装后在偏好中重新登记一次（decisions.md 改名范围裁决的已知代价）。出处：design §4 D1。
- 清理：恢复原 settings.json。

## 3. 通过判据

- 自动化（R1-01 ~ R1-03）：命令按期望退出/命中为 0、swift test 全绿。
- 人工（R1-04）：需求方启动应用逐项核对显示面文案。

## 4. 验证环境

仓库根目录；`bash scripts/make-app.sh`。

## 5. 执行手段

- 自动化：R1-01 ~ R1-03 脚本与检索命令，控制者执行。
- 人工清单：R1-04 需求方启动应用观察（已标注）。

## 6. 内容要求落实

- 确定性固定策略：检索命中数为 0 的可判据；产物路径与 plutil 键值逐字。
- 副作用隔离：自动化场景无真实文件操作；R1-04 涉及替换安装与临时破坏配置两处真实文件操作，核验后还原。
- 失败证据采集：检索命中清单、swift test 输出、plutil 输出。

**修复闭环轮次上限：3**。
