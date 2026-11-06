# CC Models 场景登记册（modules/app.md）

场景源头：docs/superpowers/specs/2026-11-04-cc-model/verification.md（已随 specs 归档至 docs/superpowers/archived/2026-11-04-cc-model/）。
S9/S10 由 `swift test` 套件承载（资产：Tests/ccmodelTests/）；S11–S15 与 S1–S8 为人工清单（资产：归档验证方案的人工步骤），机器可操作部分由控制者执行、观察点由需求方确认。

- APP-L3-001 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S1 | normal | 点菜单模型项 → env 键组精确替换、非 ANTHROPIC 内容保留、通知逐字、菜单重排置顶
- APP-L3-002 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S2 | normal | 切换失败（损坏 JSON）→ 字节不变 + 失败通知逐字
- APP-L3-003 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S3 | normal | 未命中 → 置灰自定义配置 → 弹窗纳入新模型（重名拦截不关闭）
- APP-L3-004 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S4 | normal | 覆盖已有模型：env 整体替换、显示名/默认保持、成为当前
- APP-L3-005 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S5 | normal | 取消后同 env 不再弹窗；env 变化后再次弹窗
- APP-L3-006 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S6 | normal | 首跑：欢迎窗 → 预填 → 保存 → 常驻；退出出口零写入
- APP-L3-007 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S7 | normal | 编辑生效中模型 → 立即应用 + 通知 + 不弹自定义配置
- APP-L3-008 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S8 | normal | 删除守卫置灰 + 删默认首个补位
- APP-L1-009 | L1 | Tests/ccmodelTests（swift test） | normal | _NAME 同步规则三例（派生跟随/自定义保留/清空双删）
- APP-L1-010 | L1 | Tests/ccmodelTests（swift test） | normal | settings.json 四路径语义（替换保留/创建/损坏字节不变/只读前缀）
- APP-L2-011 | L2 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S11 | normal | 通知授权被拒 → 静默降级、切换不受影响
- APP-L2-012 | L2 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S12 | normal | 开机自启登记/注销/失败回拨（需 /Applications）
- APP-L2-013 | L2 | scripts/make-app.sh | normal | 打包产物 lint/签名/启动状态项出现
- APP-L3-014 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S14 | normal | 表单三类校验错误拦截且不落库
- APP-L3-015 | L3 | docs/superpowers/archived/2026-11-04-cc-model/verification.md#S15 | normal | 新会话实际使用目标供应商（最终效果）

## UI 视觉优化迭代（2026-11-06-ui-visual-polish）并入

- APP-L1-016 | L1 | Tests/ccmodelTests（swift test） | normal | 状态项标题新语义断言与全部既有回归通过（原方案 V-01/V-08）
- APP-L2-017 | L2 | docs/superpowers/archived/2026-11-06-ui-visual-polish/verification.md#V-02 | normal | 状态项箭头图标+纯名标题，明暗菜单栏均清晰
- APP-L3-018 | L3 | docs/superpowers/archived/2026-11-06-ui-visual-polish/verification.md#V-03 | normal | 三窗+弹窗深色主题一致，深色下校验提示与密文点可辨
- APP-L3-019 | L3 | docs/superpowers/archived/2026-11-06-ui-visual-polish/verification.md#V-04 | normal | 四个业务窗口/弹窗打开均居中主屏
- APP-L3-020 | L3 | docs/superpowers/archived/2026-11-06-ui-visual-polish/verification.md#V-05 | normal | 偏好窗 720×480/最小 660×430、密度松、四档横排四列
- APP-L3-021 | L3 | docs/superpowers/archived/2026-11-06-ui-visual-polish/verification.md#V-06 | normal | 首跑表单无默认行，保存后模型仍自动成为默认
- APP-L3-022 | L3 | docs/superpowers/archived/2026-11-06-ui-visual-polish/verification.md#V-07 | normal | 深色化后弹窗三出口行为与既有语义一致

## bugfix 迭代（settings-slash-paste-menu）并入

- APP-L1-023 | L1 | Tests/ccmodelTests（swift test） | normal | settings.json 写入不转义斜杠（URL 值原样可读，JSON 语义等价）
- APP-L2-024 | L2 | docs/superpowers/archived/2026-11-06-ui-visual-polish/verification.md（人工：表单粘贴） | normal | 表单输入框 Cmd+V 粘贴有效（主菜单编辑装配回归）

## CC Models 改名（2026-11-06-rename-cc-models）并入

- APP-L1-025 | L1 | docs/superpowers/archived/2026-11-06-rename-cc-models/verification.md#R1-01 | normal | 显示面旧名检索命中 0（升级/卸载说明 2 处按口径排除）且 swift test 143 全绿
- APP-L2-026 | L2 | docs/superpowers/archived/2026-11-06-rename-cc-models/verification.md#R1-02 | normal | 打包产物 dist/CC Models.app，plist 名称=CC Models、可执行名 ccmodel 与标识 com.ccmodel.app 不变
- APP-L1-027 | L1 | docs/superpowers/archived/2026-11-06-rename-cc-models/verification.md#R1-03 | normal | README 无旧名残留（升级/卸载说明除外）、测试计数为 143
- APP-L3-028 | L3 | docs/superpowers/archived/2026-11-06-rename-cc-models/verification.md#R1-04 | normal | 退出菜单/偏好窗/欢迎窗/应用菜单/通知标题/损坏弹窗均显示 CC Models，开机自启重新登记
