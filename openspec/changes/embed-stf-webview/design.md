# 设计：Flutter 承载 STF Web 手机控制

## 责任边界

Flutter 负责设备选择、页面布局、STF 服务健康状态、WebView 生命周期和回退入口。WKWebView 负责 STF Web 的 DOM、隐藏输入端、鼠标/触控板事件、浏览器输入法、剪贴板、Socket.IO 和屏幕 WebSocket。STF 服务端和 vendor Web 源码不改动。

## 页面与路由

当前设备为 `serial` 时，WebView 加载：

```text
http://127.0.0.1:7100/#!/c/<serial>?standalone
```

STF 的 standalone 模板只包含 `device-screen`，适合放在 Flutter 左侧手机舞台。Flutter 右侧 `DeviceWorkspace` 继续保留业务工具；WebView 舞台本身不再叠加 Flutter `Listener`、`TextField`、触控反馈或渲染器。

## WebView 会话

新增会话服务负责：

1. 检查 `http://127.0.0.1:7100/app/api/v1/state.js` 是否可访问。
2. 根据当前序列号构造 standalone URL。
3. 在 WebView 页面完成、导航失败、JavaScript 错误和重试时输出结构化日志。
4. 设备切换时加载新路由，不清空已有 WebView Cookie；trusted-local 会话由 WebView 自己接收和维护。
5. 仅允许 `127.0.0.1:7100` 以及 STF 配置返回的本地 Socket.IO/屏幕流地址，外部导航不离开 Flutter 控制台。

第一阶段不从 Dart 注入 Cookie，也不把 Web 源码复制到 Flutter assets；让 WKWebView 按浏览器方式完成页面会话，避免破坏 STF 的 Angular、Hash 路由和静态资源相对路径。

## 控制面互斥

`DeviceControlPage` 增加 `ControlSurfaceMode`：

- `web`: 左侧使用 `StfWebViewStage`，右侧工具继续使用 Flutter 服务。
- `native`: 使用已有 `DeviceScreenStage`，用于 WebView 失败时回退。

模式切换时，先停止旧控制面，再创建新控制面。Web 模式下不启动或不展示原生手机画面，避免两个屏幕 WebSocket 和两个触控入口同时存在；回退到 native 时才恢复旧屏幕流和 Flutter 触控服务。

## 键盘与剪贴板

WebView 获得焦点后不由 Flutter 外层 `Focus` 抢占按键。Cmd/Ctrl+V、中文输入法组合串、回车和退格全部留给 STF Web 页面处理。Flutter 右侧工具仍可使用现有 ADB 文本/按键服务，但不向 WebView 手机画面转发重复输入。

## 错误与可观测性

- STF HTTP 不可达：显示服务启动/重试状态。
- WebView 导航失败：记录 URL、错误码和设备序列号。
- Web 页面无首帧或 Socket.IO 未连接：显示 Web 控制面未就绪，保留重试和 native 回退。
- 设备切换或页面销毁：停止旧 WebView 加载，避免旧页面继续发送设备操作。

## 回滚

默认 Web 模式出现问题时，通过 `ControlSurfaceMode.native` 恢复原有 Flutter 舞台。WebView 验收完成后再单独清理 `StfTouchService`、原生触控代理和重复屏幕流代码，避免本次变更同时扩大删除范围。
