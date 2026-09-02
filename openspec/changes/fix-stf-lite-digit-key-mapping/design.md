# 设计：区分数字字符与原始 Android KeyCode

`resolveKey` 继续把 JSON number 类型视为显式 Android 原始 KeyCode，以保持已有硬件快捷操作和协议客户端兼容。对于字符串，先经过 canonical key 名称解析，再保留数字字符串的原始 KeyCode 兼容回退。

因此：

- `"9"` → canonical key `9` → Android KeyCode `16`；
- `"0"` → canonical key `0` → Android KeyCode `7`；
- `9` → 显式原始 Android KeyCode `9`，保持现有协议语义。

sidecar 导出纯解析函数供 Node 回归测试使用；直接作为进程启动时的行为不变。
