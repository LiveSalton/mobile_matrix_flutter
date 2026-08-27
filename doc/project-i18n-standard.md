# 国际化规范

## 当前范围

- 支持简体中文 `zh` 与英文 `en`。
- 源文件为 `lib/l10n/intl_zh.arb`、`lib/l10n/intl_en.arb`。
- `lib/l10n/l10n.dart` 与 `lib/l10n/intl/` 由 `intl_utils` 生成。

## 字符串规则

- 用户可见且与语言相关的文本必须进入 ARB。
- 品牌名、协议标识、接口字段、URL、文件名和日志技术字段不翻译。
- key 使用 `lower_snake_case`，每个 key 必须提供 description。
- 两种语言的 key、占位符及类型必须一致。
- 单条文案应简洁且不超过 200 字符。
- 新增前先检查是否存在可复用语义，避免同义重复。

## 变更流程

1. 人工修改中英文 ARB。
2. 执行 `flutter pub run intl_utils:generate`。
3. 代码通过 `L10n.of(context)` 读取文案。
4. 静态审计 key、占位符、长度和硬编码文案。

当前基础仅保留 `app_name`、`project_shell_title`、`project_shell_body` 三个 key。
