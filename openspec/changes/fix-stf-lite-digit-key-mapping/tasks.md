## 1. 实现

- [x] 1.1 调整 sidecar 键解析顺序，优先区分 canonical 数字字符和 JSON 整数 KeyCode
- [x] 1.2 更新 STF Lite 协议说明，记录两种输入形式的边界

## 2. 验证

- [x] 2.1 增加数字字符与显式整数 KeyCode 的 Node 回归测试
- [ ] 2.2 在真实 Android 输入框中验证电脑数字键 `0` 到 `9` 的最终显示结果
