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
3. 运行根目录 `mobile-matrix.sh`，确认内置 STF Web 控制台与 `/api/v1/devices` 列表。
4. 访问 `http://127.0.0.1:7100/`，确认首次访问直接进入设备矩阵，不再经过浏览器登录页。
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

没有第二台真实 Android 设备时，只能报告单设备静态/API结果；不能完成多设备、批量、拔线和恢复验收。可信本地身份只用于回环地址，不能作为远程匿名部署方案。

## 当前真实验证快照（2026-08-06）

- 当前 arm64 Mac 使用宿主机 ADB 识别 1 台已授权真机；STF `3.7.9`、RethinkDB `2.4.2` 已启动，STFService 已安装并进入 `Fully operational`。
- Mobile Matrix 单设备闭环已通过：健康检查、设备列表、租用、临时远程连接、释放和释放后重新查询均已取得 API 证据。
- 已验证 STF 不可达、错误 Token、第二身份占用设备和 Docker 容器无 `/dev/bus/usb` 时的稳定错误/降级；未把缺少 USB 的容器报告为 ready。
- 由于当前只有 1 台真实 Android 设备，第二台设备、两台批量操作、拔线隔离与恢复仍保持未完成。
- 具体脱敏证据位于本 change 的 `evidence/m0-mac-adb-stf.md`、`evidence/m1-single-device-api.md` 和 `evidence/m3-failure-and-unplug.md`；证据文件被 `.gitignore` 忽略，避免本机运行凭据误提交。

## Mac 一键启动验证（2026-08-07）

- 根目录 `mobile-matrix.sh` 已在当前 arm64 Mac 上连续执行两次；第二次执行停止旧 STF 服务并重新启动，启动脚本退出后 STF 仍由 `launchctl` 托管。
- 当前内置 STF 控制台 `http://127.0.0.1:7100/` 返回 HTTP `200`，首页 HTML 标题为 `Mobile Matrix`，页面直接加载设备矩阵；7121 无监听。
- 当前真机截图链路已验证：通过 `screen.capture` 生成的 `/s/image/*` 资源经 `http://127.0.0.1:7100/` 返回 `200 image/jpeg`，本次样本为 `1080x2400`，截图处理器直连 7102 存储端口。
- 当前 ADB 识别 1 台已授权 Android 真机；双设备、批量真机、拔线隔离与恢复仍保持未完成。
- 该脚本当前仅支持 macOS；Windows 原生 PowerShell、WSL2、ADB/USB 与后台服务托管均尚未实现和验证。

## Requirement-by-requirement 审计

| 范围 | 结果 | 依据或阻塞 |
| --- | --- | --- |
| 1.x 项目、配置与运行边界 | 通过 | 实现、Node 20 约束、Mac 运行手册与严格校验 |
| 2.x STF 适配与设备模型 | 通过 | STF API/适配器测试与单设备真机列表 |
| 3.x 单设备查询、租用、释放、远程连接 | 通过 | `m1-single-device-api.md` |
| 4.x 批量选择器、并发、超时与部分失败 | 通过 | 25 个自动化测试与批量契约测试；双真机运行证据仍未声称通过 |
| 5.x 健康检查、稳定错误码与脱敏 | 通过 | `m3-failure-and-unplug.md`、红测与健康检查测试 |
| 6.1–6.2 Mac 单设备 STF 闭环 | 通过 | `m0-mac-adb-stf.md`、`m1-single-device-api.md` |
| 6.3–6.5 双设备、批量真机、拔线恢复 | 未完成 | 当前只有 1 台真实 Android 设备，不能用模拟状态替代 |
| 6.6 依赖故障与 Docker USB 边界 | 通过 | `m3-failure-and-unplug.md` |
| 7.1–7.3 记录、校验与审计 | 通过 | OpenSpec strict、根项目 25/25 测试、vendor 定向 8/8 测试、Web 构建、`git diff --check` |
