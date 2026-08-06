# Mobile Matrix — DeviceFarmer STF 集成设计

日期：2026-08-06  
状态：已获方案确认，待用户审阅设计文档

## 1. 背景与目标

Mobile Matrix 的第一阶段目标是基于 [DeviceFarmer STF](https://github.com/DeviceFarmer/stf) 管理多台真实 Android 手机，先建立稳定的设备接入、状态管理、占用释放和批量操作能力，再在其上接入 Airtest、AI Agent 和更高层的业务任务。

当前工作区为空目录，没有既有业务代码或架构约束。本设计只定义第一阶段的设备管理闭环，不提前实现 Airtest、抖音业务、AI Agent、iOS 或公网多租户部署。

## 2. 已确认的架构决策

### 2.1 集成方式

Mobile Matrix 采用“独立控制面 + STF 外部依赖”模式，不在第一阶段 fork 或重写 STF。

- STF 继续负责底层设备生命周期和远程控制。
- Mobile Matrix 通过 STF REST API 与 WebSocket 工作。
- Mobile Matrix 隔离 STF 的原始接口和版本变化，为后续执行器提供稳定设备句柄。
- STF Token 只保存在 Mobile Matrix 服务端，不下发到前端或任务脚本。

这样可以直接复用 STF 已有的设备发现、设备状态、屏幕流、输入、Shell、日志、设备占用和远程连接能力，同时把上层业务与 STF 内部实现解耦。

### 2.2 职责边界

STF 负责：

- ADB 设备发现、连接和断开
- 设备在线、离线、未授权和就绪状态
- 屏幕流、触控、输入、Shell 和日志
- 设备占用与释放
- 远程 `adb connect` 地址
- 底层设备元数据

Mobile Matrix 负责：

- STF API 的统一封装
- 稳定的设备领域模型
- 面向设备集合的批量操作
- 依赖健康检查和错误分类
- 后续的标签、分组、任务记录和执行器适配

第一阶段不复制 STF 的设备状态，不建立第二套设备状态数据库。设备是否存在、是否就绪和是否被占用，以 STF 为唯一事实来源。

## 3. 部署拓扑

### 3.1 长期目标拓扑

```text
Linux 设备主机
  ├─ ADB daemon
  ├─ STF Provider / Worker
  └─ USB Hub + 多台 Android 手机
          │
          ▼
STF 核心服务
  ├─ RethinkDB
  ├─ STF App/API
  └─ WebSocket/代理
          │
          ▼
Mobile Matrix Control Plane
  ├─ STF_BASE_URL
  ├─ STF_TOKEN
  └─ 设备与批量操作 API
```

长期部署时，Linux 主机负责连接实体手机和运行 Provider；Mobile Matrix 不直接访问 USB。设备规模增加时按设备主机水平扩展，每个物理主机只运行一个 STF Provider，避免多个 Provider 竞争同一组设备。

STF 的官方部署说明将 Provider、App/API、数据库和代理分为可独立部署的角色，并要求 Provider 与其管理的设备位于同一主机或设备节点上。

### 3.2 当前 Mac 原生验证模式

当前没有 Linux 主机，因此第一阶段使用 Mac 进行开发和实机验证：

```text
Mac
  ├─ host ADB              # 直接访问 USB 手机
  ├─ STF Provider / STF    # 原生运行
  ├─ RethinkDB             # 原生运行或单独 Docker 容器
  └─ Mobile Matrix         # 本地 API/CLI
```

验证顺序：

1. 使用当前 Mac 的 ADB 识别一台 Android 真机。
2. 原生启动 STF，确认 Provider 能显示和控制该设备。
3. 接入第二台手机，确认 STF 同时管理两台设备。
4. 启动 Mobile Matrix，读取两台设备的状态。
5. 验证单设备和批量占用、释放。

Docker Desktop 在 macOS 上不支持直接 USB 设备透传。USB/IP 可以作为实验性绕行路径，但第一阶段不依赖它；应让宿主机 ADB 直接管理 USB，再让 STF 使用宿主机 ADB。

Mac 只作为验证和开发环境，不作为长期生产设备主机。DeviceFarmer 文档指出 macOS 可用于开发，但 ADB 在生产设备场景下可靠性较差。运行时优先准备隔离的 Node.js 20 LTS 环境；当前机器的 Node.js 22 只作为兼容性待验证项，不修改系统 Node。

### 3.3 固定与安全

- STF 使用固定版本 `3.7.9`，不直接依赖 `latest`。
- RethinkDB 数据和 STF 配置使用持久化卷。
- STF Token、ADB key、内部地址和端口通过环境变量或本地 secret 文件注入。
- 第一阶段只面向本机或可信内网，不暴露公网。
- 不把设备远程连接地址、账号信息或聊天内容写入长期日志。

STF 官方安全说明指出，其内部进程通信默认缺少加密，设备也不会自动完全清理用户数据；因此公网多用户安全不属于本阶段目标。

## 4. Mobile Matrix 服务边界

第一阶段服务划分如下：

```text
Mobile Matrix Control Plane
  ├─ STF Adapter       # REST/WebSocket 客户端
  ├─ Device Registry   # 统一设备模型与状态映射
  ├─ Batch Operations  # 多设备操作聚合
  └─ Health/Diagnostics
```

首版不开发自定义控制台，以 API/CLI 完成设备管理闭环；设备模型和批量操作稳定后再开发设备墙 UI。

## 5. 设备领域模型

Mobile Matrix 保留 STF 的原始状态字段，同时提供稳定的统一状态：

```json
{
  "id": "7855361b",
  "serial": "7855361b",
  "name": "设备名称",
  "platform": "android",
  "present": true,
  "ready": true,
  "using": false,
  "owner": null,
  "status": "ready",
  "provider": "mac-host"
}
```

状态映射：

| Mobile Matrix 状态 | 判定 |
| --- | --- |
| `offline` | `present=false` |
| `unavailable` | 已连接但 `ready=false` |
| `busy` | 设备被其他用户或会话占用 |
| `ready` | 已连接、就绪且未占用 |
| `unknown` | STF API 或 Provider 暂时不可达 |

原始 STF 字段必须保留在内部响应上下文中，避免统一状态丢失诊断信息。

## 6. API 设计

Mobile Matrix 不直接暴露 STF 原始 API，而提供版本化的稳定接口。首批接口如下：

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

### 6.1 单设备操作

- `GET /devices` 返回统一设备模型及当前状态。
- `GET /devices/:serial` 返回单台设备和可诊断的 STF 原始状态。
- `POST /devices/:serial/lease` 请求占用设备。
- `DELETE /devices/:serial/lease` 释放当前用户或当前服务持有的租约。
- `POST /devices/:serial/remote-connect` 获取 STF 提供的临时 ADB 连接地址。

### 6.2 批量操作

第一版使用 serial 列表选择设备，后续再增加标签和分组：

- 每台设备独立执行并独立返回结果。
- 一台设备失败不能吞掉其他设备的结果。
- 响应包含 `accepted`、`succeeded`、`failed` 和每台设备的错误原因。
- 占用和释放保持幂等；重复占用不能创建第二个会话，释放非本人设备必须明确失败。
- `remote-connect` 返回的临时地址不在前端永久保存。
- 未来 Airtest 只接收 Mobile Matrix 设备句柄，不直接依赖 STF serial 细节。

## 7. 可靠性与错误处理

错误分类必须能区分依赖层和设备层：

| 错误码 | 含义 |
| --- | --- |
| `stf_unreachable` | STF API 不可达 |
| `provider_unavailable` | 设备主机或 Provider 不可达 |
| `device_offline` | 设备不存在或 `present=false` |
| `device_not_ready` | 设备存在但 `ready=false` |
| `device_busy` | 设备已被占用 |
| `auth_failed` | STF Token 无效 |
| `operation_timeout` | 操作超时 |
| `partial_failure` | 批量操作部分成功 |

重试规则：

- 查询类请求可以有限重试，并使用有上限的退避。
- 占用、释放、远程连接不盲目重复执行。
- 这些操作超时后先重新查询 STF 状态，再决定是否重试。
- 批量请求逐台设置超时，并返回可重试建议。
- STF、Provider 或 ADB 不健康时，Mobile Matrix 必须报告具体依赖层，不返回笼统的 HTTP 500。

## 8. 首轮验收

首轮只证明基础多设备管理：

1. Mac ADB 识别当前 Android 手机。
2. STF 显示当前手机并可打开远程控制。
3. 接入第二台手机后，两台设备同时出现在 STF。
4. Mobile Matrix 能列出两台设备及状态。
5. 能成功占用并释放一台设备。
6. 能对两台设备执行批量占用/释放，并分别返回结果。
7. 拔掉一台设备后，另一台仍可正常操作，拔掉的设备显示为离线或不可用。
8. STF 不可达、Token 错误和设备忙时，返回可区分的错误码。

验收证据需要覆盖：ADB 设备列表、STF 页面或 API 设备列表、Mobile Matrix API 响应、单设备租约结果、批量结果和拔线后的状态变化。静态检查不能替代真实设备证据。

## 9. 非目标与后续阶段

本阶段明确不做：

- Airtest 任务执行
- 抖音搜索、关注、私信等业务流程
- AI Agent 调度
- iOS/WDA 设备接入
- 自定义 Web 控制台
- 公网多租户安全、细粒度权限和完整数据清理
- Fork STF 或重写 STF Provider

后续顺序建议：

1. 设备标签、分组和设备墙。
2. 任务记录、批量动作和有限并发。
3. Airtest 执行器适配。
4. AI Agent 设备工具。
5. Linux 多 Provider 部署和更严格的权限/安全模型。
6. 在独立适配器边界上评估 iOS/WDA。

## 10. 设计依据

- [DeviceFarmer STF README](https://github.com/DeviceFarmer/stf)：功能、依赖、Mac 开发限制和安全边界。
- [STF API](https://github.com/DeviceFarmer/stf/blob/master/doc/API.md)：设备查询、占用、释放和远程连接接口。
- [STF Deployment](https://github.com/DeviceFarmer/stf/blob/master/doc/DEPLOYMENT.md)：Provider、App、数据库和部署角色。
- [STF Docker Compose](https://github.com/DeviceFarmer/stf/blob/master/docker-compose.yaml)：RethinkDB、ADB 和 STF 容器拓扑参考。
- [Docker Desktop USB/IP](https://docs.docker.com/desktop/features/usbip/)：macOS USB 容器接入限制与实验性绕行方式。
