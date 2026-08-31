## Context

本设计承接 `proposal.md`。当前输入链路已经分成两类：手机画面点击后的原始键盘事件，以及电脑剪贴板文本的复合粘贴。问题集中在原始键盘事件：Flutter 端仍发送 Web STF 风格的名称，STF Lite sidecar 却只保留少量名称并把事件改写为 `adb shell input keyevent`。

旧 Web STF 的可复用事实来自 `../mobile-matrix/vendor/devicefarmer-stf`：

- `screen-directive.js` 在画布有效聚焦后监听 `keydown`、`keyup`；输入法切换键单独发送 `switch_charset`，粘贴走 `clipboard.paste`。
- `keycodes-service.js` 对特殊键使用映射表，对 `0-9` 和 `A-Z` 使用连续范围映射；最终得到 Android KeyCode。
- `service.js` 通过 STFService 的 `DO_KEYEVENT` 发送 `KeyEventRequest`，请求包含 `DOWN`、`UP`、`PRESS` 和可选修饰键字段。
- `STFService/wire.proto` 定义了消息类型、事件枚举和 KeyEventRequest 字段；当前 Lite 已经用同一设备服务承载剪贴板设置，但没有复用按键请求。

当前 Lite 已有一个可复用的 `StfInputBridge` 持久进程。它通过 Android `InputManagerGlobal.injectInputEvent` 保持完整触摸手势，并从标准输入读取命令；当前仅支持触摸命令，sidecar 对其写入也未等待设备端结果。

## Goals / Non-Goals

**Goals:**

- 对外保持 Web STF 的键名、动作和输入边界，补齐 Lite 的 Android KeyCode 映射。
- 让字母、数字、标点、编辑键、方向键、数字小键盘、功能键、左右修饰键和 `switch_charset` 在真机上具有一致语义。
- 保留真实的 keyDown/keyUp/keypress 行为，使按住、重复和组合键不会被两个独立 `PRESS` 替代。
- 让持久控制通道返回可关联的处理结果；错误能够定位到设备 serial、动作、键名和失败阶段。
- 保持 Unicode 文本走现有“设备剪贴板 + 等待 + 原生粘贴”通道，不引入桌面 TextInput/IME。
- 让单设备和多设备会话都只向当前 serial 注入按键，并在断线、超时和设备切换后正确清理待处理请求。

**Non-Goals:**

- 不重新引入完整 STF Web、Socket.IO 服务端、Docker、RethinkDB 或账号/租借能力。
- 不把 `ACTION_SET_TEXT` 作为中文、Emoji 或第三方输入法的主要输入方案。
- 不将 `adb shell input text` 作为 Unicode 注入方案；它无法稳定保留输入法、换行、Emoji 和特殊字符语义。
- 不修改触摸坐标、屏幕流、窗口布局、设备工具箱或当前未提交的国际化内容。
- 不在本变更中实现桌面输入法候选窗口、桌面文本编辑器或新的可见输入控件。

## Decisions

### 1. 以旧 Web STF 作为行为基线，sidecar 作为键码唯一权威

Flutter 继续只产生规范化名称和动作，不在多个层级各维护一份 Android 数字键码表。sidecar 维护唯一的 canonical map，并接受两类输入：

1. Web STF 兼容名称，例如 `a`、`0`、`enter`、`del`、`space`、`dpad_left`、`numpad_1`、`switch_charset`。
2. 已经明确是整数的 Android KeyCode，用于现有快捷键和兼容调用。

映射优先复用旧 `keycodes-service.js` 的特殊键表与连续范围规则，并以 `vendor/devicefarmer-stf/android/index.json` 校验最终数字。`del`/`delete`、`backspace` 等兼容别名在进入传输层前归一化为同一个 Android KeyCode；未知名称、负数、非整数和不允许的 KeyCode 直接失败。

