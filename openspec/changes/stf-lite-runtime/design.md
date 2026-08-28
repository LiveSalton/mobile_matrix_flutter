## Context

当前 Flutter 屏幕流通过 `SmartScreenStreamService` 扫描宿主机 STF 进程的 `--screen-port`，触控服务通过 `127.0.0.1:7100` 的 STF API/Socket.IO 获取设备通道；参考项目的 `mobile-matrix.sh` 则通过 Docker/Colima 启动 RethinkDB，再启动完整 `stf local`。完整 STF 的本地编排会同时拉起认证、App、API、Groups Engine、Processor、WebSocket、Storage、Poorxy 和 Provider 等进程。

本变更只解决 Mobile Matrix 的单机运行时依赖，不恢复完整 STF Web 产品能力。现有设备工具卡片大量直接使用 ADB，可继续由 Flutter 服务层负责。

## Goals / Non-Goals

**Goals:**

- 在没有 Docker、Colima、RethinkDB 和完整 STF Web 服务的情况下，为 Flutter 提供屏幕、触控、剪贴板和设备会话能力。
- 让运行时拥有的子进程、端口和设备会话可启动、重试、观察和回收。
- 通过显式本地接口传递设备会话信息，消除 `ps` 命令行扫描和固定 STF HTTP 端口依赖。
- 先完成本机无数据库原型，再为后续 `.app` 资源打包保留清晰边界。

**Non-Goals:**

- 不保留完整 STF Web UI、登录、用户、分组、租借和数据库历史。
- 不在本变更中实现最终 Apple Developer ID 签名、公证或 Universal Binary 发布。
- 不把整个 STF 源码和完整 `node_modules` 直接复制到 Flutter 资源中。
- 不修改当前 Dashboard 工具的业务行为，不用数据库替代 ADB 工具已有能力。

## Decisions

### 1. 采用 STF Lite 设备运行时，而不是修改完整 `stf local`

新增一个面向本地单用户的运行时边界，只抽取 STF 的设备侧能力：Provider/Device Worker 所需的设备发现、minicap、minitouch、STFService 和必要的 ADB 适配。Flutter 不再依赖完整 STF 的 API、认证、WebSocket 和数据库编排。

选择该方案是因为 `stf local` 的启动链把 Processor、API、Groups Engine、认证和 WebSocket 与 RethinkDB 强耦合。直接删除数据库调用会影响用户、设备、组、访问令牌和消息处理多个模块，改动面大且难以验证。只运行设备能力可以满足当前产品边界。

备选方案“保留完整 STF、把 RethinkDB 换成 SQLite/JSON”被否决：STF 使用 RethinkDB 查询、变更监听和多张表，兼容层会变成另一套数据库实现，仍保留不需要的服务复杂度。

### 2. 本地接口由运行时显式返回会话信息

STF Lite SHALL 由单一运行时管理器分配本地会话端口并返回设备序列号、状态、屏幕流地址和控制通道信息。Flutter 只消费该接口，不再通过 `ps -axww` 查找 `--screen-port`，也不把 `127.0.0.1:7100` 作为隐式前置条件。

第一阶段可使用本机回环 HTTP/WebSocket 或受控的本地进程消息通道；接口必须能表达启动、就绪、断开、重试和停止状态，并在端口变化后发布新地址。

### 3. 运行时采用单机内存状态

设备会话、端口分配、子进程句柄和健康状态只在运行时内存中保存。Flutter 的用户偏好仍使用已有本地配置机制；不为运行时引入 SQLite、RethinkDB 或其他数据库。

这样可避免为了单机临时状态引入锁、迁移和崩溃恢复问题。应用重启后重新扫描 ADB 并重建会话即可。

### 4. 设备端资源独立管理

运行时需要的 `minicap.apk`、minicap/minitouch 相关资源和 `STFService.apk` 由资源管理器按设备会话准备。安装、版本检查和启动失败必须返回结构化结果；不得假设对方电脑已经安装过 STF 的设备端 APK。

