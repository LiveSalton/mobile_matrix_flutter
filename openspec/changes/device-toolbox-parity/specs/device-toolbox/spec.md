# 设备工具箱功能对齐

## ADDED Requirements

### Requirement: 七组设备工具入口

设备工具箱 SHALL 提供 Dashboard、Logs、Screenshots、Automation、File Explorer、Advanced、Info 七组入口，并且同一时间只在内容区展示当前工具。

#### Scenario: 切换设备工具

- **WHEN** 用户点击任意工具入口
- **THEN** 工具导航保持可见，右侧内容切换到对应工具，内容区可纵向滚动且不产生横向溢出

### Requirement: Dashboard 设备快捷操作

Dashboard SHALL 保留现有物理按键、文本注入、剪贴板和 Shell，并提供应用安装/卸载、应用包列表和 ADB 远程调试入口。

#### Scenario: 执行 Dashboard 操作

- **WHEN** 用户在 Dashboard 执行一个有效操作
- **THEN** 操作通过当前设备的 ADB/STF 服务执行，成功或失败结果在工具箱内可读反馈，不能让后续工具失效

### Requirement: 日志和截图工具

Logs SHALL 支持启动/停止 logcat、关键词/级别过滤、清空显示和复制日志文本；Screenshots SHALL 复用 ADB 截屏并直接复制 PNG 到系统图片剪贴板，不创建桌面截图文件或视频录制任务。

#### Scenario: 复制设备截图

- **WHEN** 用户点击 Screenshots 的截屏按钮且设备在线
- **THEN** 当前设备 PNG 被写入系统图片剪贴板，并显示成功状态

#### Scenario: 停止日志进程

- **WHEN** 用户切换设备或关闭设备控制页
- **THEN** 当前 logcat 子进程被停止，日志流被关闭，不继续读取旧设备输出

### Requirement: 自动化和文件管理

Automation SHALL 支持铃声模式、Wi‑Fi、蓝牙、清理蓝牙配对和打开应用商店；File Explorer SHALL 支持目录浏览、返回上级、查看文件详情和将文件拉取到用户指定的本地路径。

#### Scenario: 浏览目录并拉取文件

- **WHEN** 用户输入有效设备路径并点击进入或拉取
- **THEN** Flutter 通过 ADB 获取目录/文件结果或执行拉取，并在失败时显示可读错误，不产生未处理异常

### Requirement: 高级设备控制

Advanced SHALL 提供 Web 端已有的特殊键、方向键、端口转发和设备重启；网页内 Run JavaScript 与 VNC 不属于桌面 Flutter 的实现范围。

#### Scenario: 创建并移除端口转发

- **WHEN** 用户输入有效本地端口和设备端口并创建/移除转发
- **THEN** Flutter 使用当前设备的 ADB host 命令执行对应操作，并显示命令结果

### Requirement: 设备信息

Info SHALL 读取并展示电池、显示、网络、SIM、硬件、平台、CPU 和内存信息；读取失败的单个字段 SHALL 显示未知，不得使整个设备工具箱崩溃。

#### Scenario: 刷新设备信息

- **WHEN** 用户打开或刷新 Info
- **THEN** 工具服务读取当前设备信息并按分组显示，正在读取时显示加载状态

### Requirement: 响应式和最小窗口安全

设备工具箱 SHALL 复用项目已设置的 `1120×760` 桌面最小窗口，导航和内容均可压缩或滚动，任意工具内容不得因为窗口拖动而触发 RenderFlex overflow。

#### Scenario: 在最小窗口使用工具箱

- **WHEN** 用户将窗口缩小到允许的最小尺寸并切换七组工具
- **THEN** 导航、标题、主要操作仍可见，长内容纵向滚动，日志、文件列表和信息卡片不越界

### Requirement: 手机舞台与设备工具分栏

页面 SHALL 将手机实时画面和手机底部导航固定在左栏，并按当前手机屏幕宽高比计算左栏宽度，使启动后的实时画面贴合左栏边界；完整 AppHeader（品牌、设备选择、刷新设备、旋转、显隐和主题控制），以及设备型号、分辨率、唯一 FPS、截屏图标和设备工具箱内容 SHALL 位于右栏。手机画面区域 SHALL 不再重复渲染设备信息栏。

#### Scenario: 查看双栏控制页

- **WHEN** 用户打开已连接设备的控制页
- **THEN** 左栏只显示手机实时画面和手机底部导航；右栏顶部完整显示 AppHeader，下面显示设备信息栏、设备工具箱导航和内容

#### Scenario: 启动时贴合手机画面

- **WHEN** 用户启动并连接设备控制页
- **THEN** 左栏按当前设备屏幕方向和宽高比布局，手机实时画面不在四周留下舞台空白，底部导航紧接在画面下方
