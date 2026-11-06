# CC Model 验证环境与手段

- 单测层：`swift test`（139 条；冷启动 TestingMacros 失败为已知环境 flake，处置序列 = 重跑一次 → `swift package reset; swift test`）
- 集成层（L1）：单机桌面工具，无数据库/中间件；组装验证由单测（临时目录 store/writer 组装）+ 人工场景 S1–S8 承载
- 接口兼容层：对外接口 = `~/.claude/settings.json` env 块格式；S1/S2 人工核对即兼容检查；首次实现无基线前代
- 可运行层（L2）：`bash scripts/make-app.sh` 产物 dist/CC Model.app，或开发目录 `swift run`（登录项场景必须 /Applications）；时长上限：有界（分钟级）
- 端到端层（L3）：人工场景 S1→S15 关键路径（含 S15 新会话最终效果）
- 并发声明：全部场景单池（桌面交互天然串行），无并行池
- 副作用隔离：触真实 `~/.claude/settings.json` 的场景先备份至 /tmp、场景后恢复
- 环境注意：`CC_MODEL_CONFIG_DIR` 环境变量可覆盖应用配置目录（S6 隔离用）
