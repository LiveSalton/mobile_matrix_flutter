# STF Lite 数字按键映射

## MODIFIED Requirements

### Requirement: STF Lite 键盘事件协议完整兼容 Web STF

STF Lite SHALL 接受 Flutter 发送的规范化键盘事件，并将其转换为 Android KeyEvent。数字字符字符串 SHALL 按 Web STF canonical key 解析；显式 JSON 整数 SHALL 继续表示 Android 原始 KeyCode。两种输入形式 SHALL 不得混淆。

#### Scenario: 数字字符字符串映射

- **WHEN** sidecar 收到 JSON 字符串 `"0"` 到 `"9"`
- **THEN** sidecar SHALL 将其分别映射到 Android KeyCode `7` 到 `16`，其中 `"9"` SHALL 映射为 `KEYCODE_9=16`

#### Scenario: 显式整数 KeyCode 兼容

- **WHEN** sidecar 收到 JSON 数字 `9` 作为显式 Android KeyCode
- **THEN** sidecar SHALL 保持原始 KeyCode `9` 的协议语义，不将其改写为字符 `9`
