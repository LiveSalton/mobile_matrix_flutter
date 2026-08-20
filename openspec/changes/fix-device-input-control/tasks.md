# 实施任务

## 变更契约

- [x] 1.1 记录第三方输入法限制、剪贴板复合通道、隐藏输入代理和触控降级边界。
- [x] 1.2 对照仓库已有 STF 实现确认“设置剪贴板后等待再粘贴”的顺序。
- [x] 1.3 固化 Web STF 隐藏输入、画面点击聚焦、IME 提交和粘贴行为的 Reference Packet，并通过完整性与双向追踪门禁。

## Flutter/设备控制实现

- [x] 2.1 为 ADB 交互 shell 增加可等待的串行命令队列和启动竞态回退。
- [x] 2.2 将文本输入、电脑剪贴板和工作区发送按钮统一到剪贴板 + `KEYCODE_PASTE` 通道。
- [x] 2.3 移除可见实时同步输入栏，在手机画面内保留不占布局的透明输入代理；只在有效画面点击后聚焦，并继续处理 IME、Cmd/Ctrl+V、回车和退格。
- [x] 2.4 保持点击/长按语义，修复滑动事件与即时刷新顺序。
- [x] 2.5 将隐藏输入代理的光标锚定到手机画面底部，避免桌面输入法候选窗遮挡手机输入框。
- [x] 2.6 按 Web STF 源码移除目标端新增的滚轮/触控板双指滚动映射，仅保留按下、拖动、抬起触控链路。
- [x] 2.7 将设备触控切换为 Web 原版 STF Socket.IO 链路，动态解析设备 channel，并逐事件发送 `gestureStart`、DOWN/MOVE/UP commit、`gestureStop` 到 minitouch。
- [x] 2.8 让透明 IME 代理退出命中测试，避免桌面输入焦点重定向或取消正在进行的画布拖动。
- [x] 2.9 对齐 Web STF 的 `SeqQueue(100)`，让触控序号按 `0..99` 循环，避免长时间操作后服务端丢弃事件。

## 静态验收

- [x] 3.1 可见输入栏版本已完成格式化、Dart 静态分析和 macOS Debug 构建；不发布、不修改测试。
- [x] 3.2 对隐藏输入修正版执行格式化、Dart 静态分析、Reference Packet 与 OpenSpec 校验。
- [x] 3.3 隐藏输入与 STF Service 修正版已完成 macOS Debug 构建，并在荣耀真机日志中验证直接输入和 Cmd+V 成功；长文本/Emoji、点击/长按/滚动继续由用户验收。
- [x] 3.4 桌面输入法候选窗底部锚点已热更新到当前调试进程；最终候选窗视觉位置由用户在当前窗口验收。
- [x] 3.5 核对目标端不存在 `PointerScrollEvent`/`onPointerSignal` 设备手势入口，并通过 Flutter、Reference Packet 与 OpenSpec 静态校验。
- [x] 3.6 使用荣耀 Magic 6 Pro 对 Dart STF 触控通道执行真机验证：在 UP 前的停顿截图中列表已经移动，后续 MOVE 继续推动列表，确认不是抬手后才合成滑动。
- [ ] 3.7 对最终清理后的实现重新执行格式化、Flutter 静态分析、Reference Packet、OpenSpec、macOS Debug 构建与运行连接检查。
