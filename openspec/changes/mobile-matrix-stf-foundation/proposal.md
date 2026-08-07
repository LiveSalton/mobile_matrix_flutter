## Why

Mobile Matrix 已用 DeviceFarmer STF `3.7.9` 验证单台 Android 真机的发现、占用、释放和远程连接。现有形态同时运行 STF 控制台与独立 Fastify 控制面，浏览器还需要经过 STF Mock 登录；这增加了端口、身份和运维复杂度，却没有给当前本机单用户场景带来实际价值。

本次把 STF 源码直接纳入仓库，并把 Mobile Matrix 的设备矩阵、多选群控和主题能力合并到 STF Web 控制台。默认只暴露 STF `7100`，打开首页直接进入设备列表，通过服务端透明本地身份维持 STF 原有租约语义，不再显示登录页。

## What Changes

- 将 DeviceFarmer STF `v3.7.9` 发布源码直接复制到 `vendor/devicefarmer-stf/`，保留上游许可证并记录本项目改动。
- 根目录 `mobile-matrix.sh` 改为只托管仓库内 STF；不再启动独立的 Mobile Matrix Fastify 服务和 `7121` 端口。
- 为本机/可信内网配置透明固定身份：浏览器无需输入账号密码，STF 内部仍保留用户、租约、WebSocket 会话和所有权语义。
- STF `/` 直接进入 Mobile Matrix 设备优先的紧凑设备矩阵首页，保留单设备远程控制入口。
- 设备首页支持单行连接摘要、设备搜索、显式多选、批量占用、批量释放、逐台结果与失败反馈；移除大 Hero、重复统计卡和常驻详情标签。
- 首页设备名称、型号、状态和 serial 默认允许浏览器复制，按钮和选择控件保持不可选。
- 精简统计摘要时兼容 STF 旧统计指令，缺少“使用中”节点不得中断设备 tracker 事件。
- 设备卡片封面改为 STF `screen.capture` 产生的静态当前屏幕截图；首次加载获取一次，标题栏刷新按钮才重新截取，不建立动态轮询。
- 移除 STF 原生顶部导航栏，首页只保留 Mobile Matrix 自己的紧凑标题栏。
- 修正 Mac 本地 STF 内部存储链路，统一使用 `--public-ip` 生成回环地址；截图处理器直连 7102 存储端口并透传无变换 JPEG，避免截图资源超时。
- 主题严格使用 `doc/project-theme.md` 和 `design-system/mobile-matrix/theme.css`：仅支持液态玻璃蓝 `default` 与玫瑰流光 `roseGlow`，未知值回退 `default`。
- 将 STF 文字图标替换为 Mobile Matrix 像素矩阵 M 品牌图标，并复用同一母版导出浏览器与侧栏所需尺寸。
- 品牌图标保留蓝色与玫瑰流光两张 1024px 透明 PNG 母版，等比导出 512px / 128px 运行资源；标题栏不叠加额外边框并直接切换对应主题资源，不使用滤镜近似变色。
- 移除运行时对 `STF-128.png` / `STF-512.png` 的品牌入口，改用明确的 `mobile-matrix-*` 资源名并显式声明网页 favicon。
- 复用 STF 的实时设备状态和既有 `GroupService` 租约操作，不建立第二套设备状态或租约数据库。
- 保留根目录既有 `src/` Fastify 代码作为已验证历史基线，但不进入默认启动链路，也不再作为产品控制面。

非目标：

- 不实现公网或不可信网络下的匿名访问；免登录只适用于本机/可信内网单身份部署。
- 不实现 Airtest、抖音流程、AI Agent、任务编排、iOS/WDA、批量安装应用或批量远程连接。
- 不重写 STF Provider、ADB、minicap、minitouch 或 STFService。
- 不新增第三套主题，不复制两份页面实现主题切换。
- 不使用模拟设备、模拟画面或本地计时器证明真实设备能力。

回退方式：如果仓库内 STF 或新版设备首页破坏既有单机能力，恢复 `mobile-matrix.sh` 对外部 STF `3.7.9` 的调用，并停用 vendor 改造；RethinkDB 数据、宿主机 ADB 和既有实验性 Fastify 源码保持可恢复，不用模拟状态替代运行证据。

## Capabilities

### New Capabilities

- `stf-web-console`: 仓库内 STF 单运行时、免登录本地身份、默认设备矩阵首页和双主题控制台。

### Modified Capabilities

- `stf-device-management`: 默认交互入口从独立 Mobile Matrix API 调整为 STF 同源 Web 控制台与 WebSocket；STF 继续作为设备状态与租约唯一事实来源。
- `multi-device-batch-operations`: 批量操作合并到 STF 控制台，逐台复用 STF 既有占用/释放语义，不再依赖额外服务。
- `stf-runtime-diagnostics`: 默认运行诊断改为 STF `7100`、页面状态脚本、WebSocket、Provider/ADB 与启动日志，不再依赖 `7121 /health`。

## Impact

- 新增 `vendor/devicefarmer-stf/` 上游源码与 Mobile Matrix 改动记录。
- 修改 STF app 鉴权中间件、local/app CLI 参数、设备列表页面、主题状态与批量操作逻辑。
- 替换 STF 控制台现有 `STF-128.png` 与 `STF-512.png` 品牌资源，不改变资源引用路径或远程网址默认图标。
- 修改根启动脚本、Mac 运行说明、OpenSpec 规格和验证记录。
- 默认产品入口只有 `http://127.0.0.1:7100/`；首次打开和刷新都直接显示设备矩阵。
- 透明本地身份具有当前 STF 本地管理员能力，因此部署边界必须保持本机或可信内网，禁止默认暴露公网。
- 真实双设备、批量真机和拔线恢复仍需第二台 Android 手机，相关任务在取得证据前保持未完成。
