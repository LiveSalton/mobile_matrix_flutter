## Why

Mobile Matrix 需要先具备管理多台真实 Android 手机的基础能力，才能承载后续 Airtest、AI Agent 和自动化任务。DeviceFarmer STF 已提供成熟的设备发现、状态、远程控制和租约机制；本次以 STF 为外部设备基础设施，在当前没有 Linux 主机的条件下先用 arm64 Mac 完成可重复的本机验证。

## What Changes

- 新增 Mobile Matrix 独立控制面，作为 STF API/WebSocket 的稳定适配层。
- 新增统一 Android 设备模型，保留 STF 原始状态并映射 `ready`、`busy`、`offline`、`unavailable`、`unknown`。
- 新增设备列表、单设备查询、占用、释放和远程连接接口。
- 新增按 serial 列表选择设备的批量占用与批量释放接口，逐台返回结果并支持部分成功。
- 新增 STF、Provider、ADB 和鉴权依赖的健康检查与错误分类。
- 新增 Mac 原生验证路径：宿主机 ADB 直接访问 USB，STF 原生运行或使用非 USB 的辅助容器；Docker Desktop 不承担 USB 直通。
- 固定 STF `3.7.9` 作为第一阶段依赖，记录运行配置、Token/ADB key 注入边界和可信内网限制。
- 将设备状态以 STF 作为唯一事实来源，第一阶段不建立第二套底层设备状态数据库。
- 第一阶段采用单一服务身份：Mobile Matrix API 运行在本机/可信内网，所有租约所有权由配置的 STF Token 代表；多用户登录与权限隔离另立 change。

非目标：

- 不在本 change 内实现 Airtest、抖音流程、AI Agent、任务编排或自定义 Web 控制台。
- 不实现 iOS/WDA，也不宣称 STF 已提供 iOS 能力。
- 不 fork 或重写 STF Provider，不直接做公网多租户安全改造。
- 不使用模拟设备、模拟画面或本地计时器证明真实设备能力。

回退方式：如果 STF 在 Mac 上无法稳定运行，则保留 Mobile Matrix 的 STF 适配接口、设备领域模型和错误契约，撤回本地运行编排，改在可用 Linux 设备主机上部署 STF；不以替代实现伪造设备在线或远程控制。

## Capabilities

### New Capabilities

- `stf-device-management`: 通过 STF 管理 Android 设备列表、状态、租约和远程连接。
- `multi-device-batch-operations`: 通过 serial 集合执行批量占用与释放，支持逐台结果、幂等和部分成功。
- `stf-runtime-diagnostics`: 检查 STF、Provider、ADB 和鉴权依赖，并返回可区分的错误分类。

### Modified Capabilities

无。当前仓库尚无既有产品规格。

## Impact

- 新增 Mobile Matrix 控制面运行时、STF Adapter、设备领域模型、批量操作和健康检查模块。
- 新增版本化 HTTP API；STF Token 只在服务端使用。
- 新增 STF `3.7.9`、Node.js 20 LTS、ADB 和 RethinkDB 的开发/运行配置说明。
- 新增 OpenSpec 规格、设计、任务和 Mac/多设备验收证据记录。
- 第一阶段不要求修改 STF 源码，不要求 Android 手机端安装 Mobile Matrix Agent。
- 第一阶段不提供 Mobile Matrix 自有用户认证；API 访问控制依赖本机/可信内网边界和服务端 STF Token。
- 运行证据至少覆盖当前 Mac 上一台设备、第二台设备接入、单设备租约、批量租约、拔线和依赖故障。
