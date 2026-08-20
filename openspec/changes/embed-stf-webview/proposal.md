## Why

Flutter 自己重现 STF Web 的屏幕流、隐藏输入、鼠标事件和 Socket.IO 触控链路仍然存在平台视图与事件转发差异，真机体验无法稳定达到 Web 端。STF Web 页面已经在浏览器中验证了输入和实时拖动，因此桌面 Flutter 应直接承载该页面，让 Web 原生代码继续拥有手机交互。

## What Changes

- 在 Flutter macOS 控制台中嵌入原生 WebView，加载 STF 的 standalone 设备控制路由。
- 将手机屏幕的点击、拖动、滚轮、键盘、输入法和剪贴板事件完全交给 WebView 内的 STF Web 页面处理。
- Flutter 保留设备发现、设备切换、顶部导航、右侧业务工作区和 STF 服务不可用提示。
- WebView 按当前设备序列号切换 `#!/c/<serial>?standalone` 路由，并复用 STF Web 的 Cookie、Socket.IO 和屏幕 WebSocket。
- 第一阶段保留原 Flutter 屏幕舞台作为可回退路径；WebView 真机验收通过后再移除重复的 Dart 触控/屏幕流实现。

## Capabilities

### New Capabilities

- `stf-webview-control`: 在 Flutter 桌面端承载 STF Web standalone 手机控制页面。

### Modified Capabilities

- 无。原有输入控制变更保留为历史回退实现，本变更新增 WebView 控制表面。

## Impact

- Flutter：新增 WebView 依赖、WebView 舞台和 STF Web 会话状态管理；控制页改为可切换 Web/native 舞台。
- macOS：使用系统 WKWebView；当前工程已有网络客户端 entitlement，无需新增权限。
- STF：不修改 STF Web 源码、Socket.IO 协议或设备服务，只加载现有本地 Web 服务。
- 验收：需要本机 STF HTTP 服务可用，并在荣耀 Magic 6 Pro 真机上验证输入、粘贴和实时拖动。
