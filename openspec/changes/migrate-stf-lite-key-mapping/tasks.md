## 1. 原方案契约与键码基线

- [x] 1.1 对照 `screen-directive.js`、`control-service.js`、`keycodes-service.js`、`service.js` 和 `STFService/wire.proto`，整理 keyDown/keyUp/keyPress、输入法切换和剪贴板粘贴的端到端时序
- [x] 1.2 以旧 STF 特殊键表、连续范围规则和 Android 键码索引建立 canonical key contract，覆盖字母、数字、标点、编辑键、方向键、功能键、数字小键盘、左右修饰键与兼容别名
- [x] 1.3 标注 STFService `KeyEventRequest` 的事件枚举、KeyCode 字段和修饰键字段，明确 `DOWN`、`UP`、`PRESS`、未知键、非法动作和设备不可用的边界

## 2. STF Lite 设备输入实现

- [x] 2.1 在 `tools/stf_lite/src/main.js` 实现唯一的 canonical key 解析层，支持名称规范化、别名、数字 KeyCode 和未知输入拒绝，并为每次解析输出 serial 关联诊断信息
- [x] 2.2 扩展 `tools/stf_lite/input_bridge/src/StfInputBridge.java` 的行协议，增加带 request id、action、Android KeyCode 和 metaState 的 KEY 命令，使用 `KeyEvent` 注入并返回真实布尔结果
- [x] 2.3 在 sidecar 中为可用的持久输入桥建立键盘事件队列，解析 bridge 回执，处理桥接器退出、写入失败、超时和会话关闭，且不改变高频触摸协议
- [x] 2.4 在 sidecar 中复用现有 STFService 设备连接和 protobuf 帧，实现 `DO_KEYEVENT` 的 `DOWN/UP/PRESS` 及修饰键字段编码，作为输入桥不可用时的兼容降级
- [x] 2.5 限制 ADB shell 键码降级只用于明确的一次性 `PRESS` 快捷操作；原始键盘的 `DOWN/UP` 不得降级为离散 shell 命令并假报成功
- [x] 2.6 为键盘输入增加结构化日志，至少记录 serial、request id、canonical key、action、transport、结果、耗时和失败阶段，不记录文本内容

## 3. Flutter 控制协议适配

- [x] 3.1 在 `lib/services/android_keyboard_mapper.dart` 核对 Flutter 物理键/逻辑键到 canonical 名称的覆盖，修正 `del`、`delete`、小键盘、修饰键和输入法切换键的契约一致性
- [x] 3.2 在 `lib/models/` 或服务层新增不可变的键盘事件/修饰键模型，明确 action、canonical key、左右修饰键状态和当前 serial，保持 Models 不依赖 UI 或进程调用
- [x] 3.3 扩展 `IDeviceControlService` 与 `StfLiteDeviceControlService`，以统一 KeyEvent 消息发送原始按键，并把设备端回执传回调用方；保留 mock 服务的可测试行为
- [x] 3.4 在 `lib/services/stf_lite_runtime_service.dart` 为持久 WebSocket 按键消息增加 request id、回执等待、超时、断线和设备切换清理；HTTP 入口使用同一结果结构
- [x] 3.5 在 `lib/views/control/widgets/device_screen_stage.dart` 继续使用不可见原始 Focus 接收器，发送按键及 `HardwareKeyboard` 修饰键快照，不创建桌面 TextInput/IME
- [x] 3.6 保持 `typeText`、右侧文本发送和 Cmd/Ctrl+V 的“设备剪贴板 → 等待 → 原生粘贴”路径，不将 Unicode 文本改为逐字符 KeyEvent 或 `ACTION_SET_TEXT`

## 4. 多设备、错误和协议兼容

- [x] 4.1 确保每个 key request 绑定当前 serial，设备切换、sidecar 重启和控制通道断开时清理未完成请求，禁止跨设备重放
- [x] 4.2 为未知键、非法动作、STFService 缺失、bridge 不可用、回执超时和设备离线建立可读失败结果，并确认后续按键/文本队列仍可继续
- [x] 4.3 更新 `tools/stf_lite/README.md` 或同范围协议文档，记录 key payload、回执格式、传输优先级和降级边界；不修改参考项目源码
- [x] 4.4 审计新增长文本或错误文案是否需要进入 `lib/l10n/intl_zh.arb` 与 `lib/l10n/intl_en.arb`，禁止在 Flutter UI 中新增硬编码用户可见字符串

## 5. 静态核对与真机验收

- [x] 5.1 使用静态方式核对 canonical key contract 与旧 STF 特殊表、`0-9`/`A-Z` 连续范围和 `wire.proto` 字段，确认没有遗漏或冲突别名
- [x] 5.2 执行 Dart 格式化、`flutter analyze`、OpenSpec 严格校验和差异检查；不构建发布包、不修改测试文件
- [ ] 5.3 在真实 Android 输入框验收英文、数字、标点、空格、退格、删除、回车、Tab、方向键、Home/End、数字小键盘和功能键
- [ ] 5.4 在真实设备验收 Shift/Control/Alt/Meta 组合、长按与重复事件、输入法切换、中文候选、Emoji、换行及 Cmd/Ctrl+V
- [ ] 5.5 在两台设备同时在线时验收 serial 隔离、切换设备、断开重连、bridge 退出、STFService 降级和失败回执；由用户完成最终操作验收
