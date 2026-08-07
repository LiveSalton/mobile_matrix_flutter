## ADDED Requirements

### Requirement: 默认部署 SHALL 只运行仓库内 STF 控制面
Mobile Matrix 默认启动 SHALL 使用 `vendor/devicefarmer-stf` 中固定的 STF `v3.7.9` 源码，并 SHALL NOT 启动独立 Fastify 控制面或监听 `7121`。

#### Scenario: 运行根启动脚本
- **WHEN** 用户执行 `mobile-matrix.sh`
- **THEN** 脚本重启仓库内 STF 运行时并提供 `http://127.0.0.1:7100/`，且不启动 Mobile Matrix API launch service

#### Scenario: vendor 源码缺失
- **WHEN** 根启动脚本找不到 `vendor/devicefarmer-stf/bin/stf`
- **THEN** 脚本明确失败并指出仓库源码缺失，而不是回退到不确定版本的全局 `stf`

### Requirement: 本地控制台 SHALL 无登录直达设备列表
受信任本地配置 SHALL 通过固定服务端身份建立 STF 用户与 WebSocket 会话，浏览器 SHALL NOT 显示或要求提交登录账号密码。

#### Scenario: 首次打开控制台
- **WHEN** 浏览器没有既有 STF session 并请求 `/`
- **THEN** 服务端建立固定本地身份，页面加载后进入 `/devices`，不重定向到 `/auth/mock/`

#### Scenario: WebSocket 建立连接
- **WHEN** 无登录页面的浏览器连接 STF WebSocket
- **THEN** WebSocket 从同一 cookie session 解析固定身份并继续使用 STF 原有租约所有权语义

#### Scenario: 非本地免登录配置
- **WHEN** 未显式启用 `no-auth` 配置
- **THEN** STF 保留原有认证中间件行为，不静默绕过配置的认证系统

### Requirement: 首页 SHALL 是 Mobile Matrix 设备矩阵
控制台 SHALL 以实时 STF 设备集合渲染设备优先的紧凑首页，包含单行连接摘要、搜索、明确状态文字、设备卡和单设备控制入口；正常状态不得展示大 Hero、重复统计卡或独立详情标签。

#### Scenario: STF 报告可用设备
- **WHEN** WebSocket 设备跟踪器收到可用设备
- **THEN** 首页展示该设备的机型、状态与控制入口，且状态来源为 STF 实时数据

#### Scenario: 没有设备
- **WHEN** STF 当前没有可展示设备
- **THEN** 首页显示可操作的空状态说明，不渲染伪造设备或模拟画面

#### Scenario: 小尺寸浏览器
- **WHEN** 视口宽度为 375px
- **THEN** 状态卡、工具栏和设备矩阵自适应单列或紧凑布局，主要操作仍可见且不横向溢出

#### Scenario: 复制设备信息
- **WHEN** 用户在首页拖选设备名称、型号、状态或 serial
- **THEN** 浏览器允许复制选中文本；按钮和选择控件本身不参与文本拖选

#### Scenario: 设备封面使用静态屏幕截图
- **WHEN** 首页首次收到设备，或用户点击标题栏“刷新截图”
- **THEN** 控制台通过 STF `screen.capture` 获取该设备当前屏幕的一张静态图片并展示，不建立动态屏幕流或定时轮询

#### Scenario: 顶层导航保持单一
- **WHEN** 用户打开 Mobile Matrix 首页
- **THEN** 不显示 STF 原生顶部导航栏，只显示 Mobile Matrix 标题栏及其刷新、主题和状态摘要

#### Scenario: 部分设备截图失败
- **WHEN** 某台设备截图失败而其他设备截图成功
- **THEN** 成功设备更新封面，失败设备保留 STF 默认封面并显示失败数量，不阻塞设备矩阵和其他截图结果

#### Scenario: Mac 本地截图资源可返回
- **WHEN** STF 运行在 macOS，用户刷新可用设备截图
- **THEN** 截图处理器通过 127.0.0.1 直连本地存储端口，并返回可加载的 JPEG 资源，不因 `localhost` 或不必要的二次转换而挂起

#### Scenario: 精简统计不阻断设备事件
- **WHEN** 首页只渲染总数、可用和忙碌统计，旧 STF 指令仍收到设备新增事件
- **THEN** 缺少“使用中”统计节点时跳过该节点更新，设备卡片和截图流程仍正常执行

### Requirement: 控制台 SHALL 支持两套项目主题
页面 SHALL 只允许 `default` 液态玻璃蓝和 `roseGlow` 玫瑰流光主题，并 SHALL 通过 `doc/project-theme.md` 定义的语义 token 渲染同一份页面。

#### Scenario: 切换到玫瑰流光
- **WHEN** 用户选择 `roseGlow`
- **THEN** 根元素设置 `data-mm-theme="roseGlow"`，页面使用玫瑰流光 token 且不重建或复制设备页面

#### Scenario: 存储了未知主题值
- **WHEN** 本地存储的主题键不是 `default` 或 `roseGlow`
- **THEN** 页面安全回退 `default` 并保持文本、边框和焦点可读

#### Scenario: 用户偏好减少动画
- **WHEN** 浏览器启用 `prefers-reduced-motion: reduce`
- **THEN** 控制台关闭非必要过渡而不影响状态反馈和操作完成提示
