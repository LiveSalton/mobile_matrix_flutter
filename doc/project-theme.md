## 项目主题规范

### 唯一事实源

- 本项目主题规范的唯一事实源为 `doc/project-theme.md`，其可视化实现必须与本文件保持一致。
- `ui-ux-pro-max` 作为设计规则来源；但颜色语义与运行时主题切换以本文件定义的两套主题为准。
- 本项目 UI 采用语义化 token，不允许散落长期硬编码颜色与字体。
- 项目主题组织方式可参考 `AppUninstaller/doc/project-theme.md` 的“唯一事实源 + Token 语义映射”范式，但不得直接复用其具体色值。

### 设计风格基线（ui-ux-pro-max）

- 风格方向：Glassmorphism（轻量磨砂、层次清晰、对比可读）。
- 交互基线：轻量动效（150-300ms），禁用突兀、非业务必要动画。
- 可访问性基线：文本对比至少 4.5:1（正文），按钮/状态控件支持清晰焦点态。

### 两套主题（必须明确）

### 1) 默认液态玻璃蓝（`theme = default`）

| 语义 | 值 |
|---|---|
| 页面背景 `theme_bg` | `#0B1014` |
| 二级背景 `theme_bg_secondary` | `#212329` |
| 表面 `theme_surface` | `#10182780` |
| 浮层表面 `theme_surface_elevated` | `#101827A0` |
| 边框 `theme_outline` | `#1286D94D` |
| 主色 `theme_primary` | `#1286D9` |
| 高亮 `theme_highlight` | `#B8DFFF33` |
| 液态金属边缘 `theme_metal_edge` | `#1286D966` |
| 主文字 `theme_text_primary` | `#FFFFFF` |
| 次文字 `theme_text_secondary` | `#B4B8C5` |

### 2) 玫瑰流光（`theme = roseGlow`）

| 语义 | 值 |
|---|---|
| 页面背景 `theme_bg` | `#140F16` |
| 二级背景 `theme_bg_secondary` | `#2A2029` |
| 表面 `theme_surface` | `#1E142280` |
| 浮层表面 `theme_surface_elevated` | `#28192DA0` |
| 边框 `theme_outline` | `#59E56A9A` |
| 主色 `theme_primary` | `#E56A9A` |
| 高亮 `theme_highlight` | `#33FFD5E4` |
| 液态金属边缘 `theme_metal_edge` | `#E56A9A66` |
| 主文字 `theme_text_primary` | `#FFF8FB` |
| 次文字 `theme_text_secondary` | `#D1BEC9` |

### 主题约束

- 主题键只允许两种：`default`、`roseGlow`。
- 必须实现运行时安全回退：未知主题值统一回退到 `default`。
- 两套主题共享 `成功/警告/错误/禁用` 语义色值，不得随主题单独变体。
- 严禁再新增第三套主题或静态复制页面。

### 组件语义映射（必须）

以下语义 token 必须被统一使用，禁止直接写具体十六进制值：

| 语义 token | 使用场景 |
|---|---|
| `--mm-bg` | 页面根背景 |
| `--mm-bg-secondary` | 卡片/分区背景 |
| `--mm-surface` | 卡片、弹窗底面 |
| `--mm-surface-elevated` | 弹窗、抽屉、浮层 |
| `--mm-outline` | 边框/分割线 |
| `--mm-primary` | 主要按钮、链接、强强调 |
| `--mm-text-primary` | 标题、正文主色 |
| `--mm-text-secondary` | 辅助文案 |

### 字体与字重

- 字体首选 `Inter`，用于标题与正文。
- 必须定义 `h1/h2/paragraph/label/button` 五类语义字号与字重，不允许每处单独临时定制。
- 禁止引入非项目标准字体文件依赖，仅使用项目约定的字体来源。

### 间距与圆角

- 基础间距采用 4/8/16/24/32/48 的 4dp 递进系统。
- 圆角建议使用 `8dp/12dp/16dp` 三档，禁用无规律圆角。
- 禁止同一层级使用无序间距与无边界阴影。

### 交互与图标规则

- 禁止使用 emoji 作为功能图标，必须使用统一的图标套件。
- 必须保证所有点击目标触达最小可点击面积。
- 必须保留 1px 级别边界线与层次对比，不允许纯平铺无分层。
- 禁止新增仅依赖颜色表达状态（例如仅用红/绿表示错误/成功）。
