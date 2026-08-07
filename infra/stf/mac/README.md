# Mac 原生 STF 验证运行手册

本目录只描述开发验证路径，不代表 STF 已经在本机启动，也不替代真实设备证据。

## 一键后台启动

完成下方依赖安装后，可在仓库根目录直接运行：

```bash
./mobile-matrix.sh
```

脚本每次执行都会重启本项目的 RethinkDB 和内置 STF，并使用 macOS `launchctl` 在后台托管；关闭终端不会停止服务。日志与 PID 位于被忽略的 `.runtime/`。STF Web 控制台固定为 `http://127.0.0.1:7100/`，首页直接进入 Mobile Matrix 设备矩阵，不再额外启动 7121 API 服务。

当前脚本仅支持 macOS。Windows 原生和 WSL2 启动方式尚未验证，不能标记为已支持。

## 运行边界

- 目标环境：当前 arm64 Mac、本机或可信内网。
- 设备接入：宿主机 ADB 直接访问 USB Android 手机。
- STF：固定 `@devicefarmer/stf@3.7.9`，Provider 使用宿主机 ADB。
- RethinkDB：原生运行或单独 Docker 容器，不能让 Docker Desktop USB 直通成为前置条件。
- Mobile Matrix：直接改造内置 STF Web 控制台，通过受信任本地身份进入，默认只监听 `127.0.0.1`。
- 长期生产：迁移到连接实体 USB 设备的 Linux 设备主机；Mac 结果只作为开发/验证证据。

## 前置检查

建议使用隔离的 Node.js 20 LTS，不覆盖系统 Node.js 22：

```bash
node --version
npm --version
uname -m
adb version
adb start-server
adb devices -l
```

设备必须显示为 `device`，`unauthorized`、`offline` 或空列表都不能进入 STF 设备验收。

DeviceFarmer README 列出的 Mac 原生依赖包括 RethinkDB、GraphicsMagick、ZeroMQ、Protocol Buffers、yasm、pkg-config 和 CMake。按本机包管理器安装，并在证据中记录实际版本；不要把包管理器缓存或本机路径提交到仓库。

## 内置 STF

源码固定放在 `vendor/devicefarmer-stf`，启动脚本会自动安装依赖、构建 Web 控制台，并以受信任本地身份启动：

```bash
./mobile-matrix.sh
```

STF 启动后，浏览器直接打开设备矩阵。受信任本地身份只允许回环地址使用，不产生浏览器登录页，也不代表远程部署可以匿名访问。

若不希望原生安装 RethinkDB，可只将 RethinkDB 作为非 USB Docker 容器运行，并让宿主机 STF 通过 `127.0.0.1:28015` 连接；不得使用 `devicefarmer/adb` 容器假设 Mac 能直接透传 USB。

## Mac 限制与回退

Docker Desktop 在 macOS 上不提供直接 USB 设备透传。USB/IP 是额外实验路径，不作为首轮验收依赖。如果宿主机 STF/ADB 在多设备或 USB Hub 下不稳定，保留 Mobile Matrix 的 API、设备模型和错误契约，把 STF Provider 迁移到 Linux 设备主机；不得用模拟设备或模拟画面替代运行证据。
