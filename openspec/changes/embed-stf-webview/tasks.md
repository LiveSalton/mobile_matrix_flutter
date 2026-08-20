# 实施任务

## OpenSpec / 依赖

- [x] 1.1 创建 WebView 嵌入变更，明确 Web 页面负责手机舞台交互、Flutter 负责容器和设备状态。
- [ ] 1.2 增加官方 `webview_flutter` 依赖并完成 macOS 插件注册与依赖获取。

## Flutter WebView 实现

- [ ] 2.1 新增 `StfWebSessionService`，实现 STF 健康检查、standalone URL、Cookie 保留、导航/脚本错误日志和重试状态。
- [ ] 2.2 新增 `StfWebViewStage`，以原生 WebView 加载 `#!/c/<serial>?standalone`，不叠加 Flutter 触控或输入层。
- [ ] 2.3 将设备控制页左侧手机舞台接入 WebView 模式，设备切换时正确销毁旧页面并加载新 serial。
- [ ] 2.4 保持 Flutter 右侧业务工作区可用，并确保 Web/native 两个控制面互斥。
- [ ] 2.5 增加 WebView 未就绪时的重试和 native 回退入口。

## 验收

- [ ] 3.1 Flutter 格式化、静态分析和 macOS Debug 构建通过。
- [ ] 3.2 STF Web 页面在 WebView 中加载并显示荣耀 Magic 6 Pro standalone 手机画面。
- [ ] 3.3 验证点击手机输入框后电脑中文输入法直接输入，且不出现 Flutter 输入框。
- [ ] 3.4 验证 Cmd/Ctrl+V 的中文、Emoji、长文本粘贴。
- [ ] 3.5 验证鼠标拖动和 Mac 双指行为与 Web 端一致，手机在拖动过程中实时跟手。
- [ ] 3.6 验证切换设备、STF 重启、WebView 重试和 native 回退，不向旧设备发送事件。
- [ ] 3.7 WebView 真机验收通过后，另行评估删除旧 Dart 触控/屏幕流代码；本变更不提前删除。
