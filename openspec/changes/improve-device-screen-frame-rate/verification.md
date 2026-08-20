# 验证记录

## 已完成证据

- 源码：设备控制页只装配 `SmartScreenStreamService`；该服务只解析并绑定 STF WebSocket，不再创建原生 minicap 或 ADB 截图流。
- 源码：viewport 投影使用 Web STF 相同的 density 1.0～1.5、minscale 0.36、横屏宽高交换和向上取整规则。
- 源码：帧渲染限制为一个正在解码帧和一个最新待解码帧，并释放 buffer、descriptor、codec 和旧 image。
- 静态：本次涉及的 Dart 文件已格式化，`flutter analyze` 通过且无问题。
- 规范：`openspec validate improve-device-screen-frame-rate --strict` 通过。
- 边界：未构建、未发布、未修改或执行测试；尚无安装、真机和视觉验收证据。

## 用户真机验收清单

1. 使用同一台设备、同一应用页面和相近的画面区域尺寸，分别打开 Web STF 与 Flutter 控制台。
2. 确认两端请求的 STF 投影尺寸一致；若窗口尺寸不同，先调整至相同画面区域后再比较。
3. 在同一长列表连续滚动 10 秒，观察 Flutter HUD 的 `IN`、`OUT`、`DROP` 和解码耗时，并与 Web 流畅度对照。
4. 隐藏 Flutter 画面后确认流暂停，恢复后确认画面自动继续；断开 STF 时应显示明确错误且不出现截图回退画面。
5. 记录设备型号、投影尺寸、Flutter HUD 数值和主观滚动结果，作为最终运行验收证据。
