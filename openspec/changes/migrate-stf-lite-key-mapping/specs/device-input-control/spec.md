# 设备输入与触控控制

## MODIFIED Requirements

### Requirement: 跨输入法文本注入

桌面控制台 SHALL 将已提交文本通过设备剪贴板写入后再触发 Android 原生粘贴，不得依赖当前激活输入法连接来执行 `ACTION_SET_TEXT`。电脑物理键盘产生的按键 SHALL 通过与 Web STF 等价的 Android 按键事件通道发送；字符名称必须先转换为有效 Android KeyCode，不得把未转换的名称直接交给 ADB。

#### Scenario: 第三方输入法下输入中文

- **WHEN** Android 真机当前使用搜狗或百度输入法，手机输入框拥有光标，用户在控制台输入并完成中文候选词
- **THEN** 控制台 SHALL 按 STF Service 剪贴板请求、成功响应、短延时、`KEYCODE_PASTE` 的顺序把最终中文文本注入光标位置

#### Scenario: 普通按键交给手机输入法

- **WHEN** 用户点击手机画面中的输入框后，在电脑按下字母、数字、标点或退格等按键
- **THEN** 控制台 SHALL 将按键名称映射为 Android KeyCode，并按 Web STF 式原始 keyDown/keyUp 语义转发；设备 SHALL NOT 收到桌面 TextInput/IME 产生的拼音半成品

### Requirement: Web STF 式无界面键盘直通

桌面控制台 SHALL 使用不可见且不占布局的原始键盘焦点接收器接收桌面 keyDown/keyUp，不得创建桌面 TextInput/IME 连接，不得在真机舞台上显示同步输入栏、提示图标、边框或占位区域。键盘接收器 SHALL 默认不自动聚焦，并 SHALL 将 Web STF 支持的字符、数字、编辑键、方向键、小键盘键、功能键和左右修饰键转换为有效 Android KeyCode。

#### Scenario: 点击手机输入框后直接打字

- **WHEN** 用户在真机画面矩形内点击手机 App 的输入框，随后使用电脑键盘输入并完成输入法候选
- **THEN** 控制台 SHALL 聚焦原始键盘接收器，将每个按键的 keyDown/keyUp 按 Android KeyCode 转发到手机当前输入法，并保持手机画面为唯一可见输入界面

#### Scenario: 修饰键与组合键

- **WHEN** 用户按住 Shift、Control、Alt 或 Meta 后再按另一个电脑按键
- **THEN** 控制台 SHALL 保持修饰键的按下/释放顺序，并将左右修饰键状态或等价组合标记传递到设备端；不得把组合键拆成丢失修饰语义的单独字符

#### Scenario: 手机输入法负责中英文切换

- **WHEN** 用户在手机画面中点击输入框，再按下电脑键盘字符或手机输入法切换键
- **THEN** 控制台 SHALL 转发原始按键及 `KEYCODE_SWITCH_CHARSET`，不得启动电脑输入法候选；中文、英文和候选词 SHALL 由手机当前输入法处理

#### Scenario: 尚未点击手机画面

- **WHEN** 真机舞台刚显示但用户尚未在手机画面矩形内按下指针
- **THEN** 原始键盘接收器 SHALL NOT 自动抢占桌面键盘焦点，控制台 SHALL NOT 显示任何输入 UI

#### Scenario: 电脑输入法不显示候选窗

- **WHEN** 用户点击手机画面中的输入框并开始输入
- **THEN** 控制台 SHALL 不建立桌面 TextInput/IME 连接，电脑输入法候选窗 SHALL NOT 出现

### Requirement: 实时刷新与错误降级

控制台 SHALL 在文本、按键和触控控制命令完成后请求即时刷新；按键控制通道 SHALL 只有在设备端实际接受事件后才报告成功。单条设备命令失败不得破坏后续文本/按键队列，STF 触控断线不得破坏后续重连。

#### Scenario: 按键执行结果可追踪

- **WHEN** 控制台通过持久控制通道发送 keyDown、keyUp 或 keyPress
- **THEN** sidecar SHALL 返回带请求关联信息的实际执行结果；映射失败、设备端拒绝、通道断开或超时 SHALL 返回失败原因，Flutter SHALL 不把“WebSocket 已写入”当作设备执行成功

#### Scenario: ADB 交互 shell 启动较慢

- **WHEN** 用户在 ADB 交互 shell 或 STF Socket.IO 触控连接尚未完全建立时点击、输入或粘贴
- **THEN** 文本/按键 SHALL 等待设备控制会话后按提交顺序执行，必要时逐条回退到有明确语义的设备通道；触控 SHALL 暂存首个完整手势并在 STF 设备 channel 建立后按事件顺序发送，不得静默丢弃首个操作

#### Scenario: 切换设备或 STF 屏幕进程重启后恢复画面

- **WHEN** 当前设备切换，或 STF 为当前设备重启了屏幕子进程导致原屏幕 WebSocket 断开
- **THEN** 屏幕流 SHALL 释放旧 WebSocket，按当前设备序列号重新解析最新 `--screen-port` 并自动重连；不得持续使用旧端口并长期显示“未找到当前设备的 STF 屏幕服务”
