# 设备输入与触控控制

## ADDED Requirements

### Requirement: 跨输入法文本注入

桌面控制台 SHALL 将已提交文本通过设备剪贴板写入后再触发 Android 原生粘贴，不得依赖当前激活输入法连接来执行 `ACTION_SET_TEXT`。

#### Scenario: 第三方输入法下输入中文

- **WHEN** Android 真机当前使用搜狗或百度输入法，手机输入框拥有光标，用户在控制台输入并完成中文候选词
- **THEN** 控制台 SHALL 按 STF Service 剪贴板请求、成功响应、短延时、`KEYCODE_PASTE` 的顺序把最终中文文本注入光标位置

#### Scenario: 普通按键交给手机输入法

- **WHEN** 用户点击手机画面中的输入框后，在电脑按下字母、数字、标点或退格等按键
- **THEN** 控制台 SHALL 只转发 Web STF 式原始 keyDown/keyUp，设备 SHALL NOT 收到桌面 TextInput/IME 产生的拼音半成品

### Requirement: Web STF 式无界面键盘直通

桌面控制台 SHALL 使用不可见且不占布局的原始键盘焦点接收器接收桌面 keyDown/keyUp，不得创建桌面 TextInput/IME 连接，不得在真机舞台上显示同步输入栏、提示图标、边框或占位区域。键盘接收器 SHALL 默认不自动聚焦。

#### Scenario: 点击手机输入框后直接打字

- **WHEN** 用户在真机画面矩形内点击手机 App 的输入框，随后使用电脑键盘输入并完成输入法候选
- **THEN** 控制台 SHALL 聚焦原始键盘接收器，将 keyDown/keyUp 按 Android KeyCode 转发到手机当前输入法，并保持手机画面为唯一可见输入界面

#### Scenario: 手机输入法负责中英文切换

- **WHEN** 用户在手机画面中点击输入框，再按下电脑键盘字符或手机输入法切换键
- **THEN** 控制台 SHALL 转发原始按键及 `KEYCODE_SWITCH_CHARSET`，不得启动电脑输入法候选；中文、英文和候选词 SHALL 由手机当前输入法处理

#### Scenario: 尚未点击手机画面

- **WHEN** 真机舞台刚显示但用户尚未在手机画面矩形内按下指针
- **THEN** 原始键盘接收器 SHALL NOT 自动抢占桌面键盘焦点，控制台 SHALL NOT 显示任何输入 UI

#### Scenario: 电脑输入法不显示候选窗

- **WHEN** 用户点击手机画面中的输入框并开始输入
- **THEN** 控制台 SHALL 不建立桌面 TextInput/IME 连接，电脑输入法候选窗 SHALL NOT 出现

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

#### Scenario: 切换设备或 STF 屏幕进程重启后恢复画面

- **WHEN** 当前设备切换，或 STF 为当前设备重启了屏幕子进程导致原屏幕 WebSocket 断开
- **THEN** 屏幕流 SHALL 释放旧 WebSocket，按当前设备序列号重新解析最新 `--screen-port` 并自动重连；不得持续使用旧端口并长期显示“未找到当前设备的 STF 屏幕服务”

### Requirement: 设备截图复制到电脑剪贴板

控制台 SHALL 提供截取屏幕操作，将当前设备的 PNG 截图直接写入电脑系统剪贴板，不得为截图创建桌面文件，也不得启动视频录制流程。

#### Scenario: 设备在线时复制截图

- **WHEN** 用户点击“截取屏幕”按钮且当前设备在线
- **THEN** 控制台 SHALL 通过 ADB 获取当前设备截图，并将图片内容以 PNG 格式复制到电脑剪贴板；操作成功后 SHALL 给出成功提示

#### Scenario: 截图失败或系统不支持图片剪贴板

- **WHEN** 设备离线、截图命令失败或系统不支持图片剪贴板
- **THEN** 控制台 SHALL 不创建本地截图文件，并给出可读的失败提示

### Requirement: 桌面工作区最小尺寸

桌面端 SHALL 为 macOS、Windows 和 Linux 设置不小于 `1120×760` 的窗口尺寸，保证顶部导航、左侧设备舞台和右侧设备工具箱在可用区域内布局；右侧工具内容 SHALL 保持纵向可滚动，不得因窗口高度不足产生布局越界。

#### Scenario: 用户拖动窗口边缘缩小

- **WHEN** 用户拖动桌面窗口边缘继续缩小
- **THEN** 窗口 SHALL 在 `1120×760` 处停止缩小，界面 SHALL 保持双栏布局、按钮可见且无 RenderFlex 越界
