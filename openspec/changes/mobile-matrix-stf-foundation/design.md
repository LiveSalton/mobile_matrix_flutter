## Context

Mobile Matrix 已在 arm64 Mac 上通过 STF `3.7.9` 和宿主机 ADB 完成单设备验证。当前仓库另有一个 Fastify 适配层，启动时会在 STF `7100` 之外按 Token 条件启动 `7121`。用户已确认将产品控制面直接合并到 STF Web 控制台，不再运行额外服务，并去掉对本机单用户场景无价值的登录页面。

项目主题的唯一事实源是 `doc/project-theme.md`；`ui-ux-pro-max` 只提供密度、层级、反馈、可访问性和交互规范。颜色只允许液态玻璃蓝 `default` 与玫瑰流光 `roseGlow` 两套语义 token。

## Goals / Non-Goals

**Goals:**

- 仓库直接包含 STF `v3.7.9` 源码并从该源码启动。
- 默认只运行一个由 `launchctl` 托管的 STF 进程树，对外入口固定为 `7100`。
- 浏览器无需登录，服务端自动建立固定本地身份和 STF 会话。
- `/` 直接显示响应式设备矩阵，保留单设备控制链路。
- 支持显式多选、批量占用/释放、加载态、逐台结果和部分失败。
- 两套主题共用一份页面和组件，通过 `data-mm-theme` 与语义 token 切换。
- 在不伪造设备的前提下完成静态、单元、构建和单机运行验证。

**Non-Goals:**

- 不提供公网匿名访问、多租户身份隔离或细粒度权限。
- 不删除既有 Fastify 源码和历史证据，只退出默认运行链路。
- 不实现批量远程连接、批量安装、Airtest、AI Agent 或 iOS。
- 不修改 Provider、ADB、STFService、minicap 或 minitouch 协议。

## Decisions

### 1. STF 源码成为唯一默认运行时

```text
浏览器
  │
  ▼
STF Poorxy :7100
  ├─ App + Mobile Matrix 设备首页
  ├─ WebSocket + 透明本地身份
  ├─ STF API / Storage / Processor
  └─ Provider ── host ADB ── Android 真机

RethinkDB 继续由本机辅助容器承载
```

`mobile-matrix.sh` 只创建一个 STF `launchctl` 服务；STF 内部子进程仍属于同一运行时。根目录 `src/` 不再构建或启动，`7121` 不再监听。这样页面、实时状态和租约操作保持同源，也避免浏览器接触 STF Token。

Mac 回环约束：`stf local` 的 provider、WebSocket 和截图存储插件之间不得硬编码 `localhost`。启动参数 `--public-ip 127.0.0.1` 作为内部 HTTP 链路主机名；截图处理器直连 7102 存储端口，并在没有裁剪参数时透传原始 JPEG，避免 macOS 回环解析和 ImageMagick 流处理造成 `/s/image/*` 请求超时。

### 2. 直接复制固定上游 tag

源码目录固定为 `vendor/devicefarmer-stf/`，来源为 GitHub `DeviceFarmer/stf` tag `v3.7.9`。保留 `LICENSE`、版权头和上游目录；排除 `.git` 与依赖缓存。`MOBILE_MATRIX_CHANGES.md` 记录来源 commit、复制日期、免登录、主题、页面和启动改动。

首次启动如果 vendor 依赖不存在，脚本在 Node.js 20 环境中执行 vendor 安装；后续直接复用本地依赖。依赖目录由根 `.gitignore` 排除。

### 3. 免登录采用透明固定身份，而不是删除身份模型

STF 的 WebSocket、设备组和租约逻辑依赖用户。直接删除身份会破坏设备占用与释放，因此新增显式 `no-auth` 本地配置：

- App 鉴权中间件在 `no-auth` 时使用固定 `administrator@fakedomain.com` / `administrator` 身份。
- 中间件通过 STF `dbapi.saveUserAfterLogin` / `loadUser` 保证用户存在，并把相同身份写入 cookie session。
- WebSocket 继续读取同一 session JWT，原有所有权和管理员语义不变。
- `stf local` 的 Mobile Matrix 默认启动参数启用 `no-auth`，并不启动 Mock Auth 子进程。
- 非 `no-auth` 模式继续保留上游登录流程，便于回退和未来重新启用认证。

该模式等价于“可信环境中的单一管理员会话”，不是无身份或安全匿名模式。启动说明必须明确禁止公网暴露。

### 4. 首页直接使用实时 STF 设备集合

AngularJS 路由继续以 `/devices` 为设备列表状态，根路由默认跳转该页面；服务端 `/` 首次返回 App shell 后不出现登录页。设备页通过现有 `DeviceService.trackAll` 和 WebSocket 获取设备，不从本地缓存宣称在线。

首页采用设备优先的紧凑控制台，不再使用大 Hero 和四张独立统计卡：

1. 顶部栏：Mobile Matrix、单行连接摘要、主题切换和搜索入口。
2. 工具栏：批量选择按钮；只有进入多选后才显示已选数量和批量动作。
3. 设备矩阵：使用 STF `screen.capture` 的静态当前屏幕截图作为封面，补充名称、状态文字、serial 摘要和明确选择控件，默认立即进入首屏。
4. 结果反馈：使用轻量状态提示，不在正常状态长期占据页面空间。
5. 单机详情：点击设备卡进入现有控制面板，首页不再用 Details 标签重复占据空间。