选择 sidecar 权威映射，是为了避免 Flutter、HTTP、WebSocket 和设备端分别解释同一键名。Flutter 的 `AndroidKeyboardMapper` 只负责把桌面物理键转换成稳定的 STF 名称，并保留物理键优先、逻辑键兜底的跨平台行为。

### 2. 首选高保真输入桥，保留 STFService 兼容降级

考虑过三种方案：

- **只扩展 `mapKeyCode` 并继续调用 `adb shell input keyevent`**：改动最少，但只能可靠表达一次性 `PRESS`，无法保持 `DOWN/UP`、左右修饰键和真实设备注入结果，不能恢复旧 Web STF 行为。
- **完整引入 STF Web 的设备服务层**：协议一致性最高，但会重新带入完整 STF 的运行时复杂度，与 STF Lite 的单机边界冲突。
- **复用旧键名/KeyEvent 契约，扩展已有 `StfInputBridge`，以 STFService 为降级**：保留用户行为和最小运行时边界，并能在支持反射注入的设备上得到真实 `injectInputEvent` 结果。

本变更采用第三种方案：

- 对 Android SDK 30 及以上且 `StfInputBridge` 可用的设备，sidecar 启动或懒启动同一个持久输入桥，同时承载触摸和键盘。桥接器新增 `KEY` 命令，使用 Android `KeyEvent` 的 `ACTION_DOWN`、`ACTION_UP`、`repeatCount` 和 `metaState`，并返回带 request id 的注入结果。
- 对无法启动该桥的设备，sidecar 复用现有 `STFService.apk` 和 `localabstract:stfservice`，按 `wire.proto` 编码 `DO_KEYEVENT` 的 `KeyEventRequest`。这条路径完整保留 `DOWN/UP/PRESS`、KeyCode 和修饰键字段；若设备服务是单向写入，则成功定义为服务连接正常且完整帧已写入，通道错误仍必须失败，不再使用无语义的 shell fallback。
- 仅针对历史快捷按钮的明确 `PRESS` 请求保留 `adb shell input keyevent` 作为最后兼容通道；原始键盘的 `DOWN/UP` 不得降级为 shell 命令并假报成功。

这样既不要求所有设备都支持同一个隐藏 API，也不把当前设备上已经验证的持久输入桥退回到离散 ADB 命令。

### 3. 用统一 KeyEvent 消息承载动作和修饰键

Flutter 到 sidecar 的键盘消息采用明确的数据结构：

```json
{
  "type": "key",
  "id": "serial-local-sequence",
  "action": "down|up|press",
  "key": "a",
  "modifiers": {
    "shift": false,
    "ctrl": false,
    "alt": false,
    "meta": false,
    "sym": false,
    "function": false,
    "capsLock": false,
    "scrollLock": false,
    "numLock": false
  }
}
```

`id` 只要求在当前设备控制会话内唯一；`action` 和 `key` 使用小写规范化值。Flutter 从 `HardwareKeyboard` 获取修饰键快照，同时仍发送修饰键自身的 down/up，使单独按键和组合键都能被 Android 端观察到。`switch_charset` 只发送一次 `press`，不生成桌面文本。

sidecar 将 `modifiers` 转换为高保真桥所需的 Android meta state，或映射到 STFService `KeyEventRequest` 的字段 3-11。设备切换或会话关闭时，未完成的 request id 全部以 session closed 失败结束，禁止跨 serial 重放。

### 4. 持久 WebSocket 改为“请求/回执”而不是“写入即成功”

当前持久控制通道在 `socket.add()` 后立即返回 `true`，sidecar 只在异常时发送一条没有被 Flutter 消费的错误消息。迁移后：

