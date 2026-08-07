# Mobile Matrix Design System Master

> 运行规则：先读取主题变量，再实现组件。`pages/` 下文件如果存在，优先级高于本文件。

## 适用范围

- 主题语义、字重和间距采用本文档定义，未说明部分从项目约定提取，不允许直接散落硬编码色值。
- 主题切换仅允许两个值：`default` 与 `roseGlow`。

## 主题语义色（仅定义语义）

说明：以下语义色中，`danger` / `warning` / `success` / `disabled` 为全局共享，不受主题切换影响。

### 默认（`default`）

| Token | Hex |
| --- | --- |
| `--mm-bg` | `#0B1014` |
| `--mm-bg-secondary` | `#212329` |
| `--mm-surface` | `#10182780` |
| `--mm-surface-elevated` | `#101827A0` |
| `--mm-outline` | `#1286D94D` |
| `--mm-primary` | `#1286D9` |
| `--mm-accent` | `#1286D9` |
| `--mm-highlight` | `#B8DFFF33` |
| `--mm-metal-edge` | `#1286D966` |
| `--mm-text-primary` | `#FFFFFF` |
| `--mm-text-secondary` | `#B4B8C5` |
| `--mm-danger` | `#EF4444` |
| `--mm-warning` | `#FF9124` |
| `--mm-success` | `#00D591` |
| `--mm-disabled` | `#64748B` |

### 玫瑰流光（`roseGlow`）

| Token | Hex |
| --- | --- |
| `--mm-bg` | `#140F16` |
| `--mm-bg-secondary` | `#2A2029` |
| `--mm-surface` | `#1E142280` |
| `--mm-surface-elevated` | `#28192DA0` |
| `--mm-outline` | `#59E56A9A` |
| `--mm-primary` | `#E56A9A` |
| `--mm-accent` | `#E56A9A` |
| `--mm-highlight` | `#33FFD5E4` |
| `--mm-metal-edge` | `#E56A9A66` |
| `--mm-text-primary` | `#FFF8FB` |
| `--mm-text-secondary` | `#D1BEC9` |
| `--mm-danger` | `#EF4444` |
| `--mm-warning` | `#FF9124` |
| `--mm-success` | `#00D591` |
| `--mm-disabled` | `#64748B` |

## 文案与字体

- 字体：`Inter` 体系（标题 + 正文）。
- 字重与字号采用语义分层，不允许页面级随意定义。

## 间距与圆角

- 基础间距：`4 / 8 / 16 / 24 / 32 / 48`。
- 圆角：`8 / 12 / 16 / 28` 规范化使用。

## 交互约束

- 点击反馈：200ms 以内。
- 禁止表情符号作为功能图标。
- 禁止只靠颜色表达状态，不允许无文本提示。
