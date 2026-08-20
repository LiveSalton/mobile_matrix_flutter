# 设备输入与触控控制

## ADDED Requirements

### Requirement: 跨输入法文本注入

桌面控制台 SHALL 将已提交文本通过设备剪贴板写入后再触发 Android 原生粘贴，不得依赖当前激活输入法连接来执行 `ACTION_SET_TEXT`。

#### Scenario: 第三方输入法下输入中文

- **WHEN** Android 真机当前使用搜狗或百度输入法，手机输入框拥有光标，用户在控制台输入并完成中文候选词
- **THEN** 控制台 SHALL 按 STF Service 剪贴板请求、成功响应、短延时、`KEYCODE_PASTE` 的顺序把最终中文文本注入光标位置

#### Scenario: 隐藏代理保留拼音组合串

- **WHEN** 用户点击手机画面中的输入框后，在电脑输入尚未选词的拼音组合串
- **THEN** 隐藏输入代理 SHALL 保留组合文本，设备 SHALL NOT 收到未完成的拼音半成品；控制台 SHALL NOT 显示额外输入栏

### Requirement: Web STF 式无界面键盘直通

桌面控制台 SHALL 使用不可见且不占布局的输入代理接收桌面键盘与输入法事件，不得在真机舞台上显示同步输入栏、提示图标、边框或占位区域。输入代理 SHALL 默认不自动聚焦。

#### Scenario: 点击手机输入框后直接打字

- **WHEN** 用户在真机画面矩形内点击手机 App 的输入框，随后使用电脑键盘输入并完成输入法候选
- **THEN** 控制台 SHALL 聚焦隐藏输入代理，将最终文本注入手机当前光标位置，并保持手机画面为唯一可见输入界面

#### Scenario: 尚未点击手机画面

- **WHEN** 真机舞台刚显示但用户尚未在手机画面矩形内按下指针
- **THEN** 隐藏输入代理 SHALL NOT 自动抢占桌面键盘焦点，控制台 SHALL NOT 显示任何输入 UI

#### Scenario: 桌面输入法显示候选窗

- **WHEN** 用户点击手机画面中的输入框并使用 macOS 输入法输入组合文本
- **THEN** 隐藏输入代理 SHALL 将桌面输入法候选窗锚定在手机画面底部，避免遮挡手机输入框与手机输入法候选区域

### Requirement: 电脑剪贴板粘贴

桌面控制台 SHALL 支持 macOS Cmd+V 与 Windows/Linux Ctrl+V，将电脑纯文本剪贴板内容一次性粘贴到手机当前焦点输入框。

#### Scenario: 粘贴长文本和 Emoji

- **WHEN** 用户已通过手机画面点击建立桌面输入焦点，电脑剪贴板包含中文、标点、换行或 Emoji，且手机输入框有焦点
- **THEN** 控制台 SHALL 保持文本内容并只触发一次设备粘贴，不因 ADB 会话尚未完成启动而丢弃命令

#### Scenario: 电脑剪贴板为空

- **WHEN** 用户触发 Cmd/Ctrl+V 且电脑剪贴板没有纯文本
- **THEN** 控制台 SHALL 不向手机发送空粘贴，并保持当前输入焦点

### Requirement: 可靠触控和滑动

控制台 SHALL 将画布的归一化坐标映射为 Web STF 触控协议坐标，并通过当前设备的 Socket.IO channel 按原始事件顺序转发。一次手势 SHALL 使用 Web STF 相同的 `0..99` 循环序号，依次包含 `gestureStart`、带 `touchCommit` 的 DOWN/MOVE/UP 和 `gestureStop`，不得通过 ADB 等到抬手后再合成一次完整滑动。文本与物理按键仍 SHALL 保持现有 ADB 队列顺序。

#### Scenario: 真机拖动实时跟手

- **WHEN** 用户在手机画布内按下、移动超过触控阈值后抬手
- **THEN** 控制台 SHALL 在按下时发送 `gestureStart`、DOWN 和 commit，在每次移动时发送 MOVE 和 commit，在抬手时发送 UP、commit 和 `gestureStop`；手机画面 SHALL 在拖动过程中跟随指针，不得等待抬手后再执行一次合成滑动

#### Scenario: 桌面滚轮或触控板滚动

- **WHEN** 用户将指针停在手机画布内并滚动鼠标滚轮或使用 macOS 触控板双指滚动
- **THEN** 控制台 SHALL 与 Web STF 一致，不把滚轮信号转换为设备触摸或滑动命令

#### Scenario: 短点击和长按

- **WHEN** 用户在触控阈值内抬手，或按住超过长按时长
- **THEN** 控制台 SHALL 让 STF/minitouch 收到的真实 DOWN/UP 序列分别产生点击或长按，不得在抬手时改写为延迟滑动

### Requirement: 实时刷新与错误降级

控制台 SHALL 在文本、按键和触控控制命令完成后请求即时刷新；单条 ADB 命令失败不得破坏后续文本/按键队列，STF 触控断线不得破坏后续重连。

#### Scenario: ADB 交互 shell 启动较慢

- **WHEN** 用户在 ADB 交互 shell 或 STF Socket.IO 触控连接尚未完全建立时点击、输入或粘贴
- **THEN** 文本/按键 SHALL 等待 ADB 会话后按提交顺序执行，必要时逐条回退到独立 `adb shell`；触控 SHALL 暂存首个完整手势并在 STF 设备 channel 建立后按事件顺序发送，不得静默丢弃首个操作
