## Purpose

为 Mobile Matrix 提供一个面向单机 Android 控制的轻量设备运行时，使 Flutter 应用无需 Docker、RethinkDB 或外部 STF Web 控制台即可获得稳定的设备画面和控制能力。

## ADDED Requirements

### Requirement: 独立启动不依赖完整 STF

STF Lite SHALL 在本机启动并提供 Mobile Matrix 所需的设备能力，不得要求 Docker、Colima、RethinkDB、STF Web 登录或外部 STF HTTP 控制台处于运行状态。

#### Scenario: 本机没有完整 STF 服务

- **WHEN** 用户启动 Mobile Matrix 且 `127.0.0.1:7100` 没有完整 STF 服务
- **THEN** STF Lite SHALL 仍能初始化并尝试提供已授权 Android 设备，不得仅因完整 STF 不可用而显示空白设备工作区

#### Scenario: 本机没有数据库服务

- **WHEN** 本机没有 Docker、Colima 或 RethinkDB
- **THEN** STF Lite SHALL 不因数据库连接失败而退出，运行时状态 SHALL 使用单机内存状态管理

### Requirement: 设备能力按设备会话隔离

STF Lite SHALL 为每个已授权 ADB 设备建立独立会话，并为当前会话提供实时屏幕、触控、剪贴板和设备服务能力；任何设备会话不得向另一台设备发送控制命令或复用其屏幕流地址。

#### Scenario: 发现已授权设备

- **WHEN** ADB 返回一台状态为 `device` 的 Android 设备
- **THEN** STF Lite SHALL 创建该设备的运行会话并返回可供 Flutter 使用的设备标识和屏幕流连接信息

#### Scenario: 切换设备

- **WHEN** 用户从一台设备切换到另一台设备
- **THEN** 运行时 SHALL 停止旧会话中由本应用拥有的连接和子进程，并让后续屏幕帧、触控和剪贴板操作只绑定新设备

#### Scenario: 设备断开

- **WHEN** ADB 设备从已授权列表中消失
- **THEN** 运行时 SHALL 将该会话标记为断开，释放其本地端口和设备连接，并向 Flutter 返回可读的断开状态

### Requirement: 实时画面和输入可用

STF Lite SHALL 提供与当前 Flutter 控制台兼容的实时屏幕帧、点击、滑动、长按、键盘、剪贴板和截图所需的设备通道，并保持设备画面的纵横比和最新帧优先策略。

#### Scenario: 建立屏幕流

- **WHEN** 当前设备会话已就绪且 Flutter 请求屏幕流
- **THEN** 运行时 SHALL 返回该设备专属的实时 JPEG 屏幕流，且画面不得依赖另一个设备或静态截图回退

#### Scenario: 发送触控操作

- **WHEN** Flutter 发送按下、移动、抬起或取消事件
- **THEN** STF Lite SHALL 优先通过 minitouch 按当前设备会话顺序转发事件；设备拒绝 minitouch 时 SHALL 优先使用持久化 ADB 输入桥接保持单指手势连续，并返回 `touchMode: adb-input-bridge`；桥接器不可用时才使用 `touchMode: adb-input` 的受限点击/滑动降级，不得静默丢弃或伪造成功

### Requirement: macOS 应用自包含运行时

STF Lite 的 macOS Release 应用 SHALL 将 sidecar、Node、ADB、设备端资源和输入桥接器放入应用资源目录，并从应用资源目录启动，不得依赖开发机路径。

#### Scenario: 从 Finder 启动已打包应用

- **WHEN** 用户从另一台兼容架构的 Mac 启动已打包的 Mobile Matrix 应用
- **THEN** 应用 SHALL 从 `Contents/Resources/stf-lite` 启动 sidecar，并使用包内 Node、ADB 和 STF Lite 资源；若设备已授权， SHALL 能建立设备会话

#### Scenario: 发送剪贴板内容

- **WHEN** Flutter 请求将电脑文本粘贴到当前设备
- **THEN** 运行时 SHALL 将文本发送到当前设备的 STFService 或等价设备通道，并返回明确成功或失败结果

### Requirement: 生命周期可观测且可恢复

STF Lite SHALL 提供启动中、就绪、设备服务不可用、连接中断、重试和停止等可观察状态，并记录运行时、设备序列号、子进程和端口分配的脱敏诊断信息。

#### Scenario: 运行时启动

- **WHEN** Flutter 请求启动 STF Lite
- **THEN** 运行时 SHALL 在就绪探测通过前报告启动中，成功后报告就绪并提供当前设备会话状态

#### Scenario: 子进程异常退出

- **WHEN** 运行时拥有的设备子进程异常退出
- **THEN** 运行时 SHALL 标记受影响设备不可用，按退避策略重试，并保留最后一次失败原因供 Flutter 展示

#### Scenario: 应用退出

- **WHEN** Mobile Matrix 退出或明确停止 STF Lite
- **THEN** 运行时 SHALL 停止由本应用启动的子进程、关闭本地连接和释放端口，不得终止不属于本应用的外部 STF 服务

### Requirement: 运行时接口明确且不依赖进程扫描

Flutter SHALL 通过显式的本地运行时接口获取设备会话和屏幕流地址，不得依赖扫描宿主机进程命令行、猜测动态端口或要求完整 STF 的固定 `127.0.0.1:7100` API。

#### Scenario: 返回设备会话信息

- **WHEN** STF Lite 完成设备会话初始化
- **THEN** 本地接口 SHALL 返回设备序列号、会话状态、屏幕流地址和必要的输入/剪贴板通道信息

#### Scenario: 端口发生变化

- **WHEN** 设备子进程重启并获得新的本地端口
- **THEN** 运行时 SHALL 通过接口发布最新连接信息，Flutter SHALL 不继续使用旧端口

### Requirement: 不提供完整 STF Web 能力

STF Lite SHALL 明确限定为 Mobile Matrix 单机控制运行时，不得为了兼容完整 STF 而重新引入用户认证、设备分组、跨用户租借、RethinkDB 历史数据或完整 STF Web 控制台。

#### Scenario: 查询非目标能力

- **WHEN** 调用方请求账号、分组或持久化历史等完整 STF Web 能力
- **THEN** STF Lite SHALL 返回未支持状态，并提供可读的能力边界说明