当前 Flutter 工程已有 `assets/minicap/minicap.apk`；`STFService.apk` 需要从参考 STF 源码中按 Apache-2.0 许可要求补齐，并保留许可证/NOTICE 记录。

### 5. 第一阶段采用 Node sidecar

第一阶段使用 Node sidecar 复用当前 `@devicefarmer/stf` 3.7.9 的设备实现，而不是立即用 Dart 或 Rust 重写 minicap/minitouch 协议。sidecar 只加载设备运行时所需模块，使用显式本地接口向 Flutter 返回会话信息；完整 Web、认证、数据库和 Docker 编排不进入 sidecar。

选择 Node sidecar 是因为参考实现已经是 Node，能够最大限度复用 STF 的设备端资源准备、minicap、minitouch 和 STFService 逻辑，先验证运行时边界和真机行为。Dart/Rust 重写虽然有机会降低长期运行时依赖，但会同时引入协议重写、设备兼容性和回归风险，暂不作为第一阶段前置条件。

### 6. 分阶段实现和发布边界

第一阶段先在开发环境中验证无 Docker、无 RethinkDB 的 STF Lite 子集和 Flutter 适配。发布阶段将裁剪后的 Node、ADB、sidecar、设备端资源和输入桥接器复制到 `.app` 的 `Contents/Resources/stf-lite`，由 Flutter 从包内路径启动。

最终 `.app` 需要对所有嵌套 Mach-O、Node 原生模块、ADB 和运行时二进制进行签名；如果支持 Intel Mac，还要构建 Universal 版本。签名、公证和跨机器验收不属于第一阶段。

### 7. 触控能力降级

设备支持 minitouch 时，sidecar 使用 STF 的 minitouch 协议发送按下、移动、抬起和提交事件。部分量产 Android 设备会允许 ADB 调试但拒绝 minitouch 读取输入设备；此时 sidecar 优先启动持久化 ADB 输入桥接器，以同一个 Android 手势会话转发单指按下、移动和抬起，并报告 `touchMode: adb-input-bridge`。桥接器不可用时才报告 `touchMode: adb-input`，将单指点击与滑动合并为受控的 `input tap`/`input swipe` 操作。

该降级只覆盖无法启动 minitouch 的设备，状态会通过会话查询接口公开，便于 UI 和日志区分“实时画面可用但触控能力受限”。

## Risks / Trade-offs

- [抽取后需要维护 STF 的设备协议分支] → 锁定当前 STF 版本和资源版本，保留来源、许可证和最小补丁记录。
- [取消数据库后失去设备租借和多用户状态] → 明确 STF Lite 只支持单机单用户，将设备会话绑定到当前 App 实例。
- [Node 原生依赖可能难以放进 `.app`] → 先以独立 sidecar 原型验证协议，再做 runtime 裁剪、架构构建和嵌套签名。
- [设备端 STFService.apk 未安装或版本不匹配] → 会话初始化阶段检查包版本，失败时显示可操作错误并记录设备序列号。
- [多个设备同时运行时端口和资源竞争] → 由运行时统一分配端口并按 serial 建立会话，禁止 Flutter 自行猜测或复用端口。

## Migration Plan

1. 从参考 STF 源码提取设备运行时依赖清单，确认屏幕、触控、剪贴板需要的最小组件和资源。
2. 建立 STF Lite 本地接口与生命周期管理器，先支持单设备启动、就绪、断开和停止。
3. 将 Flutter 屏幕流和触控装配切换到显式会话信息；保留现有 ADB 工具和截图剪贴板链路。
4. 在无 Docker/RethinkDB 的本机环境完成真机验收，再增加多设备和异常恢复验收。
5. 若原型通过，再单独创建发布变更，将 sidecar/runtime 纳入 `.app` 资源并处理签名公证。

回滚时恢复 Flutter 对现有 STF WebSocket/API 的适配入口；STF Lite 运行时不应修改或终止外部完整 STF 进程。
