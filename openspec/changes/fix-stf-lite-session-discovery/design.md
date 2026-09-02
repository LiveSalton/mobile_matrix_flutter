## 设计

### 1. 资源解析优先级

保持现有优先级：显式配置 → `.app/Contents/Resources/stf-lite` → 当前目录开发路径 → 当前开发项目根目录。项目根目录通过从 `Platform.resolvedExecutable` 和 `Directory.current` 向上查找 `tools/stf_lite` 标记目录得到。

这样 Release 包不会依赖开发机文件；Debug 包即使由 Finder 启动，也能回到当前 checkout 的 sidecar 和 `../mobile-matrix/vendor/devicefarmer-stf` 资源。

### 2. 初始化时序

sidecar 先绑定回环 HTTP 服务，再执行一次 ADB 设备轮询，最后输出 `STF_LITE_READY`。Flutter 收到就绪信号后请求 `/v1/sessions` 时，设备会话对象已经注册；设备服务仍可在后台继续初始化，`screenUrl` 会先可用，画面流服务按现有重试逻辑连接。

### 3. 失败边界

如果没有开发资源且应用包也没有内置资源，运行时仍返回资源不可用；如果 ADB 没有授权设备，应用仍按现有空设备状态展示。两种情况都不再被误判为手机已连接但屏幕会话永久缺失。
