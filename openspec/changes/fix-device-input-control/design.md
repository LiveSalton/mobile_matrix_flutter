# 设计：桌面控制台真机交互直通

## 责任边界

Flutter 桌面端负责点击后的原始键盘焦点、电脑剪贴板和指针手势；`IDeviceControlService` 负责把已确认的用户操作转换为设备控制命令；普通物理按键和触控复用 Web STF 的 Socket.IO 设备通道，剪贴板粘贴继续通过 STF Service/ADB 复合通道；截图按钮由 `ScreenCaptureService` 通过 ADB 获取 PNG 并写入电脑图片剪贴板，不落盘、不录制；现有屏幕流服务负责刷新画面。设备状态和屏幕帧的事实来源保持不变。

桌面窗口在 macOS、Windows 和 Linux 统一设置 `1120×760` 最小尺寸；设备工具箱使用纵向滚动承载工具卡片，避免窗口高度变化时把内容压缩到固定行高之外。

## 文本与剪贴板通道

所有已提交文本统一经过以下顺序：

1. 将文本按 UTF-8 编码为 STF `SetClipboardRequest` protobuf。
2. 通过 ADB 转发连接 `localabstract:stfservice`，发送 `SET_CLIPBOARD` 请求。
3. 校验 STF Service 返回的 `SetClipboardResponse.success`，再等待剪贴板状态稳定。
4. 发送 `input keyevent 279`（Android `KEYCODE_PASTE`）。

ADB 交互会话使用单一 Future 队列，保证同一设备上的 STF 剪贴板请求和粘贴事件保持提交顺序。普通字符不建立桌面 TextInput/IME 连接，而是按 Web STF 的原始 keyDown/keyUp 事件发送给手机，由手机当前输入法负责中英文、拼音和候选词；仅 Cmd/Ctrl+V 进入剪贴板复合通道。

Cmd/Ctrl+V 在键盘桥焦点上被拦截，只读取电脑剪贴板并走上述复合通道，避免桌面文本先插入代理造成重复粘贴。回车、退格、方向键和标点等均以原始按键事件发送给手机；输入法切换键在释放时发送 `KEYCODE_SWITCH_CHARSET`，不在电脑端生成组合文本或候选窗。

## 触摸与滑动

触控完全复用 Web STF 的传输与事件顺序：Flutter 先从 STF trusted-local 会话取得 Cookie，从 `/app/api/v1/state.js` 解析 Socket.IO 地址，再从 `/api/v1/devices` 解析当前序列号的动态设备 channel。每条输入消息使用与 Web 相同的 `0..99` 循环序号，因为 STF 服务端的 `SeqQueue(100)` 会拒绝更大的序号。按下发送 `input.gestureStart`、`input.touchDown`、`input.touchCommit`；每次移动立即发送 `input.touchMove`、`input.touchCommit`；抬手或取消发送 `input.touchUp`、`input.touchCommit`、`input.gestureStop`。STF 服务端沿既有 protobuf 设备通道把事件交给 minitouch，因此手机在每个 MOVE 到达时就开始移动，不等待抬手，也不再通过 ADB 合成 `input swipe` 或 `input motionevent`。连接尚未建立时首个完整手势按原顺序暂存，连接成功后立即发送；断线后按 STF 的 Socket.IO 重连策略恢复。对齐 Web STF，设备画面不把鼠标滚轮或 macOS 触控板双指滚动映射为设备手势。

## 隐藏输入代理

对照 Web STF，真机舞台不渲染任何可见输入栏，也不创建 Flutter `TextField` 或桌面 TextInput/IME 连接。Flutter 在手机画面点击后只激活一个不参与命中测试的 `Focus` 键盘桥，接收原始 keyDown/keyUp；点击、长按和滑动仍完整转发到手机。Web STF 的输入法切换键映射为 Android `KEYCODE_SWITCH_CHARSET`，由手机输入法决定中英文。

该键盘桥关闭 `autofocus`。只有指针按下位置位于真实手机画面矩形内时，画布才请求键盘焦点并继续下发设备触摸；点击画面之外不会抢占桌面键盘，也不会显示电脑输入法候选窗。

## 错误与降级

- ADB 启动失败时，文本和按键命令队列逐条回退到独立 `adb shell` 执行，并输出调试日志，不向 UI 抛出未处理异常。
- STF 触控连接建立前暂存首个完整手势；连接或设备 channel 解析失败时保留后续重试能力，不使用语义不同的 ADB 滑动伪装成功。
- STF 屏幕 WebSocket 连接失败或被 STF 子进程重启后，屏幕流服务 SHALL 丢弃旧连接并按当前设备序列号重新解析 `--screen-port`，再建立新连接；不得永久重试已经失效的端口。
- 文本为空时不发送 STF Service 请求或粘贴事件。
- 设备离线或命令失败时，当前操作结束，后续队列仍可继续尝试；屏幕刷新只在控制命令完成后触发。
- 本次不把本地 mock 的成功日志当作真实设备验收证据。
