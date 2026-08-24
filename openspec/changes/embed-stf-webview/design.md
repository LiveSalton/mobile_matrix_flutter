# 设计：Flutter 承载 STF Web 手机控制

## 责任边界

Flutter 负责设备发现、顺序列表、页面布局、每个设备的 STF 服务健康状态和 WebView 生命周期。每个 WKWebView 负责对应 STF Web 的 DOM、隐藏输入端、鼠标/触控板事件、浏览器输入法、剪贴板、Socket.IO 和屏幕 WebSocket。STF 服务端和 vendor Web 源码不改动。

## 页面与路由

当前设备为 `serial` 时，WebView 加载：

```text
http://127.0.0.1:7100/#!/c/<serial>?standalone
```

STF 的 standalone 模板只包含 `device-screen`，每个设备卡片只承载一个对应 WebView。Flutter 不再渲染右侧 `DeviceWorkspace`，WebView 舞台本身不再叠加 Flutter `Listener`、`TextField`、触控反馈或渲染器。

设备卡片按照 `AdbService.getConnectedDevices()` 返回顺序构建，使用设备序列号作为稳定 Key。设备新增、断开或顺序变化时，已有设备的 WebView 不复用到其他序列号；每台设备拥有独立的 `StfWebSessionService`，避免一个页面的加载错误覆盖其他设备。

## WebView 会话

新增会话服务负责：

1. 检查 `http://127.0.0.1:7100/app/api/v1/state.js` 是否可访问。
2. 根据当前序列号构造 standalone URL。
3. 在 WebView 页面完成、导航失败、JavaScript 错误和重试时输出结构化日志。
4. 设备切换时加载新路由，不清空已有 WebView Cookie；trusted-local 会话由 WebView 自己接收和维护。
5. 仅允许 `127.0.0.1:7100` 以及 STF 配置返回的本地 Socket.IO/屏幕流地址，外部导航不离开 Flutter 控制台。

第一阶段不从 Dart 注入 Cookie，也不把 Web 源码复制到 Flutter assets；让 WKWebView 按浏览器方式完成页面会话，避免破坏 STF 的 Angular、Hash 路由和静态资源相对路径。

## 控制面互斥

设备墙默认只启用 Web 控制面；同一张设备卡片不叠加原生 Flutter 触控层、输入层或屏幕渲染器，避免两个触控入口同时存在。WebView 加载失败时提供本卡片重试入口；旧 Dart native 舞台继续保留在代码库中，暂不作为多设备墙的默认渲染路径。

## 键盘与剪贴板

WebView 获得焦点后不由 Flutter 外层 `Focus` 抢占按键。Cmd/Ctrl+V、中文输入法组合串、回车和退格全部留给 STF Web 页面处理；Flutter 不再提供右侧工具箱向手机画面转发重复输入。

## 错误与可观测性

- STF HTTP 不可达：显示服务启动/重试状态。
- WebView 导航失败：记录 URL、错误码和设备序列号。
- Web 页面无首帧或 Socket.IO 未连接：显示 Web 控制面未就绪，保留重试和 native 回退。
- 设备切换或页面销毁：停止旧 WebView 加载，避免旧页面继续发送设备操作。

## 回滚

默认 Web 模式出现问题时，通过 `ControlSurfaceMode.native` 恢复原有 Flutter 舞台。WebView 验收完成后再单独清理 `StfTouchService`、原生触控代理和重复屏幕流代码，避免本次变更同时扩大删除范围。
