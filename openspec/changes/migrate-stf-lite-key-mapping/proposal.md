## Why

STF Lite 迁移后，Flutter 仍按 Web STF 的约定发送 `a`、`1`、`space`、`del`、方向键和修饰键名称，但 Lite sidecar 目前只识别少量特殊键和数字，并通过 `adb shell input keyevent` 执行，导致普通电脑键盘输入无法落到 Android 当前焦点。原 Web STF 还使用 STFService 的 `KeyEventRequest` 表达 `DOWN`、`UP`、`PRESS` 和修饰键；这部分契约没有随 STF Lite 一起迁移，必须在继续打包分发前补齐。

## What Changes

- 完整梳理并固化旧 Web STF 的键盘输入契约：浏览器事件监听、字符/数字范围映射、特殊键映射、输入法切换键、剪贴板粘贴和错误边界。
- 在 STF Lite 中建立唯一的 Android 键码映射层，覆盖字母、数字、标点、编辑键、方向键、功能键、数字小键盘、左右修饰键及兼容别名；保留直接传入 Android 数字键码的能力，并拒绝未知键。
- 将普通键盘事件从“名称直接拼接 ADB 命令”迁移为 STFService `DO_KEYEVENT` 协议，保持 `DOWN`、`UP`、`PRESS` 的语义和修饰键状态，避免按住、组合键和粘贴被拆成无意义的独立命令。
- 让 Flutter → sidecar 的控制消息明确表达动作、键码名称和修饰键快照；持久控制通道只有在 sidecar 实际处理成功后才返回成功，失败时返回可定位的错误并写入 serial 关联日志。
- 保持现有文本输入边界：中文、Emoji、换行和任意 Unicode 文本继续使用“设置设备剪贴板 → 等待稳定 → 原生粘贴”；不把 `ACTION_SET_TEXT` 重新作为跨输入法主路径。
- 增加从原方案到 Lite 的静态契约核对和真机验收矩阵，覆盖英文、数字、标点、退格、回车、方向键、修饰键组合、输入法切换、Cmd/Ctrl+V、长按和设备切换。
- **BREAKING**：STF Lite 控制协议中 `key` 消息的成功含义改为“设备端事件已被实际接受”；调用方不得再把 WebSocket 写入成功当作按键执行成功。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `device-input-control`: 补齐 Web STF 键盘映射、按键动作语义、修饰键组合、输入法切换和真实执行结果反馈。
- `stf-lite-runtime`: 明确 STF Lite 本地控制接口对键盘事件的映射、传输和成功/失败回执要求。

## Impact

- Flutter 输入层：`lib/services/android_keyboard_mapper.dart`、`lib/views/control/widgets/device_screen_stage.dart`，必要时扩展 `IDeviceControlService` 的键盘消息模型。
- Flutter 运行时通信层：`lib/services/device_control_service.dart`、`lib/services/stf_lite_runtime_service.dart`，负责动作、修饰键、回执等待和错误日志。
- STF Lite sidecar：`tools/stf_lite/src/main.js`，负责键码表、STFService protobuf 帧、设备端输入执行和降级边界。
- 参考协议：`../mobile-matrix/vendor/devicefarmer-stf` 中的 `screen-directive.js`、`control-service.js`、`keycodes-service.js`、`service.js` 和 `STFService/wire.proto`；仅作为来源核对，不修改参考项目。
- 文档与变更治理：新增本 OpenSpec 的 proposal、设计、能力增量和任务清单；不修改当前未提交的设备工具箱、布局或国际化改动。
- 平台范围：保持现有 Flutter 桌面主机控制 Android 设备的边界；Android 设备输入协议放在 sidecar/设备实现层，Flutter 公共接口不新增 iOS 设备控制假设。
