# 修复 STF Lite 数字按键映射

## 变更原因

Flutter 键盘桥把电脑上的数字键作为字符字符串发送，例如 `"9"`。sidecar 当前先把所有数字字符串解释为 Android 原始 KeyCode，导致 `"9"` 被当成 KeyCode `9`，而 Android KeyCode `9` 实际代表数字 `2`。

## 目标范围

- 将数字字符字符串按 Web STF canonical key 解析，保证 `"0"` 到 `"9"` 映射到 Android KeyCode `7` 到 `16`。
- 保留 JSON 数字值作为显式 Android 原始 KeyCode 的协议兼容性。
- 增加自动化回归测试，覆盖字符数字与整数 KeyCode 的边界。

## 非目标

- 不修改 Flutter 键盘事件生成逻辑；Flutter 当前发送数字字符的行为是正确的。
- 不改变字母、标点、特殊键、触控或文本剪贴板通道。
- 不改变设备端输入桥和 Android KeyEvent 注入实现。
