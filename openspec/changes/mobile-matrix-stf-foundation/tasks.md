## 1. 项目与运行配置

- [x] 1.1 建立 Mobile Matrix 控制面最小目录、Node.js 20 LTS 运行约束和 TypeScript 编译/检查入口；验证不覆盖系统 Node.js 22
- [x] 1.2 定义 STF `3.7.9`、STF_BASE_URL、STF_TOKEN、超时、并发和日志脱敏配置契约；确认 secret 不进入版本库
- [x] 1.3 编写 Mac 原生 ADB/STF 验证运行说明；明确宿主机 ADB、RethinkDB、STF Provider 和 Docker Desktop 无 USB 直通的边界
- [x] 1.4 增加根目录一键后台重启脚本；验证重复执行会重启项目服务、关闭终端不影响运行，并明确 Windows 尚未支持

## 2. STF 适配与设备模型

- [x] 2.1 实现 STF REST 客户端，封装设备列表、单设备查询、占用、释放和远程连接请求
- [x] 2.2 实现统一设备模型和 `present`、`ready`、`using`、`owner` 到 `ready`、`busy`、`offline`、`unavailable`、`unknown` 的状态映射
- [x] 2.3 为 STF 响应、超时、非 2xx 和无效 JSON 建立可测试的适配器错误类型，并保留安全诊断上下文
- [x] 2.4 实现 `GET /api/v1/devices` 与 `GET /api/v1/devices/:serial`；验证设备状态来自 STF 而非陈旧本地缓存

## 3. 单设备操作 API

- [x] 3.1 实现 `POST /api/v1/devices/:serial/lease`，处理可用、离线、未就绪、忙和 STF 鉴权失败场景
- [x] 3.2 实现 `DELETE /api/v1/devices/:serial/lease`，校验当前客户端所有权并保持释放幂等
- [x] 3.3 实现 `POST /api/v1/devices/:serial/remote-connect`，返回当前会话临时地址并禁止持久化敏感值
- [x] 3.4 为单设备接口补充输入校验、稳定错误码和不泄露 Token/ADB key/完整连接地址的响应与日志规则

## 4. 批量操作

- [x] 4.1 实现 serial 列表校验，拒绝空列表、重复 serial 和无效输入，不在校验失败时调用 STF
- [x] 4.2 实现 `POST /api/v1/batch/lease`，逐台执行并返回 `accepted`、`succeeded`、`failed` 与每台错误原因
- [x] 4.3 实现 `POST /api/v1/batch/release`，只释放当前客户端持有的租约并保留其他目标结果
- [x] 4.4 增加有上限的并发、超时和查询重试；对不确定的租约操作先重查 STF，禁止盲目重复变更
- [x] 4.5 为一台忙/离线/超时而其他设备成功的场景生成 `partial_failure`，并完成适配器级测试

## 5. 健康检查与诊断

- [x] 5.1 实现 `GET /health`，分别报告控制面、STF API、Provider/ADB 和鉴权配置状态
- [x] 5.2 固定并验证 `stf_unreachable`、`provider_unavailable`、`device_offline`、`device_not_ready`、`device_busy`、`auth_failed`、`operation_timeout`、`partial_failure`
- [x] 5.3 实现统一日志脱敏和错误序列化；确认 Token、ADB key、凭据和不必要的完整远程地址不出现在日志或错误正文
- [x] 5.4 增加服务自身的单元/契约检查，覆盖正常 STF 响应、认证失败、依赖不可达和部分批量失败

## 6. Mac 真机与多设备验收

- [x] 6.1 在当前 arm64 Mac 上以宿主机 ADB 识别并授权第一台 Android 真机，记录 ADB 与 STF 设备列表证据
- [x] 6.2 启动固定版本 STF，验证第一台设备可在 STF 中显示、占用、释放并建立远程连接
- [ ] 6.3 接入第二台 Android 真机，验证两台设备同时列出、状态独立且 Mobile Matrix API 能读到两台设备
- [ ] 6.4 通过 Mobile Matrix 完成单设备占用/释放和两台设备批量占用/释放，保存逐台成功与失败结果
- [ ] 6.5 拔掉一台设备并重新查询，验证该设备进入离线/不可用，另一台设备仍可操作；记录恢复或重连结果
- [x] 6.6 验证 STF 不可达、Token 错误、设备忙和 Docker 无 USB 直通时的明确错误/降级，不以模拟状态替代

