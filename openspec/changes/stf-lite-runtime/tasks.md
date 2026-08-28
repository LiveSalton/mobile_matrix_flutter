## 1. STF Lite 依赖与边界

- [x] 1.1 从 `../mobile-matrix/vendor/devicefarmer-stf` 梳理设备发现、Device Worker、minicap、minitouch、STFService.apk 及其最小 Node 依赖清单
- [x] 1.2 记录 STF 3.7.9 的 Apache-2.0 许可证、第三方声明和资源来源，确保抽取后的运行时可随项目分发
- [x] 1.3 建立 STF Lite 目录和版本锁定信息，禁止引入完整 Web、认证、Groups Engine、Processor、Poorxy、RethinkDB 和 Docker 编排

## 2. Node sidecar 运行时

- [x] 2.1 创建 STF Lite sidecar 启动入口，接收运行目录、ADB 地址、设备筛选和本地监听配置
- [x] 2.2 实现单机内存设备会话注册表，按 Android serial 管理设备状态、子进程句柄、端口和最近错误
- [x] 2.3 实现设备发现与 Device Worker 启停，确保每台设备只创建一个独立会话
- [x] 2.4 接入 minicap 屏幕流、minitouch 触控和 STFService.apk 设备端资源准备，并将安装/启动失败转换为结构化错误
- [x] 2.5 实现本地健康检查和会话查询接口，返回设备 serial、状态、屏幕流地址及输入/剪贴板通道信息
- [x] 2.6 实现设备子进程异常退出、设备断开、端口变化和退避重试

## 3. Flutter 运行时适配

- [x] 3.1 新增 Flutter 侧 STF Lite 生命周期服务，负责启动 sidecar、读取状态、等待就绪和保存进程句柄
- [x] 3.2 将设备发现装配切换到 STF Lite 会话信息，同时保留 ADB 直接读取分辨率、厂商和工具数据的能力
- [x] 3.3 将屏幕流连接从 `ps` 扫描和固定 STF API 迁移到 sidecar 返回的显式地址
- [x] 3.4 将触控和剪贴板通道迁移到 STF Lite 本地接口，确保设备切换后旧会话不再接收操作
- [x] 3.5 保持截图、应用管理、Shell、日志和文件管理等现有 ADB 工具行为不变

## 4. 状态、错误与资源回收

- [x] 4.1 在 Flutter UI 中展示运行时启动中、依赖缺失、设备服务不可用、重连和停止状态
- [x] 4.2 为 sidecar 和 Flutter 适配增加 serial、组件、端口和错误阶段的脱敏日志
- [x] 4.3 实现应用退出时只回收由当前 App 启动的 sidecar 和设备子进程，不影响外部完整 STF 服务
- [ ] 4.4 验证单设备连接、断开、重连、切换设备和 sidecar 重启后的状态恢复

## 5. 原型验收

- [x] 5.1 在没有 Docker、Colima、RethinkDB 和完整 STF Web 服务的环境中启动 STF Lite
- [ ] 5.2 在真实 Android 设备上验收实时画面、点击、滑动、长按、键盘、剪贴板和截图
- [ ] 5.3 验收两台设备同时连接时的会话隔离、端口隔离和设备切换
- [x] 5.4 执行 Dart 格式化、静态分析和 OpenSpec 严格校验；不构建发布包，不修改测试文件

## 6. macOS 独立发布阶段

- [x] 6.1 评估裁剪后的 Node 运行时、原生模块和 ADB 的最终体积与架构支持（Universal 包约 112 MB，主程序、Node 和 ADB 均含 arm64/x86_64）
- [x] 6.2 将 sidecar/runtime 纳入 macOS `.app` 资源并配置进程启动路径
- [x] 6.3 对嵌套 Mach-O、Node 原生模块和 ADB 执行签名，完成 arm64/Universal 构建策略（当前本地包使用 ad hoc 签名）
- [ ] 6.4 完成 Apple Developer ID 签名、公证、Gatekeeper 和跨机器安装验收
