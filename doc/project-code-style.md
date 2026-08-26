# 编码约束

## 架构与状态

- 状态管理采用原生 `ValueNotifier` / `ChangeNotifier` 驱动，局部刷新优先。
- 异步操作均须处理取消、超时（Timeout）与组件 `mounted` 检查，杜绝内存泄漏。

## 错误与日志

- 外部进程与网络通信（ADB/WebSocket）须完备捕获异常，提供友好降级或重连。
- 日志使用 `debugPrint` 并携带模块标签（如 `[AdbService]`），发布环境静默。

## 接口与安全

- 设备端命令注入须严格转义 Shell 特殊字符，防范命令注入。
- 公共接口严格面向抽象（如 `IDeviceControlService`、`IScreenStreamService`），便于单测与解耦。
