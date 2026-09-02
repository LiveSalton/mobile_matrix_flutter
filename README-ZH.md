# Mobile Matrix — macOS Android 设备控制与 ADB 工作台

Mobile Matrix 是一个基于 Flutter 的 macOS 桌面端 Android 设备控制工作台。它将 ADB 设备管理、实时投屏、键盘与触摸操作、剪贴板同步、截屏复制、设备工具和 STF Lite 运行时整合到一个控制台中。

[English README](README.md) · [下载最新 macOS 版本](https://github.com/LiveSalton/mobile_matrix_flutter/releases/latest) · [查看所有版本](https://github.com/LiveSalton/mobile_matrix_flutter/releases)

## 功能

- **Android 设备控制**：发现已授权的 ADB 设备，并在多个已连接设备之间切换。
- **实时投屏**：通过项目内置的 STF Lite 和 minicap 运行时查看 Android 实时画面。
- **键盘与触摸操作**：向设备发送文字、点击、滑动、实体按键和导航操作。
- **剪贴板同步**：在 Mac 剪贴板与 Android 设备之间传递文本。
- **截屏复制**：截取当前设备画面，并复制到系统剪贴板。
- **ADB 工具**：执行 Shell 命令，查询系统版本、屏幕分辨率、网络信息等设备信息。
- **设备工作流**：安装和管理 APK、读取已安装应用、打开系统设置、配置开发者选项。
- **桌面控制台**：通过响应式多面板工作台集中控制设备。

## 下载

### macOS

当前已发布版本支持 **Apple Silicon（arm64）**：

- [下载 Mobile-Matrix-macos-arm64.zip](https://github.com/LiveSalton/mobile_matrix_flutter/releases/download/v1.0.1/Mobile-Matrix-macos-arm64.zip)

压缩包内包含 `Mobile Matrix.app` 和内置的 STF Lite 运行时。当前版本使用 ad hoc 签名。首次打开时 macOS 可能显示安全提示，请根据系统提示在确认来源可信后允许打开。

### Windows 和 Linux

仓库中包含 Flutter 桌面平台目录，但目前尚未发布或验证可分发的 Windows、Linux 安装包。不要将这些目录当作可以直接交付的正式版本。

### Android

Mobile Matrix 是用于控制 Android 设备的桌面端程序。本仓库目前没有单独发布 Android 手机端应用。

## 使用要求

- 当前发布版本需要 Apple Silicon Mac。
- Android 手机或平板已开启**开发者选项**和 **USB 调试**。
- 使用 USB 连接，并建立已授权的 ADB 连接。
- 首次连接时，在 Android 设备上确认电脑的 RSA 调试授权提示。

## 使用发布包

1. 从 Release 页面下载 macOS arm64 压缩包。
2. 解压 `Mobile Matrix.app`，将其移动到合适的本地应用程序目录。
3. 连接已开启 USB 调试的 Android 设备。
4. 打开应用，并在设备上确认 ADB 调试授权。
5. 在设备选择器中选择设备，开始控制。

## 本地开发

这是一个 Flutter 桌面项目，运行方式如下：

```bash
flutter pub get
flutter run -d macos
```

如需检查其他桌面平台，请先确认对应平台的运行时和内置 STF Lite 资源，再使用对应的 Flutter 设备目标运行。

## 架构说明

桌面 UI 通过 ADB 与 Android 设备通信。实时投屏和输入能力由本地 STF Lite 集成及其内置运行时资源提供。平台专属代码位于 Flutter 桌面应用边界内，未验证的平台能力不会被展示为已支持功能。

## 项目状态

macOS arm64 版本已经发布到 GitHub。实际功能表现取决于 Android 设备、ADB 授权状态和本地 STF Lite 运行时。欢迎通过 [GitHub Issues](https://github.com/LiveSalton/mobile_matrix_flutter/issues) 提交可复现的问题和设备兼容性案例。

## 许可证

重新分发应用包前，请查看仓库许可证和第三方声明。
