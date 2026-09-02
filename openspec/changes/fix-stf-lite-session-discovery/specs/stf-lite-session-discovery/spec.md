# STF Lite 屏幕会话发现

## ADDED Requirements

### Requirement: 开发态启动可定位运行时资源

Mobile Matrix 的 Debug `.app` 从 Finder、桌面或 IDE 启动时，SHALL 能从项目根目录定位 STF Lite sidecar 和参考设备资源，不得要求当前工作目录恰好是项目根目录。

#### Scenario: 从 Finder 启动 Debug 应用

- **WHEN** ADB 已发现一台授权 Android 设备，且应用可执行文件位于项目构建目录
- **THEN** 运行时 SHALL 定位当前 checkout 的 sidecar 和参考资源，并尝试建立 STF Lite 屏幕会话

### Requirement: 就绪信号包含首次设备发现

STF Lite sidecar SHALL 在首次 ADB 轮询完成后发布 `STF_LITE_READY`，以避免 Flutter 首次查询会话时读取到初始化中的空列表。

#### Scenario: 首次查询会话

- **WHEN** sidecar 已发现授权 ADB 设备并向 Flutter 发布就绪信号
- **THEN** `GET /v1/sessions` SHALL 返回该设备的会话信息和屏幕流地址

### Requirement: Release 资源边界不变

Release `.app` SHALL 优先从 `Contents/Resources/stf-lite` 加载 sidecar、Node、ADB 和设备资源，不得因为新增开发态定位逻辑而依赖开发机路径。

#### Scenario: 从已打包应用启动

- **WHEN** 用户从 Finder 启动已打包的 Release `.app`
- **THEN** 运行时 SHALL 使用包内资源建立 STF Lite 会话，不得要求项目 checkout 或特定当前目录存在