- 按键消息必须带 `id`；sidecar 在真实桥接器返回结果或 STFService 帧完成写入后回送 `{id, success, ...}`。
- Flutter runtime 维护当前 serial 的待处理回执表，按 id 等待、超时、断线和设备切换，并只把匹配的结果交给 `IDeviceControlService`。
- 触摸 MOVE/commit 仍保持单向高频路径，避免为了键盘回执改动已经稳定的滑动时序；触摸的既有错误处理继续由现有控制链路负责。
- HTTP 控制入口沿用相同 payload 和结果格式，便于启动竞态、诊断和旧客户端兼容；不支持回执的旧客户端只能得到明确的兼容行为，不得把它作为新 Flutter 输入路径。

### 5. 文本注入与原始按键保持隔离

`typeText`、右侧文本发送、桌面 Cmd/Ctrl+V 继续使用现有剪贴板复合流程：设置 STFService 剪贴板，确认成功，等待约 500ms，再触发一次 Android 原生粘贴。原始键盘只负责按键事件，不调用 `ACTION_SET_TEXT`，也不读取桌面输入法的组合文本。

该边界保留旧 STF 对第三方输入法的稳定做法，同时避免把 Unicode 字符错误地拆成不存在的 Android 物理键。

### 6. 日志以协议阶段和设备 serial 为主键

日志分成 Flutter、sidecar、Android bridge 三层，至少包含 serial、request id、action、canonical key、transport、结果和耗时；文本内容本身不写入日志，只记录字符数和是否为空。未知键、映射失败、桥接器退出、STFService 连接失败、回执超时和设备切换都要能在同一 request id 下串联。

快捷键和高频触控日志继续避免逐 MOVE 输出，防止日志反过来影响跟手性。

## Risks / Trade-offs

- [Android 隐藏 API 或 `InputManagerGlobal` 在部分版本不可反射调用] → 启动探测失败时切换到 STFService；不把 bridge 不可用伪装成成功。
- [STFService 的 `DO_KEYEVENT` 本身是单向 agent 命令] → 将其成功边界限定为“服务连接正常且完整帧写入”，并记录 `transport=stfservice`; 不宣称比协议实际提供的更强硬件确认。
- [不同平台的物理键、逻辑键和输入法切换键不一致] → 物理键优先、逻辑键兜底，沿用 Web STF 的 `switch_charset` 特判，并用 macOS、Windows/Linux 的验收矩阵覆盖。
- [修饰键重复发送可能造成组合状态差异] → 由单一消息模型记录左右修饰键和 metaState；桥接器按 action 处理，禁止 sidecar再次把一个事件拆成两个 PRESS。
- [新增回执会影响持久 WebSocket 生命周期] → 仅给键盘事件启用 request/response；回执表在超时、断线、设备切换和 dispose 时统一清理。
- [sidecar 资源中已有 bridge jar 与 STFService 版本不一致] → 在资源清单和启动日志中锁定版本，使用同一份 `wire.proto`/资源来源，不修改参考仓库。

## Migration Plan

1. 从参考 STF 源码和 Android 键码索引生成并人工核对 canonical key contract，先列出旧方案支持范围、别名和不可支持项。
2. 扩展 `StfInputBridge` 的命令协议和 sidecar 的键码解析；先让单个 `PRESS`、字母、数字和特殊键在单设备上可执行。
3. 接入 `DOWN/UP`、修饰键、输入法切换和重复事件；为持久 WebSocket/HTTP 增加 request id 回执与超时清理。
4. 将 Flutter mapper、控制服务和键盘 Focus 适配到统一消息；不改变隐藏输入代理和剪贴板文本注入边界。
5. 依次进行静态协议核对、Dart 分析、OpenSpec 校验和真机验收；由用户在真实输入框中验证英文、中文输入法、标点、退格、回车、组合键、长按、Cmd/Ctrl+V 与多设备隔离。
6. 若迁移出现回归，回滚 Flutter 的新 KeyEvent 回执适配，暂时保留旧控制入口；不得恢复未完成的名称直传 shell 路径作为正式方案。

## Open Questions

无。设备端桥接优先级、STFService 降级边界、文本注入边界和回执语义已在本设计中固定，后续可在实现阶段只调整编码细节，不改变外部契约。
