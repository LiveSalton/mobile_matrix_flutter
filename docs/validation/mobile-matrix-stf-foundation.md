# Mobile Matrix STF 基础闭环验证

## 目的

验证 Mobile Matrix 通过 DeviceFarmer STF 管理真实 Android 设备，不把模拟响应、旧缓存或按钮计时器当作设备能力。

## 证据等级

| 等级 | 含义 |
| --- | --- |
| 静态 | 类型检查、测试、OpenSpec 严格校验或配置审计 |
| API | 当前运行服务与 STF 的 HTTP 响应，必须记录时间和环境 |
| 真机 | ADB、STF UI/API 与真实设备插拔/租约结果 |

静态或 API 证据不能替代多设备真机证据。

## 运行顺序

1. 记录 Mac 架构、Node 20、ADB 和 STF 版本。
2. 记录 `adb devices -l`，确认第一台设备为 authorized/`device`。
3. 启动固定版本 STF，确认 STF UI 与 `/api/v1/devices` 列表。
4. 启动 Mobile Matrix，确认 `/health` 和 `/api/v1/devices`。
5. 对第一台设备执行查询、占用、远程连接和释放。
6. 接入第二台 Android 设备，重复列表并执行批量占用/释放。
7. 拔出一台设备，确认其离线/不可用且另一台仍可操作。
8. 分别验证 STF 不可达、Token 错误、设备忙和 Docker 无 USB 直通降级。

## 通过条件

- 单台设备的状态、占用、远程连接和释放结果与 STF 一致。
- 两台设备在列表、租约和批量结果中保持独立。
- 批量部分失败保留每台设备的结果和稳定错误码。
- 拔线只影响被拔出的设备。
- 任何依赖不可达都不会被报告为 `ready`。

## 未完成边界

没有第二台真实 Android 设备时，只能报告单设备静态/API结果；不能完成多设备、批量、拔线和恢复验收。没有可用 STF Token 时，不能声称租约或远程连接已验证。
