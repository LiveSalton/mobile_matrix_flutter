# 设计：桌面设备工具箱与 Web 功能对齐

## 参考基线

参考项目为 `/Users/salton/codeGit/mobile-matrix`，基线 revision 为 `2e2e7d6280af68264566dba88523ea1e79baecfb`。本变更只采用 Web 设备工具模板及其现有控制服务行为；参考工作区的群控/TikTok 等其他模式不属于本变更。

Web 设备工具分为 Dashboard、Logs、Screenshots、Automation、File Explorer、Advanced、Info 七组。Flutter 以 ADB 为桌面传输边界；已有 STF Socket.IO 屏幕流、触控和文本控制不迁移到工具服务。

## 组件边界

- `DeviceToolModels`：保存工具导航、文件项、设备信息、端口转发和铃声状态等纯数据类型。
- `DeviceToolsService`：以设备序列号为边界，封装 ADB shell/host 命令、logcat 子进程、文件拉取、安装卸载、无线调试、端口转发和设备信息读取；所有失败返回可展示的错误结果，不向 widget 抛出未处理异常。
- `DeviceWorkspace`：维护当前工具、输入控制器和加载状态；左侧为七组工具导航，右侧只渲染当前工具，所有内容放入可滚动区域。
- 页面双栏布局：左栏只承载手机实时画面和手机底部导航，并按当前手机屏幕宽高比计算左栏宽度，使实时画面贴合左栏边界；右栏顶部完整显示 AppHeader（品牌、设备选择、刷新设备、旋转、显隐和主题控制），下面再显示设备型号、分辨率、唯一 FPS、截屏图标和设备工具箱，避免设备控制与手机画面争用垂直空间。
- `DeviceControlService`：继续负责现有触控、文本注入、剪贴板同步、基础物理按键和设备画面刷新，不吸收新的工具业务。

## Web 到 Flutter 映射

| Web 工具 | Flutter 桌面实现 |
| --- | --- |
| Dashboard | 现有基础按键/文本/剪贴板/Shell，加上应用安装、应用包管理和 ADB 远程调试 |
| Logs | ADB logcat 可启动/停止，按关键字和级别过滤，清空显示，复制日志文本 |
| Screenshots | 复用现有 ADB 截屏并复制 PNG 到系统图片剪贴板，显示最近一次结果 |
| Automation | 铃声、Wi‑Fi、蓝牙和已配对蓝牙清理；应用商店入口通过设备 Shell 打开 |
| File Explorer | ADB 目录浏览、上级目录、文件详情和拉取到用户输入的目标路径 |
| Advanced | Web 特殊按键/方向键、端口转发和设备重启；Run JS/VNC 不适用于原生桌面 |
| Info | 读取并展示电池、显示、网络、SIM、硬件、平台、CPU、内存信息 |

## 错误与生命周期

- 未连接设备时工具按钮保持禁用或显示离线提示。
- ADB 命令统一转换为 `DeviceToolResult`，保留 stdout/stderr 摘要供 UI 展示。
- logcat 进程由 `DeviceToolsService` 独占，切换设备或 widget dispose 时停止并关闭流。
- 文件路径和端口在执行前做本地校验；命令失败不得阻塞后续工具操作。
- Dashboard 和各工具页面使用 `ListView`/`SingleChildScrollView`，不使用依赖固定高度的横向溢出布局。
