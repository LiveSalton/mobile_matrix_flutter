# STF WebView 手机控制

## ADDED Requirements

### Requirement: 嵌入 STF standalone 手机页面

Flutter 桌面控制台 SHALL 在设备控制区域提供原生 WebView，并加载当前设备对应的 STF standalone 路由 `#!/c/<serial>?standalone`。WebView SHALL 直接承载 Web 页面，不得在其上覆盖 Flutter 的 Listener、透明 TextField 或其他会拦截指针和键盘事件的层。

#### Scenario: 连接设备后显示 Web 手机

- **WHEN** Flutter 已发现一个可用 Android 真机且 STF HTTP 服务可用
- **THEN** 控制台 SHALL 在 WebView 中加载该设备的 standalone 页面，并显示 Web 端手机画面

#### Scenario: 切换设备

- **WHEN** 用户从 Flutter 顶部设备选择器切换到另一台可用真机
- **THEN** WebView SHALL 停止旧设备控制页面并加载新设备序列号对应的 standalone 路由，不得继续向旧设备发送操作

### Requirement: Web 原生输入与实时触控

WebView SHALL 让 STF Web 页面独占手机舞台的鼠标、触控板、键盘、输入法和剪贴板事件。Flutter SHALL NOT 在该舞台重新实现触摸协议或拦截 WebView 的 `mousedown`、`mousemove`、`mouseup`、输入法提交和粘贴事件。

#### Scenario: 手机画布实时拖动

- **WHEN** 用户在 WebView 中按住手机画面并拖动
- **THEN** STF Web 页面 SHALL 逐个接收移动事件并通过其原有 Socket.IO 触控链路发送到设备，手机画面 SHALL 在抬手前实时跟手

#### Scenario: 点击手机输入框后输入中文

- **WHEN** 用户点击 WebView 内手机 App 的输入框并使用电脑中文输入法完成候选词
- **THEN** Web 页面 SHALL 使用原有隐藏输入端接收组合文本并将最终文本发送到手机，Flutter SHALL NOT 显示额外输入框

#### Scenario: 电脑剪贴板粘贴

- **WHEN** 用户在 WebView 手机画面建立焦点后按下 Cmd+V 或 Ctrl+V
- **THEN** Web 页面 SHALL 按 STF 原有粘贴行为把桌面纯文本一次性发送到手机焦点输入框

### Requirement: 会话与服务状态

WebView SHALL 使用本机 STF HTTP 服务建立页面会话，并保留 WebView Cookie 以支持后续 Socket.IO 和屏幕 WebSocket 连接。Flutter SHALL 在加载前检查 STF 服务可达性，并对加载失败、设备离线和 WebSocket 断开提供可重试状态。

#### Scenario: STF 服务不可用

- **WHEN** `127.0.0.1:7100` 无法访问
- **THEN** Flutter SHALL 显示 STF 服务不可用和重试入口，不显示空白 WebView，也不得向用户伪造连接成功

#### Scenario: Web 页面加载失败

- **WHEN** WebView 导航、JavaScript 或 Socket.IO 连接失败
- **THEN** Flutter SHALL 记录可诊断日志并显示可重试状态，重试 SHALL 复用当前设备序列号和现有 Cookie

### Requirement: 回退与互斥控制面

WebView 舞台与原生 Flutter 舞台 SHALL 互斥启用，同一设备同一时刻只能存在一个可发送触控事件的控制面。第一阶段 SHALL 保留 native 控制面作为显式回退，不得让两个控制面同时发送屏幕操作。

#### Scenario: WebView 未就绪时回退

- **WHEN** WebView 在限定重试次数后仍未就绪且用户选择回退
- **THEN** 控制台 SHALL 停止 WebView 的设备操作并显示原生 Flutter 舞台，原有回退链路 SHALL 继续可用