STF 原生 `menu.pug` 顶部导航不再挂载到 App shell；Mobile Matrix 标题栏是首页唯一的顶层栏，避免同时出现 STF 和产品两套标题体系。

截图策略：设备列表首次出现设备时执行一次按设备截图；截图完成后只保留当前静态 URL，不订阅屏幕 WebSocket，也不设置定时器。标题栏的“刷新截图”按钮重新对当前设备集合调用 `ControlService.screenshot()`，按钮在请求期间禁用并显示进度；单台截图失败时保留该设备的 STF 默认封面并统计失败数量，不影响其他设备。

统计兼容：顶部仅展示总数、可用和忙碌三个数字；旧 STF 统计指令仍可能尝试更新“使用中”节点，必须在节点缺失时跳过该更新，不能中断 tracker 的设备新增事件。

点击未处于多选交互的设备卡仍进入现有 `/control/:serial` 单机页面。

### 5. 批量操作复用 STF GroupService

控制台不引入第二套租约 API。批量占用逐台调用 `GroupService.invite(device)`，批量释放逐台调用 `GroupService.kick(device)`；使用固定并发上限，保持每台独立结果。一台失败不会取消其他目标。

选择只存在当前页面内存：刷新、离开设备页或退出多选模式即清空。提交期间按钮进入 loading/disabled 状态，防止重复操作。结果对象至少包含 `serial`、`status` 和安全错误文案，不记录 Token、ADB key 或远程地址。

### 6. 双主题与设计约束

页面根元素使用 `data-mm-theme`，只接受 `default`、`roseGlow`；其他存储值回退 `default`。主题偏好可保存在浏览器 `localStorage`，但不得保存设备租约、选择状态或远程连接信息。首页文本默认可选择复制；仅按钮、选择控件和拖拽区域禁止文本选择。

实现只使用 `--mm-*` 语义 token；共享成功、警告、错误、禁用色不随主题变化。采用 4/8/16/24/32/48 间距、8/12/16 圆角、150–300ms 轻量反馈、可见键盘焦点与 `prefers-reduced-motion`。设备状态同时使用文字/图标与颜色，不能只靠颜色表达。

品牌图标采用模块化像素单元组成的字母 M，表达设备矩阵与集中控制；蓝色版本以单个绿色单元表示已连接状态，玫瑰版本保持相同结构并使用玫瑰流光配色。`mobile-matrix-1024.png` 与 `mobile-matrix-1024-rose.png` 是保留圆角边框、内部底板且外部透明的不可覆盖母版；项目从母版等比导出对应主题的 512px 与 128px PNG。128px 资源用于设备首页标题栏、favicon 与 Apple Touch Icon，512px 资源用于全局导航和登录页；默认 `/favicon.ico` 路由指向蓝色 128px 资源，主题服务在切换时同步更新标题栏与 favicon 到对应主题的独立资源，不使用混合模式或滤镜近似变色。远程网址的 48px 默认站点图标不属于产品品牌资源，保持不变。

Socket 断线弹窗使用独立的 `mm-socket-modal` 样式：弹窗宽度响应式限制在 520px，采用 `--mm-surface-elevated` / `--mm-surface` 玻璃层、`--mm-outline` 边界、16px 圆角和语义化 `--mm-danger` 标题；正文、关闭按钮和重连按钮分别使用文本次要色、主色与最小 40px 点击高度。断线、关闭和重连行为沿用现有 STF 服务，不改变连接状态机。

### 7. 错误、安全与诊断

- 7100 根页面、`/app/api/v1/state.js`、WebSocket 和 Provider/ADB 日志分别构成运行诊断链路。
- 透明本地身份启动失败时页面不得伪装可用，启动日志需保留不含凭据的错误原因。
- Token、ADB key、cookie secret、完整远程地址不得进入普通日志或页面持久化。
- 免登录模式只绑定 `127.0.0.1`；若未来扩展可信内网或公网，必须另立 change 恢复真实认证和权限模型。

## Risks / Trade-offs

- [vendor STF 依赖安装较慢] → 首次启动安装，后续复用；固定 tag 并记录来源。
- [透明管理员身份降低安全边界] → 仅绑定本机，文档明确禁止公网；保留原登录模式作为回退。
- [旧 AngularJS 页面和手工 DOM 渲染难测试] → 把主题状态和批量调度拆成小服务，页面只负责绑定；为服务和关键 controller 行为补单元测试。
- [两套主题的玻璃透明度影响可读性] → 使用语义表面层、明确边框和 WCAG 对比检查，不额外降低正文透明度。
- [第二台真机未就绪] → 双机、部分失败和拔线恢复的真实证据保持未完成，不能用模拟测试替代。

## Migration Plan

1. 更新 OpenSpec 和实施计划，固定单运行时、透明身份、设备首页与双主题契约。
2. 复制 STF `v3.7.9` 源码并记录上游来源。
3. 测试先行实现 `no-auth` 中间件与 local/app CLI 透传。
4. 测试先行实现主题状态、设备矩阵页面和批量操作服务。
5. 修改 `mobile-matrix.sh`，停止旧 API launch service，仅启动 vendor STF。
6. 执行 vendor 定向测试、构建、根项目检查、OpenSpec 严格校验和单机 7100 运行验证。
7. 第二台真机到位后补双机批量与拔线恢复证据。

## Open Questions

- 第二台用于真实批量验收的 Android 手机和 USB Hub 何时可用？
- 未来若从本机扩展到可信局域网，是否恢复登录，还是采用反向代理统一身份？该问题不阻塞当前本机实现，必须另立 change。
