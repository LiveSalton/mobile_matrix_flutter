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
- **THEN** 首页展示该设备的机型、连接状态与控制入口；卡片状态按钮显示“已连接 · 可控制”，且状态来源为 STF 实时数据

#### Scenario: 设备连接状态变化
- **WHEN** STF 实时设备状态在可用、使用中、忙碌、断开、未授权或自动化执行中之间变化
- **THEN** 首页卡片的状态按钮 SHALL 同步更新中文状态文案、图标、颜色与可点击性，不显示 STF 遗留的 `Use` 文案

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

#### Scenario: 手机预览保持统一比例
- **WHEN** 首页渲染任意设备的当前屏幕截图
- **THEN** 设备卡片按真机 9:20 纵向圆角比例显示，当前屏幕截图与卡片边界和圆角完全重合并铺满背景；设备名称、serial 与连接状态按钮全部位于屏幕内底部的完全不透明控制浮层，异步更新不得引起网格跳动

#### Scenario: 顶层导航保持单一
- **WHEN** 用户打开 Mobile Matrix 首页
- **THEN** 不显示 STF 原生顶部导航栏，只显示 Mobile Matrix 标题栏及其刷新、主题和状态摘要

#### Scenario: 部分设备截图失败
- **WHEN** 某台设备截图失败而其他设备截图成功
- **THEN** 成功设备更新封面，失败设备显示中性空白封面和状态文字，不渲染 STF 默认手机展位图，不阻塞设备矩阵和其他截图结果

#### Scenario: Mac 本地截图资源可返回
- **WHEN** STF 运行在 macOS，用户刷新可用设备截图
- **THEN** 截图处理器通过 127.0.0.1 直连本地存储端口，并返回可加载的 JPEG 资源，不因 `localhost` 或不必要的二次转换而挂起

#### Scenario: 精简统计不阻断设备事件
- **WHEN** 首页只渲染总数、可用和忙碌统计，旧 STF 指令仍收到设备新增事件
- **THEN** 缺少“使用中”统计节点时跳过该节点更新，设备卡片和截图流程仍正常执行

### Requirement: 单设备控制页 SHALL 使用统一工作台布局
控制页 SHALL 保留 STF 既有单设备控制能力，并 SHALL 以设备主舞台和单一双模式工作区组织页面；右侧默认提供群控执行布局，现有 STF 工具通过分类入口访问，不重复渲染同一组工具标签。

#### Scenario: 打开可控制设备
- **WHEN** 用户进入 `/control/:serial` 且 STF 已建立该设备的控制会话
- **THEN** 左侧显示设备名称、旋转、屏幕显隐、释放、实时屏幕与 Android 导航控制，右侧默认显示“选择设备 / 配置操作 / 确认执行”三步群控布局，并把当前控制设备自动显示为目标设备

#### Scenario: Airtest 执行引擎尚未接入
- **WHEN** 用户查看群控执行布局且当前 change 未提供 Airtest 执行能力
- **THEN** 只有选择设备步骤可用，配置操作和确认执行明确禁用并显示未接入说明，页面不提供可产生模拟结果的执行按钮、进度或虚构参数

#### Scenario: 查看现有设备工具
- **WHEN** 用户从群控执行切换到设备工具
- **THEN** 页面按常用操作、记录诊断和设备管理分类显示 Dashboard、Logs、Screenshots、Automation、File Explorer、Advanced 与 Info，且每次只挂载当前选择的工具内容

#### Scenario: 切换右侧工作模式
- **WHEN** 用户在群控执行和设备工具之间切换
- **THEN** 左侧设备屏幕、控制会话和租约保持不变，右侧模式状态不写入持久化存储

#### Scenario: 宽桌面视口
- **WHEN** 控制页视口宽度大于 1200px
- **THEN** 设备主舞台宽度限制在 480px 以内，右侧工作区使用剩余空间；设备工具内容使用最大 1180px 的响应式卡片网格，不因百分比窗格产生过宽手机区或长期空白底栏

#### Scenario: 紧凑控制页视口
- **WHEN** 右侧工作区不足以同时容纳分类侧栏和工具内容
- **THEN** 设备工具分类折叠为顶部可滚动导航，群控步骤和内容保持单列可读且不横向溢出

#### Scenario: 控制页图标渲染
- **WHEN** 控制页显示设备工具栏、导航键、标签、卡片标题或操作按钮
- **THEN** 功能性 UI 图标使用本地 Material Design Icons Round，且不依赖运行时外网字体；浏览器 favicon、App 图标和真机画面内容保持原始资产

#### Scenario: 控制平台尚未初始化
- **WHEN** 用户首次进入控制页且 `$root.platform` 不是 `native` 或 `web`
- **THEN** 页面初始化为 `native` 并显示可用工具标签，不因设备平台值 `Android` 导致标签导航隐藏

### Requirement: Dashboard SHALL 按任务层级组织既有设备工具
单设备控制页的 Dashboard SHALL 使用一个连续表面，并按 Quick Controls、Applications、Developer 三个任务组组织 Navigation、Clipboard、Shell、App Upload、Apps 与 Remote debug；不得重复左侧设备信息，不得删除或复制既有控制器、事件和功能入口。

#### Scenario: 打开 Dashboard
- **WHEN** 用户在设备工具中打开 Dashboard
- **THEN** 页面不再渲染重复的 Dashboard 大标题、设备名称、serial 或状态卡，所有工具位于一个连续表面，并按即时控制、应用管理和开发信息分组

#### Scenario: Dashboard 窄工作区
- **WHEN** 右侧工作区不足以并列容纳同组工具
- **THEN** 工具回退为单列，标题、图标、内容和动作保持对齐，不产生横向溢出、边框嵌套或工具重叠

#### Scenario: Dashboard 主题与功能保持不变
- **WHEN** 用户在 `default` 或 `roseGlow` 主题下操作 Dashboard 的输入框、按钮、拖拽区或控制器动作
- **THEN** 页面只切换既有语义 token 的表面与强调层级，所有既有 STF 事件、控制器和操作结果保持不变

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

#### Scenario: 控制中的设备离线
- **WHEN** STF 设备状态变化触发 `FatalMessage` 设备离线弹窗
- **THEN** 弹窗使用当前 Mobile Matrix 主题、Material 图标和紧凑设备状态卡，不显示默认手机展位图；“返回设备列表”和“重新连接”保持原有行为且触达高度不少于 44px
