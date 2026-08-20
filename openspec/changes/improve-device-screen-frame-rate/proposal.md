## Why

当前 Flutter 控制台没有复用 Web STF 的设备屏幕流，而是自行启动一套固定为设备 75% 分辨率的 minicap 流。现场同一设备上，Web 实际输出为 461×1008，Flutter 输出为 960×2100，Flutter 每帧需要解码约 4.34 倍像素，并且自启流程会与 STF 争抢同一个 minicap 运行时，造成低帧率、卡顿和不稳定。

## What Changes

- 将 STF `device.display.url` 对应的设备专属 WebSocket 作为实时画面的唯一事实来源，与 Web 控制台使用同一屏幕生产链路。
- 复刻 Web 的 `size <w>x<h>`、`on`、`off` 协议和可见性生命周期，并采用相同的像素密度上限与最小缩放规则计算请求尺寸。
- 移除 Flutter 生产路径中自启、清理和直连 minicap 的优先方案，避免杀死或竞争 STF 正在维护的屏幕进程。
- **BREAKING**：STF 屏幕 WebSocket 不可用时显示明确错误，不再静默切换到 ADB 截图或另一套实时流协议。
- 保留 Flutter 等价渲染：只解码最新 JPEG 帧，通过 `ui.Codec` / `ui.Image` / `CustomPaint` 绘制，及时释放图片资源并隔离每帧重绘。
- 增加接收、渲染、丢弃和解码耗时指标，用于与 Web 在相同输入尺寸下进行用户验收。
- 不引入 OpenGL、WebView、平台专属 JPEG 解码器或新外部依赖。

## Capabilities

### New Capabilities

- `device-screen-stream`: 定义 Flutter 控制台与 Web STF 一致的屏幕流来源、尺寸协商、启停生命周期、最新帧渲染和错误可见性。

### Modified Capabilities

无。

## Impact

- 屏幕流：`lib/services/screen_stream_service.dart`。
- 设备与屏幕流装配：`lib/views/control/device_control_page.dart`。
- 画面布局与可见性：`lib/views/control/widgets/device_screen_stage.dart`。
- JPEG 解码与绘制：`lib/views/control/widgets/fast_screen_renderer.dart`。
- 原有 `NativeMinicapStreamService` 和 ADB 截图流不再进入实时画面生产链路；本变更不扩大到设备输入、剪贴板、触控、发布配置或测试文件。
- 运行时依赖本机 STF 提供有效的设备屏幕 WebSocket；不增加 Dart package 或原生平台依赖。
