## Context

参见 `proposal.md` 的问题背景。当前 Flutter 生产路径优先创建 `NativeMinicapStreamService`，固定请求设备真实尺寸的 75%，并在启动时清理设备上的 minicap；已有 STF WebSocket 服务和 `DeviceDisplayInfo.streamUrl` 没有成为实际首选路径。现场同一台 1280×2800 设备中，Web STF 的 banner 为 461×1008，而 Flutter 自启进程为 960×2100。

Web STF 的客户端在连接后发送 `size` 和 `on`，隐藏时发送 `off`。投影尺寸由画面逻辑边界乘以限制为 1.0～1.5 的像素密度得到，并以设备真实尺寸的 0.36 作为最小缩放边界。服务端在当前帧对 WebSocket 客户端发送完成后再读取下一帧。

当前变更必须保留用户尚未提交的输入、剪贴板和触控修改，不修改测试、发布配置或平台原生渲染后端。

## Goals / Non-Goals

**Goals:**

- 让 Flutter 与 Web 使用同一个 STF 屏幕生产者和相同的控制协议。
- 让请求像素量由实际显示区域决定，不再固定为设备尺寸的 75%。
- 保持最新画面优先，限制解码队列与资源寿命，并提供分段性能指标。
- STF 不可用时呈现可操作的错误状态，而不是用另一种协议掩盖失败。

**Non-Goals:**

- 不修改 STF 服务端、minicap 参数或设备输入协议。
- 不引入 OpenGL、WebView、Impeller 开关、平台专属 JPEG 解码或原生 Texture 路径。
- 不把本次性能变更扩展到 Gateway 重构、设备发现重构、iOS/WDA、测试文件或发布流程。

## Decisions

### 1. STF WebSocket 是唯一生产画面通道

`SmartScreenStreamService` 保留为当前页面装配入口，但只负责解析并绑定 STF WebSocket：优先使用 `DeviceDisplayInfo.streamUrl`；本机 STF 尚未把该字段注入 Flutter 设备模型时，复用现有端口解析能力定位同一个 STF 设备屏幕端口。解析或连接失败进入 `error`，不再创建 `NativeMinicapStreamService` 或 `AdbScreenStreamService`。

选择该方案是因为它与 Web 共用 STF 的生命周期、质量参数、帧生产和发送背压，同时避免两个客户端争抢 `localabstract:minicap`。备选方案“保留自启 minicap 作为透明回退”被否决，因为它会改变协议和性能语义，并可能破坏正在运行的 Web STF。

### 2. 完整复制 Web 的兴趣与尺寸协议

服务保存最近一次有效投影尺寸和期望可见状态。WebSocket 打开时若画面可见，严格按 `size` 后 `on` 的顺序发送；尺寸变化只在整数结果改变时发送 `size`；隐藏发送 `off`；重连后重新恢复尺寸与兴趣状态。

投影计算复制 Web 算法：

1. 横屏时交换逻辑画面边界宽高。
2. `density = clamp(devicePixelRatio, 1.0, 1.5)`。
3. 逻辑宽高分别乘以 `density`。
4. 若宽度小于 `realWidth × 0.36`，等比例放大宽高。
5. 若高度小于 `realHeight × 0.36`，再次等比例放大宽高。
6. 对宽高向上取整，并去重相同结果。

`DeviceScreenStage` 在布局结果变化后于当前 frame 结束时提交新的 viewport，避免在 `build` 中直接产生网络副作用。服务端仍负责最终保持设备纵横比，Flutter 不在解码后再次生成更高分辨率图片。

备选方案“固定请求设备 75%”被否决，因为它与窗口实际面积无关；“只用 `ui.Codec` 的 targetWidth/targetHeight 缩小”也被否决，因为 JPEG 已在设备和网络侧按大尺寸生成，无法减少采集、传输和完整 JPEG 解码成本。

### 3. 状态变化必须可被画面组件观察

屏幕流接口增加只读错误信息和可监听的状态入口。画面舞台根据 `connecting`、`streaming`、`paused`、`error` 和 `disconnected` 展示占位状态；错误包含“STF 屏幕服务不可用”及重连语义，但不泄露无关进程命令或设备敏感信息。

这比仅依赖 `frameStream` 更可靠：连接在首帧之前失败时仍能更新 UI。备选方案“只写 debugPrint”被否决，因为用户无法区分空白画面、低帧率和连接失败。

### 4. Flutter 使用等价 JPEG 解码与 Canvas 绘制

`FastScreenRenderer` 保持一个活动 `ui.Image`、一个正在解码的任务和一个最新待解码帧。新帧覆盖待解码帧时计为丢弃；解码成功后替换活动图片，损坏帧不清空上一张有效画面。编码缓冲、图片描述符、codec 和旧图片在各自生命周期结束后释放。

画面使用 `CustomPaint` 的 `drawImageRect` 绘制，并用 `RepaintBoundary` 隔离屏幕区域。此路径已经进入 Flutter 的 GPU 合成层；手写 OpenGL 不会减少 JPEG 解码或源像素数量，而且 macOS OpenGL 已弃用，因此不采用。

备选方案“macOS 原生 Texture”被推迟：现有 Texture 通道未接入渲染器，并且仍要求 Dart 先提供 BGRA 数据，不能解决当前 JPEG 解码和过大投影问题，还会产生平台差异。

### 5. 性能指标按链路阶段拆分

调试指标分别统计一秒窗口内收到和渲染的帧数、累计被覆盖帧数以及最近解码耗时。指标用于用户在相同设备和相同投影尺寸下对照 Web，不把静态画面中 minicap 的低变更帧率误判为渲染器卡顿。

## Risks / Trade-offs

- [STF 未运行时不再有实时画面] → 显示明确错误并保留重连，不切换到语义不同的截图方案。
- [本机端口解析依赖当前 STF 进程信息] → 优先使用设备模型中的 `streamUrl`，把端口解析限制为当前本地兼容入口；后续 Gateway 可在不改变屏幕服务协议的情况下提供稳定 URL。
- [STF 多客户端共享一个投影生产者，尺寸变化会影响 Web] → 对 viewport 结果去重，并只在真实布局变化后发送；验收时使用相同画面尺寸比较。
- [Debug 模式自身影响帧率] → 指标用于定位链路阶段，最终流畅度由用户在当前真机场景验收，不把 Debug FPS 当作发布性能结论。
- [帧覆盖会降低完整帧计数] → 以最新画面和交互延迟优先，避免排队导致画面越来越落后。

## Migration Plan

1. 扩展屏幕流状态契约，并让页面装配传入设备已有的 STF 屏幕地址。
2. 将流选择切换为 STF WebSocket 唯一路径，断开自启 minicap 与 ADB 截图回退。
3. 接入 Web 等价 viewport 计算、尺寸去重和可见性消息顺序。
4. 收紧 JPEG 解码队列、资源释放、重绘边界和分段指标。
5. 执行格式化、静态分析与 OpenSpec 严格校验；不构建、不发布、不修改测试，真机滚动和 Web 对照由用户验收。

回退时恢复旧的流选择与 renderer 文件即可；本变更没有数据迁移或持久化格式变化。
