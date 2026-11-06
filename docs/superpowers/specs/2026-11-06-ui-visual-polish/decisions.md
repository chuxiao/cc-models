# decisions.md — UI 视觉优化（2026-11-06-ui-visual-polish）

追加式裁决日志。格式：日期 | 项目 | 主题 | 裁决 | 依据 | 影响。

---

2026-11-06 | CC Model | 菜单栏图标 | 裁决：D 方案——系统 SF Symbol `arrow.left.arrow.right`（直线双向箭头），单色模板图 + 侧随当前模型显示名，替换现文本「⇄ 」前缀 | 视觉稿点选（icon-swap）；原生自适应明暗菜单栏、永不违和 | StatusItemController 装配、archived design §F1（现 design §V1）
2026-11-06 | CC Model | 面板配色 | 裁决：B 方案「现代深邃」——三窗口固定深色外观：卡面 #1e1e24、侧栏 #24242c、描边 rgba(255,255,255,.1)、主按钮蓝紫渐变（#4f8dff→#7c5cff）、选中态 #3a3f4d、辅助文字 #8f8f9c | 视觉稿点选（color-dark）；「现在的有点土」 | 全部窗口视觉层、design §界面规格
2026-11-06 | CC Model | 窗口位置 | 裁决：全部窗口（偏好/首跑欢迎/首跑表单/导入弹窗）打开时居中于屏幕 | 需求方明确要求「面板打开应该在屏幕的正中央」 | 各窗口 show 路径
2026-11-06 | CC Model | 面板尺寸与密度 | 裁决：偏好窗口默认 720×480（最小 660×430，可调）；侧栏 200pt；表单留白 20pt、行距 14pt；档位映射改横排四列 | 需求方反馈「大小不合理、选项太挤」+ 高保真稿确认（均接受） | PreferencesWindow、ProfileFormView
2026-11-06 | CC Model | 顺带收敛 | 裁决：ProfileFormView 增加「隐藏设为默认行」参数，首跑窗隐藏该行——消解终审 deferred minor（T6 首跑默认 Toggle UI 承诺不一致） | 终审建议 + 本需求 UI 顺带 | ProfileFormView、FirstRunCoordinator
