# 设计：桌面控制台真机交互直通

## 责任边界

Flutter 桌面端负责焦点、桌面 IME、电脑剪贴板和指针手势；`IDeviceControlService` 负责把已确认的用户操作转换为设备控制命令；文本和物理按键继续通过 ADB，触控则复用 Web STF 的 Socket.IO 设备通道；现有屏幕流服务负责刷新画面。设备状态和屏幕帧的事实来源保持不变。

## 文本与剪贴板通道

所有已提交文本统一经过以下顺序：

1. 将文本按 UTF-8 编码为 STF `SetClipboardRequest` protobuf。
2. 通过 ADB 转发连接 `localabstract:stfservice`，发送 `SET_CLIPBOARD` 请求。
3. 校验 STF Service 返回的 `SetClipboardResponse.success`，再等待剪贴板状态稳定。
4. 发送 `input keyevent 279`（Android `KEYCODE_PASTE`）。

ADB 交互会话使用单一 Future 队列，保证同一设备上的 STF 剪贴板请求、粘贴事件和按键保持提交顺序。隐藏输入代理只在 IME 组合区结束后提交文本，组合中的拼音保留在代理控制器内，不提前注入半成品。

Cmd/Ctrl+V 在输入代理焦点上被拦截，只读取电脑剪贴板并走上述复合通道，避免桌面文本先插入代理造成重复粘贴。回车提交当前已完成文本；代理为空时仍向手机发送回车。退格、方向键等在代理为空时发送到手机，在代理有本地组合内容时交给桌面输入控件处理。

## 触摸与滑动

触控完全复用 Web STF 的传输与事件顺序：Flutter 先从 STF trusted-local 会话取得 Cookie，从 `/app/api/v1/state.js` 解析 Socket.IO 地址，再从 `/api/v1/devices` 解析当前序列号的动态设备 channel。每条输入消息使用与 Web 相同的 `0..99` 循环序号，因为 STF 服务端的 `SeqQueue(100)` 会拒绝更大的序号。按下发送 `input.gestureStart`、`input.touchDown`、`input.touchCommit`；每次移动立即发送 `input.touchMove`、`input.touchCommit`；抬手或取消发送 `input.touchUp`、`input.touchCommit`、`input.gestureStop`。STF 服务端沿既有 protobuf 设备通道把事件交给 minitouch，因此手机在每个 MOVE 到达时就开始移动，不等待抬手，也不再通过 ADB 合成 `input swipe` 或 `input motionevent`。连接尚未建立时首个完整手势按原顺序暂存，连接成功后立即发送；断线后按 STF 的 Socket.IO 重连策略恢复。对齐 Web STF，设备画面不把鼠标滚轮或 macOS 触控板双指滚动映射为设备手势。

## 隐藏输入代理

对照 Web STF，真机舞台不渲染任何可见输入栏。Flutter 在手机画面的 `Stack` 内保留一个覆盖手机画面、全透明且从语义树排除的 `TextField`，仅作为桌面 IME 的输入连接，不显示提示、边框、图标或光标。触摸监听器位于它的父层，透明代理通过 `IgnorePointer` 退出命中测试，避免获得焦点时重定向或取消正在进行的拖动；点击、长按和滑动仍完整转发到手机。

该代理关闭 `autofocus`。只有指针按下位置位于真实手机画面矩形内时，画布才请求代理焦点并继续下发设备触摸；点击画面之外不会抢占桌面键盘。IME 组合文本留在透明代理中，候选确认后立即清空并通过文本复合通道发送到手机。透明代理的文本光标垂直锚定在手机画面底部，使 macOS 输入法候选窗出现在舞台下方区域，避免遮挡手机顶部输入框。

## 错误与降级

- ADB 启动失败时，文本和按键命令队列逐条回退到独立 `adb shell` 执行，并输出调试日志，不向 UI 抛出未处理异常。
- STF 触控连接建立前暂存首个完整手势；连接或设备 channel 解析失败时保留后续重试能力，不使用语义不同的 ADB 滑动伪装成功。
- 文本为空时不发送 STF Service 请求或粘贴事件。
- 设备离线或命令失败时，当前操作结束，后续队列仍可继续尝试；屏幕刷新只在控制命令完成后触发。
- 本次不把本地 mock 的成功日志当作真实设备验收证据。
