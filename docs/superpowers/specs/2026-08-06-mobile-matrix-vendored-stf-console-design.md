# Mobile Matrix 内置 STF 控制台与批量租约设计

## 背景

当前 Mobile Matrix 已通过外部安装的 DeviceFarmer STF `3.7.9` 在 arm64 Mac 上完成单设备发现、占用、释放和远程连接验证。用户决定将 STF 源码直接复制到本工程，并以 STF 自带 Web 控制台作为 Mobile Matrix 的默认控制台，在其基础上实现多设备批量租约能力。

本设计取代“STF 仅作为外部依赖”的后续演进方向，但不修改已经完成的外部 STF 基线 change。

## 目标

- 将 DeviceFarmer STF `3.7.9` 源码直接纳入仓库。
- 将 STF 的 `7100` Web 控制台作为 Mobile Matrix 默认控制台。
- 在 STF 已有的用户、设备状态和租约语义上实现多选设备、批量占用、批量释放与逐台结果。
- 保持 STF 作为设备状态、用户身份和租约的唯一事实来源。
- 在当前 Mac 上回归单设备真机链路，并为双设备验收保留明确任务。

## 非目标

- 不实现 Airtest、AI Agent、任务编排、批量安装应用或批量远程连接。
- 不重写 STF Provider、ADB、minicap、minitouch 或 STFService。
- 不建立第二套设备数据库、租约数据库或 Mobile Matrix 用户体系。
- 不实现公网多租户安全方案；开发环境继续使用本地 Mock 登录。
- 不建立上游自动同步机制；本期采用直接复制源码。

## 源码与目录

```text
mobile-matrix/
├── vendor/
│   └── devicefarmer-stf/          # 直接复制的 STF 3.7.9 源码
│       ├── MOBILE_MATRIX_CHANGES.md
│       └── ... upstream source ...
├── src/                           # 既有实验性控制面，非默认入口
├── infra/stf/mac/
├── openspec/
└── package.json                   # 根目录统一开发入口
```

- 复制来自 DeviceFarmer STF `3.7.9` 的发布 tag，而不是全局 npm 安装目录、`node_modules` 或包管理器缓存。
- 保留上游 LICENSE、NOTICE（若有）和源码版权头。
- `vendor/devicefarmer-stf/MOBILE_MATRIX_CHANGES.md` 记录上游 tag、复制来源、复制日期和本项目改动清单。
- 对 STF 的改动直接提交在 `vendor/devicefarmer-stf/` 内；不使用 submodule、subtree 或自动同步脚本。

## 运行模型

```text
浏览器
  │
  ▼
STF Web Console :7100  ── 登录用户 / 多选批量操作
  │
  ▼
STF API + Batch Extension
  │
  ▼
STF Provider（Mac 宿主机 ADB） ── Android 真机
  │
  └── RethinkDB（仅辅助容器，无 USB）
```

- `vendor/devicefarmer-stf/` 运行 STF；`7100` 是 Mobile Matrix 的默认控制台入口。
- STF 的已登录用户即批量操作身份，批量后端沿用 STF 现有访问控制与租约所有者语义。
- 既有 `src/` Fastify 控制面保留为实验基线，不作为默认启动项、不提供首页控制台，也不与 STF 争夺租约真相。
- 根目录提供面向开发的统一脚本，委托 vendor STF 完成安装、启动和定向测试；本机端口、Token、ADB key 均只来自未提交环境配置。

## 批量租约后端

新增受现有 STF API 鉴权保护的批量租约端点，语义如下：

```text
POST /api/v1/user/devices/batch/lease
DELETE /api/v1/user/devices/batch/release
```

请求体包含非空、去重的 serial 列表。服务端固定并发上限，逐台复用 STF 既有占用或释放语义，而不是直接改写设备记录。

响应包含：

- 请求的 serial 数量与脱敏安全的逐台标识。
- `accepted`、`succeeded`、`failed` 集合。
- 每台成功或稳定失败分类，如 `device_busy`、`device_offline`、`device_not_ready`、`operation_timeout`、`partial_failure`。
- 聚合结果：全部成功、全部失败或部分失败。

超时后的租约操作先查询 STF 当前所有权；如果查询能够证明目标已成功占用或释放，则返回实际结果，不盲目重复变更。

批量远程连接不在首期范围内：远程连接继续是单设备、显式、临时的会话操作。

## 控制台交互

- STF 设备列表新增多选模式，不改变默认单设备点击、远程查看和单设备租约流程。
- 多选模式显示已选择数量，以及“批量占用”“批量释放”操作。
- 提交前显示受影响设备数；请求中不携带 STF Token。
- 完成后展示逐台结果和聚合状态。一台失败不会隐藏其他设备结果。
- 当前页面刷新、退出多选模式或重新进入页面时不持久化选择；不会在浏览器本地存储租约或连接地址。
- 设备忙、离线、未就绪、超时和鉴权失败按后端稳定错误码显示；不以计时器或本地缓存伪造 ready 状态。

## 错误、安全与可观测性

- 保留 Token、ADB key、完整远程连接地址和用户凭据的脱敏规则。
- STF 不可达、Provider/ADB 不可用、错误 Token、设备忙、部分失败必须可区分。
- Docker 在 Mac 上仅承载 RethinkDB 等辅助服务；没有 USB 时继续使用宿主机 ADB，或明确报告 setup blocker，绝不报告虚假的设备 ready。
- 本期 Mock 登录只用于本机开发。进入可信内网或生产前必须另立 change 设计真实认证和权限模型。

## 验证

1. 固定来源与许可证审计：确认 vendor 源码为 STF `3.7.9`，不含复制进来的依赖缓存或本机凭据。
2. 后端定向测试：请求校验、并发上限、逐台结果、部分失败、超时后重查、所有权保护和脱敏。
3. 控制台定向测试：多选状态、批量操作发起、结果渲染和错误展示。
4. Mac 真机回归：STF `7100` 列出当前授权设备，单设备占用/释放/远程连接仍可用。
5. 双设备验收：第二台设备接入后完成独立状态、批量占用/释放、一个目标失败不影响另一个目标，以及拔线恢复验证。

没有第二台真实 Android 设备时，双设备、批量真机和拔线恢复相关任务必须保持未完成。

## 回退

如果 vendor STF 改造破坏单设备稳定性，停止使用新的根目录启动入口，恢复到已经验证的外部 STF `3.7.9` 本机运行路径。保留证据和改动记录，不用模拟设备替代真实验证。
