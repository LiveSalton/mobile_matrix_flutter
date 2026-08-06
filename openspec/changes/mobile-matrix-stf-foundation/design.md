## Context

Mobile Matrix 当前是空仓库，第一阶段需要先把多台真实 Android 手机管理起来。DeviceFarmer STF 已提供 ADB 设备发现、设备状态、远程画面/输入、设备租约和 REST API；本 change 不 fork STF，而是在其上建立独立的 Mobile Matrix 控制面。

当前没有 Linux 主机，首轮在 arm64 Mac 上验证。宿主机 ADB 直接访问 USB 手机，STF 原生运行；Docker Desktop 不承担 USB 直通。长期部署再迁移到 Linux 设备主机。

## Goals / Non-Goals

**Goals:**

- 通过 STF API/WebSocket 管理 Android 设备列表、状态、占用、释放和远程连接。
- 提供不依赖 STF 内部实现的 Mobile Matrix 设备模型和版本化 API。
- 支持按 serial 集合进行批量占用与释放，逐台返回结果。
- 区分 STF、Provider、ADB、鉴权、设备状态和部分批量失败。
- 用当前 Mac 的一台设备先验证，再用第二台设备证明多设备管理。
- 保留后续 Airtest、AI Agent、标签/分组和任务编排的稳定设备句柄边界。

**Non-Goals:**

- 不实现 Airtest、抖音业务、AI Agent、iOS/WDA、自定义 Web 控制台或完整任务编排。
- 不 fork 或重写 STF Provider，不创建第二套底层设备状态数据库。
- 不做公网多租户安全，不把 STF 直接暴露到公网。
- 不使用模拟设备、模拟画面或按钮计时器代替真实设备证据。

## Decisions

### 1. Mobile Matrix 作为 STF 上层控制面

STF 是设备存在、就绪与租约状态的唯一事实来源。Mobile Matrix 只负责适配、规范化、批量聚合和后续业务元数据；第一阶段不复制设备状态。

职责分界：

```text
Android 手机 ──ADB──> STF Provider/Worker ──> STF App/API
                                              │
                                              ▼
                                      Mobile Matrix Adapter
```

选择外部依赖模式，是为了复用 STF 已有的屏幕流、输入、Shell、日志、占用和远程连接，避免在空仓库中重复实现设备底层。Fork STF 的方案保留为未来需要修改底层协议时的独立 change。

### 2. 首轮使用 Mac 原生 ADB/STF

Mac 验证拓扑：

```text
Mac
  ├─ host ADB ───── USB 手机
  ├─ STF + RethinkDB
  └─ Mobile Matrix
```

Docker Desktop 在 macOS 上没有直接 USB 透传；USB/IP 属于额外实验路径，不作为首轮验收依赖。Mac 只作为开发/验证环境，长期设备节点使用 Linux。STF 固定 `3.7.9`；运行时优先使用隔离的 Node.js 20 LTS，避免覆盖系统 Node.js 22。

### 3. 统一设备模型与状态映射

内部模型保留 STF 原始字段，并提供：

- `offline`：设备未出现。
- `unavailable`：设备出现但 Provider 尚未就绪。
- `busy`：已被占用。
- `ready`：出现、就绪且可占用。
- `unknown`：STF/Provider/ADB 依赖不可达。

`using`、`owner` 等租约信息不丢失，用于解释 `busy` 与冲突。不得仅根据本地缓存宣称 `ready`。

### 4. 版本化 Mobile Matrix API

首批接口：

```text
GET    /api/v1/devices
GET    /api/v1/devices/:serial
POST   /api/v1/devices/:serial/lease
DELETE /api/v1/devices/:serial/lease
POST   /api/v1/devices/:serial/remote-connect
POST   /api/v1/batch/lease
POST   /api/v1/batch/release
GET    /health
```

STF Token 只在服务端注入。`remote-connect` 返回的临时 ADB 地址不进入前端永久存储。未来 Airtest 只依赖 Mobile Matrix 设备句柄，不直接耦合 STF API。

### 5. 批量操作独立聚合

第一版以 serial 列表为选择器，不提前引入标签数据库。每个目标独立执行并返回 `accepted`、`succeeded`、`failed` 和逐台错误原因；一台设备失败不吞掉其他结果。

占用、释放和远程连接不得在超时后盲目重复。超时先重新查询 STF 状态，再判断是否重试。查询可使用有限退避重试。重复占用、释放非本人租约和设备忙必须得到确定错误，而不是成功假象。

### 6. 健康检查与错误契约

错误码至少包含：

`stf_unreachable`、`provider_unavailable`、`device_offline`、`device_not_ready`、`device_busy`、`auth_failed`、`operation_timeout`、`partial_failure`。

`/health` 必须分别报告 Mobile Matrix 进程、STF API、Provider/ADB 依赖；不能把依赖故障统一成无诊断信息的 HTTP 500。

### 7. 首版技术形态

- Node.js 20 LTS + TypeScript。
- 轻量 HTTP 服务，不先做 Web UI。
- STF 设备状态与租约不落 Mobile Matrix 数据库。
- 配置通过环境变量/本地 secret 注入，敏感值不进源码、普通日志或版本库。

### 8. 首轮采用单一 STF 服务身份

第一阶段不新增 Mobile Matrix 自有用户认证、会话或权限数据库。控制面 API 只在本机或可信内网提供；所有租约、释放和远程连接操作都由配置的 STF Token 代表同一个服务身份执行。文档中的“当前客户端/当前所有者”在本 change 内指该 STF 服务身份。浏览器用户隔离、组织、配额和多租户权限必须作为后续独立 change 设计，不能从当前 API 推断已经存在。

选择该边界是为了先验证设备管理闭环，避免在 STF 已有 OAuth/租约模型之外重复建设身份系统；代价是第一阶段不适合不可信网络或多用户部署。

## Risks / Trade-offs

- [Mac ADB 在多设备或 USB Hub 场景下不稳定] → 首轮只把 Mac 当验证节点；记录真实设备证据，长期迁移 Linux。
- [Docker Desktop 无直接 USB 透传] → 使用宿主机 ADB；不把 `devicefarmer/adb` 容器作为 Mac 首轮依赖。
- [STF 内部通信默认缺少加密] → 只在本机/可信内网运行，不做公网部署。
- [STF API 或 Provider 短暂不可达] → 健康检查分层报告，查询有限重试，写操作先复查状态。
- [多台设备批量操作部分失败] → 每台设备独立超时和结果，聚合为 `partial_failure`。
- [STF 版本或 Node 原生依赖漂移] → 固定 STF 3.7.9，优先 Node 20 隔离环境，记录安装与运行证据。

## Migration Plan

1. 初始化 Mobile Matrix 的 OpenSpec 和控制面目录，不改变 STF 源码。
2. 先完成 Mac ADB/STF 单设备启动与设备列表验证。
3. 接入第二台设备，记录多设备状态和拔线行为。
4. 实现 STF Adapter、统一设备模型、健康检查和单设备 API。
5. 实现批量占用/释放并完成逐台结果验收。
6. 若 Mac 运行不稳定，保留 API/模型契约，把 STF 运行节点迁移到可用 Linux 主机；不使用模拟状态替代。

## Open Questions

- 第二台用于验收的 Android 手机和 USB Hub 何时可用？
- 首轮是否需要同时验证 `adb connect` 远程设备，还是只验证 USB 设备？
- 设备标签/分组是否在本 change 之后作为独立 change 引入？
- 首轮 CLI 是直接调用 HTTP API，还是与控制面同仓库提供薄封装？
