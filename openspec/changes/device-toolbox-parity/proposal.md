# 设备工具箱同步 Web 功能

## Why

Flutter 桌面端当前的设备工具箱只覆盖物理按键、文本注入、剪贴板和基础 Shell，和 Web 端已经存在的设备工具能力不一致。用户要求以 Web 项目为基准补齐工具箱，同时保留桌面端已有的截图复制、单 FPS、无群控 Tab 和最小窗口约束。

## What Changes

- 增加 Dashboard、Logs、Automation、File Explorer、Advanced、Info 六组工具入口。
- 新增独立的设备工具服务，集中处理 ADB 命令、logcat 进程、文件操作、端口转发和设备信息读取。
- 将 Web 端有明确设备行为的功能映射到桌面 ADB；网页内 JavaScript 和 VNC 不纳入桌面端。
- 将设备工具箱改为可滚动、响应式的导航布局，窗口达到既有最小尺寸时不产生越界。
- 移除 Flutter 工具箱中的独立 Screenshots 入口，截图复制仅保留设备信息栏中的快捷图标；Automation 的 Wi‑Fi、蓝牙开关提升为设备信息栏快捷操作。

## Scope Boundary

- 截图只获取 PNG 并复制到系统图片剪贴板，不保存桌面文件，也不加入录制流程。
- 文件管理的“拉取文件”使用用户提供的目标路径保存，和截图的剪贴板策略分开。
- 不恢复群控执行向导，不改变现有屏幕流和 STF 触控链路。
