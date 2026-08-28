## Why

当前 Flutter `.app` 只连接已经运行的 STF 屏幕服务；用户把应用复制到桌面或其他电脑后，如果没有同时启动完整 STF、Docker 和 RethinkDB，就无法显示手机画面。完整 STF 的 Web、认证、分组和持久化能力超出 Mobile Matrix 的单机控制场景，阻碍独立应用分发。

## What Changes

- 新增面向 Mobile Matrix 单机控制场景的 STF Lite 运行时，只保留 ADB 设备发现、设备工作进程、minicap 屏幕流、minitouch 触控和 STFService 设备端服务。
- 新增本地运行时生命周期管理：启动、就绪探测、设备切换、断线重连、崩溃回收和退出清理由 Flutter 统一观察和控制。
- 移除 STF Lite 运行路径对 Docker、Colima、RethinkDB、完整 Web App、认证、Groups Engine、Processor、Poorxy 和持久化 Storage 的依赖。
- 设备清单、屏幕流地址和运行状态使用单机内存状态；用户偏好仍由 Flutter 本地配置保存，不引入数据库替代品。
- 将 Flutter 的屏幕、触控和剪贴板链路从“扫描完整 STF 进程的动态端口”收敛到显式的本地运行时接口，避免从 Finder 启动时依赖外部进程上下文。
- **BREAKING**：本变更不再承诺完整 STF Web 控制台、用户账号、设备分组、跨用户租借和数据库历史数据能力；这些能力不属于 Mobile Matrix 的 STF Lite 范围。
- 第一阶段只完成本机无 Docker、无 RethinkDB 的原型和真机验收；最终将运行时、Node/ADB 和嵌套二进制打包进签名公证的单 `.app` 属于后续发布阶段。

## Capabilities

### New Capabilities

- `stf-lite-runtime`: 定义单机 STF Lite 的运行时边界、生命周期、设备能力和本地通信契约。

### Modified Capabilities

无。现有屏幕流和设备工具规范的最终实现接入将在 STF Lite 原型通过真机验收后另行同步。

## Impact

- Flutter 服务层：新增 STF Lite 运行时管理器和本地通信适配，调整屏幕流、触控、剪贴板的装配入口。
- Flutter 页面层：显示运行时启动中、未安装依赖、设备服务不可用、重连和退出清理等可读状态。
- 资源：复用或补齐 minicap 与 STFService.apk 等设备端资源；保留 Apache-2.0 许可证和必要的第三方声明。
- 参考运行时：从 `../mobile-matrix/vendor/devicefarmer-stf` 抽取设备服务相关代码，不能把完整 `node_modules`、Web 依赖或 Docker 配置直接复制进 Flutter 运行路径。
- 发布：第一阶段不构建发布包；后续单 `.app` 分发需要处理 Node/ADB/原生依赖、arm64/Intel 架构、嵌套签名和 Apple 公证。
