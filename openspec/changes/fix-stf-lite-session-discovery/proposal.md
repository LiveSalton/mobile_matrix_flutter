# 修复 STF Lite 屏幕会话发现

## Why

手机已经被 ADB 发现时，Mobile Matrix 仍可能显示“未找到 STF Lite 屏幕会话”。原因有两个：从 Finder 启动 Debug `.app` 时当前目录不是项目根目录，Flutter 找不到项目内的 sidecar 和参考资源；同时 sidecar 在初次 ADB 轮询完成前就通知 Flutter 已就绪，首次会话查询可能得到空列表。

## What Changes

- 让开发态运行时从应用可执行文件的祖先目录定位当前项目，支持从 Finder、桌面或 IDE 启动 Debug `.app`。
- 保持 Release `.app` 优先使用 `Contents/Resources/stf-lite` 的自包含资源。
- 让 sidecar 在首次 ADB 轮询完成后再发布就绪信号，确保首次 `/v1/sessions` 查询能看到已连接设备。
- 更新 STF Lite 运行时说明，明确就绪信号与首次设备发现的关系。

## Scope Boundary

- 不改变设备端 minicap、minitouch、输入桥接或屏幕协议。
- 不引入完整 STF、Docker、RethinkDB 或外部服务依赖。
- 不改变应用功能和控制协议，仅修复运行时资源发现与初始化时序。

## Impact

- Flutter 运行时路径解析：`lib/services/stf_lite_runtime_service.dart`
- STF Lite sidecar 启动时序：`tools/stf_lite/src/main.js`
- 运行时说明：`tools/stf_lite/README.md`
