# CC Model

macOS 菜单栏应用：一键切换 Claude Code 的 API 供应商（智谱 / DeepSeek / 任意 Anthropic 兼容接入点）。常驻菜单栏，点一下即完成切换，不影响已运行的会话。

## 功能

- **菜单栏状态项**：`⇄ 当前模型名`，不点菜单也能一眼看到在用哪家
- **一键切换**：重写 `~/.claude/settings.json` 的模型相关键（`ANTHROPIC_*`），插件等其他配置**原样保留**
- **模型管理**：偏好设置窗口增删改模型；「设为默认」标记主力模型
- **首跑引导**：首次启动自动识别你现有的 `settings.json` 配置并预填，不用手抄
- **自定义配置识别**：手动改过配置文件？应用会弹窗让你「纳入管理」或「覆盖已有模型」
- **开机自启**（可选）：登录后状态项自动出现
- **通知回执**：切换成功/失败都有系统通知

## 环境要求

- macOS 13 及以上（Apple Silicon）
- Xcode Command Line Tools（`xcode-select --install` 可装）——**无需完整 Xcode**
- Swift 5.9+ 工具链（随 CLT 提供）

## 编译运行（开发模式）

```bash
git clone <本仓库> && cd cc-model
swift build          # 编译
swift run            # 运行：菜单栏出现 ⇄ 图标
swift test           # 139 条单元测试
```

> **已知构建怪癖**：冷启动时可能遇到宏插件报错（`TestingMacros` / `SwiftUIMacros` 相关，CLT 工具链问题）。处置：重跑一次；仍失败则 `swift package reset && swift test`（或 `swift build`）。

## 编译安装到系统

```bash
bash scripts/make-app.sh
```

脚本做五件事：删旧 dist → release 构建 → 生成 Info.plist → 拷贝可执行 → ad-hoc 签名，产出 **`dist/CC Model.app`**（任一步失败即非零退出，不会产出半成品）。

**安装步骤：**

1. 运行上面的脚本
2. 把 `dist/CC Model.app` 拖入 **/Applications**（Finder 拖拽或 `mv`）——登录项（开机自启）在标准位置注册最稳定
3. 双击打开（本地构建无 quarantine 属性，Gatekeeper 不会拦；若从其他途径传输，先 `xattr -d com.apple.quarantine "CC Model.app"`）
4. 菜单栏出现 `⇄ 图标` 即安装完成

> ad-hoc 签名仅本机有效——这个 app 不适合分发给别人（那是新需求，需另行设计签名与公证）。

## 使用

| 想做什么 | 怎么做 |
|----------|--------|
| 切换模型 | 点菜单栏 `⇄ 模型名` → 菜单里点目标模型 → 收到通知「已切换到 X，对新建会话生效」 |
| 添加模型 | 菜单 → 偏好设置… → 侧栏底部 **＋** → 填表单（显示名/接入点/Token/主模型/四档映射）→ 保存 |
| 删除模型 | 偏好设置… → 选中模型 → **－**（只剩一个时置灰不可删；删默认则首个自动补位） |
| 设默认模型 | 表单里勾选「设为默认」→ 保存（菜单里该模型名后会带「（默认）」标注） |
| 开机自启 | 偏好设置… → 侧栏底部「开机自启」开关 |
| 退出 | 菜单 → 退出 CC Model |

**关键行为须知：**

- 切换只对**新建**的 Claude Code 会话生效，已运行的会话保持原供应商
- 手动改过 `settings.json`？下次开菜单应用会识别为「自定义配置」，弹窗三选：**纳入为新模型** / **覆盖已有模型**（让已有记录跟上你的手改）/ 取消
- 配置损坏（JSON 写坏）？启动时弹窗给出路径与解决建议，绝不静默重置
- Token 以明文存放在两处（应用配置 `~/Library/Application Support/cc-model/config.json` 与 `~/.claude/settings.json`，均 0600 权限）——这是单机个人工具的设计取舍，勿在多人共用机器上使用

## 卸载

1. 偏好设置… → 关闭「开机自启」
2. 菜单 → 退出 CC Model
3. 从 /Applications 删除 CC Model.app
4. （可选，彻底清理）删除配置目录 `~/Library/Application Support/cc-model/`；`~/.claude/settings.json` 保留当前值即可继续用 Claude Code

## 开发者

- 单元测试：`swift test`（139 条）
- 设计/计划/验证方案：`docs/superpowers/archived/2026-11-04-cc-model/`
- 验证场景登记册（15 条回归场景）：`docs/superpowers/verification/`
- 打包：`scripts/make-app.sh`（五步构建 + 失败非零退出 + 产物自检）
