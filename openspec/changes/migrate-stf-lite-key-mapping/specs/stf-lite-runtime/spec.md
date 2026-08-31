# STF Lite 运行时

## ADDED Requirements

### Requirement: STF Lite 键盘事件协议完整兼容 Web STF

STF Lite SHALL 接受 Flutter 发送的规范化键盘事件，并将其转换为 Android KeyEvent。协议 SHALL 支持 `DOWN`、`UP`、`PRESS` 三种动作、Web STF 兼容的字符及特殊键名称、Android 数字键码和修饰键状态；未知键或非法动作 SHALL 被拒绝并返回结构化错误。

#### Scenario: 字符和数字映射

- **WHEN** sidecar 收到字母、数字、标点、编辑键、方向键或数字小键盘的规范化键名称
- **THEN** sidecar SHALL 使用与 Web STF 相同的 Android KeyCode 映射规则处理事件，并将 `0-9`、`A-Z` 范围映射到对应 Android 键码 `7-16`、`29-54`

#### Scenario: 特殊键和输入法切换

- **WHEN** sidecar 收到 `enter`、`del`、`space`、`tab`、方向键、左右修饰键、`switch_charset` 或兼容别名
- **THEN** sidecar SHALL 将其映射到对应 Android KeyCode；`switch_charset` SHALL 映射到 `KEYCODE_SWITCH_CHARSET`，别名 SHALL 不产生重复或歧义事件

#### Scenario: 按键动作语义

- **WHEN** sidecar 收到 `DOWN`、`UP` 或 `PRESS` 事件及可选修饰键状态
- **THEN** 设备端 SHALL 按指定动作和修饰键执行一次等价 Android KeyEvent；按住按键不得被强制改写为两个无关的 `PRESS`

#### Scenario: 未知按键被拒绝

- **WHEN** sidecar 收到未知名称、非法数字键码或不支持的动作
- **THEN** sidecar SHALL 不向设备发送输入命令，返回包含 serial、请求标识、输入类型和原因的失败结果，并记录脱敏诊断日志

#### Scenario: 持久通道真实回执

- **WHEN** Flutter 通过持久控制通道发送键盘事件
- **THEN** sidecar SHALL 在实际处理完成后返回与请求匹配的成功或失败回执；Flutter SHALL 能区分发送成功、设备执行成功、超时和设备拒绝

### Requirement: STF Lite 键盘输入与文本粘贴通道隔离

STF Lite SHALL 将原始物理按键和 Unicode 文本注入视为两条不同的设备能力：原始按键使用 KeyEvent 协议，中文、Emoji、换行及任意 Unicode 文本使用剪贴板写入后再触发原生粘贴。原始按键映射失败不得改变或污染剪贴板内容。

#### Scenario: 原始按键不走桌面文本注入

- **WHEN** Flutter 发送单个物理按键或按键组合
- **THEN** sidecar SHALL 只处理 KeyEvent，不调用 `ACTION_SET_TEXT`，不把桌面输入法产生的组合文本当作按键字符发送

#### Scenario: Unicode 文本走剪贴板复合通道

- **WHEN** Flutter 请求注入包含中文、Emoji、换行或标点的文本
- **THEN** sidecar SHALL 先确认设备剪贴板写入成功，再等待状态稳定并触发一次 Android 原生粘贴；任一步失败 SHALL 返回失败且不得假报成功