## 7. 进度与交付记录

- [x] 7.1 将实现文件、配置、运行命令、测试结果和真实设备证据回写到本 change 的相关工件
- [x] 7.2 执行 OpenSpec 严格校验、格式/类型检查和 API 契约检查，修复所有规范错误
- [x] 7.3 完成 requirement-by-requirement 验收审计；未有真实证据的条目保持未完成，并记录阻塞原因

## 8. STF 单运行时与新版控制台

- [x] 8.1 将 DeviceFarmer STF `v3.7.9` 源码复制到 `vendor/devicefarmer-stf/`，保留许可证并记录上游 commit 与 Mobile Matrix 改动边界
- [x] 8.2 测试先行实现可信本地 `trusted-local` 固定身份，验证首次访问不跳登录、session 可供 WebSocket 使用且默认模式保持原行为
- [x] 8.3 测试先行实现 `default` / `roseGlow` 主题状态与未知值回退，并把主题 token 接入 STF App shell
- [x] 8.4 按 `ui-ux-pro-max` 与项目主题规范重做设备矩阵首页，完成状态概览、搜索、响应式卡片、焦点态、空状态和单机控制入口
- [x] 8.5 测试先行实现设备多选与批量占用/释放，验证固定并发、重复提交保护、逐台结果、部分失败和退出多选清空选择
- [x] 8.6 修改 `mobile-matrix.sh` 只启动仓库内 STF，停止并移除旧 API launch service，确认 7121 不再由本项目启动且关闭终端不影响 7100
- [x] 8.7 执行 vendor 定向测试与构建、根项目检查、OpenSpec 严格校验和单机 7100 运行验证；双设备真实证据仍由 6.3–6.5 跟踪
- [x] 8.8 精简设备首页为顶部栏、工具栏和设备矩阵，移除大 Hero、重复统计卡与常驻详情标签
- [x] 8.9 修复首页文本选择与复制，保留按钮/选择控件的不可选交互边界，并完成构建与 7100 验证
- [x] 8.10 生成并选定 Mobile Matrix 像素矩阵 M 品牌图标，替换 STF 128px/512px 品牌资源，统一接入标题栏、全局导航、登录页和浏览器图标并完成静态检查
- [x] 8.11 移除标题栏品牌图标外部边框，并通过主题 token 在 `default` 与 `roseGlow` 下切换图标主色
- [x] 8.12 将品牌资源改名为 `mobile-matrix-128.png` / `mobile-matrix-512.png`，切断旧 STF favicon 路由与缓存入口并完成引用检查
- [x] 8.13 按 Mobile Matrix 主题规范重做 Socket 断线弹窗的玻璃层级、响应式尺寸、语义色、间距和重连按钮，保持连接行为不变
- [x] 8.14 为 `default` / `roseGlow` 生成和切换对应网页 favicon
- [x] 8.16 保留蓝色与玫瑰流光 1024px 透明 PNG 原始母版，等比导出并替换 512px / 128px 项目资源，标题栏直接切换主题资源且不再使用混合模式或滤镜
- [x] 8.10 使用 STF `screen.capture` 替换设备默认封面，首次加载静态截屏并在标题栏增加手动刷新按钮；覆盖部分失败和无动态轮询；截图画面仍需用户在真机页面点击刷新后目视确认
- [x] 8.11 移除 STF 原生顶部导航栏，保留 Mobile Matrix 单一标题栏并完成模板构建验证
- [x] 8.12 修正 Mac STF 内部存储链路的 `localhost` IPv6 解析问题；截图处理器直连 7102 并透传无变换 JPEG，验证静态截图资源可通过 7100 返回
- [x] 8.15 兼容精简统计摘要与 STF 旧统计指令，缺少“使用中”节点时不阻断设备卡片和截图事件
- [x] 8.17 按 `ui-ux-pro-max` 与 `apple-design` 将设备卡片调整为当前截图 9:20 背景比例，移除默认手机展位图，改用底部轻量玻璃渐变信息层，并补齐响应式网格、键盘焦点、44px 选择触达面积和截图替代文本
- [x] 8.18 让截图层与卡片边界和圆角完全重合，移除底部毛玻璃，改用共享语义 token 的中性灰阶渐变保障底部文案可读且减少遮挡
- [x] 8.19 将卡片主题边框改为覆盖在截图上方的描边，避免边框占用布局空间并确保截图与圆角边界完全贴合
- [x] 8.20 移除设备矩阵对 STF 默认手机展位图的封面回退；缺少截图时显示中性空白背景，并重做可用设备操作按钮的主色、圆角和居中对齐
- [x] 8.21 将 `Use` 与 `Disconnected` 统一为同一状态按钮组件，固定宽高和居中规则，并用禁用语义区分不可用状态
- [x] 8.22 将状态按钮调整为信息层底部独占一行，加入统一图标与水平居中排版，去除右侧悬浮式按钮布局
- [x] 8.23 用中文连接状态文案替代 STF 遗留 `Use`，并令按钮与 STF 实时设备状态、图标、可用性同步
- [x] 8.24 采用“屏幕 + 控制底座”卡片结构，将状态按钮、名称和 serial 移出截图层，使用完全不透明的主题底座消除内容重叠
- [x] 8.25 按需求收回屏幕外底座；恢复 9:20 整屏卡片，并用屏幕内不透明控制浮层承载设备信息和状态按钮
- [x] 8.26 将单设备控制页重构为 360–480px 设备主舞台与单一工具工作区，移除重复底部标签窗格并把日志合并到主标签组
- [x] 8.27 引入本地 Material Design Icons Round，将控制页工具栏、Android 导航、标签、卡片与旧 `fa-*` 图标映射为统一 Material 图标
- [x] 8.28 完成控制页双主题、1600px 宽桌面和 1000px 紧凑视口视觉验收；真实设备屏幕流正常显示，七个工具标签均可切换且 Material 图标映射无旧字体残留
- [x] 8.29 重做设备离线 `FatalMessage` 弹窗，移除默认手机展位图，接入双主题、Material 图标、紧凑状态卡和 44px 响应式操作按钮
- [x] 8.30 完成单设备控制页右侧工作区信息架构设计，确认默认群控三步布局、当前设备自动显示、Airtest 未接入边界、顶部双模式入口和设备工具分类侧栏
- [x] 8.31 实现群控执行布局基座；只引用当前 STF 设备状态，禁用未接入的配置与执行步骤，不新增 Airtest API、模拟进度或持久化目标集合
- [x] 8.32 将 Dashboard、Logs、Screenshots、Automation、File Explorer、Advanced 与 Info 收纳到设备工具分类侧栏和单一内容区，保持现有模板、事件与左侧控制会话不变
- [x] 8.33 完成控制页定向静态检查、模板构建和双主题宽/紧凑视口视觉验收；Airtest 真实执行不属于本任务证据
- [x] 8.34 修复 Logs 旧版绝对定位日志层覆盖 Device Tools 工作区的问题，限制其定位上下文并接入主题表面 token
- [x] 8.35 统一 Device Tools 全部页面的图标、文字、按钮和表单控件对齐基线，并修复 Apps 标题区窄列换行时的内容重叠
- [x] 8.36 对 Dashboard 真实页面截图执行 Apple Design 与 ui-ux-pro-max 走查，确认重复页首、嵌套卡片、空间浪费、Apps 层级和操作对齐问题
- [x] 8.37 将 Dashboard 收敛为 Quick Controls、Applications、Developer 三组连续表面，保留既有 STF 模板、控制器与事件并完成模板构建
- [ ] 8.38 在 ADB 设备恢复后补充 Dashboard 默认蓝与玫瑰流光主题的宽/窄工作区真实截图验收
