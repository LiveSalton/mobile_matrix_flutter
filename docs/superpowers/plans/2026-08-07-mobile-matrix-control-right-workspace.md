# Mobile Matrix Control Right Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将单设备控制页右侧整理为默认群控三步布局与分类设备工具区，同时诚实标记 Airtest 尚未接入，并保持左侧真机控制会话和现有 STF 工具行为不变。

**Architecture:** 在现有 `ControlPanesCtrl` 中维护仅限页面内存的工作区模式和工具选择状态；右侧壳层通过两个 `$templateCache` 模板分别渲染群控布局与设备工具。所有设备数据继续直接引用 `$scope.device`，现有工具继续使用原 template URL 和 controller，不新增服务、API、状态仓库或依赖。

**Tech Stack:** AngularJS 1.x、Pug、CSS、DeviceFarmer STF 3.7.9、Material Design Icons Round、Mobile Matrix `--mm-*` 主题 token。

## Global Constraints

- 先遵循 `AGENTS.md`、`doc/project-structure.md`、`doc/project-code-style.md`、`doc/project-theme.md`、`doc/project-workflow.md` 和 `design-system/mobile-matrix/MASTER.md`。
- 主题只允许 `default` 液态玻璃蓝与 `roseGlow` 玫瑰流光；不得新增硬编码界面色值、第三套主题或主题副本。
- 不实现 Airtest API、脚本配置、模拟进度、伪执行结果、额外设备集合或持久化群控目标。
- 不修改 `ControlService`、Provider、ADB、minicap、minitouch、租约 API、根启动脚本或主题 token 文件。
- 功能图标只使用本地 Material Design Icons Round；点击目标至少 44px，并提供文字、图标和可见焦点。
- 项目门禁默认禁止新增测试；本计划不创建测试文件，以定向 ESLint、Pug/webpack 构建和真实控制页视觉检查验收。
- 用户已要求以后默认不提交；各任务只形成检查点，不执行 `git add`、`git commit` 或 push。

## File Structure

**Create:**

- `vendor/devicefarmer-stf/res/app/control-panes/workspace-execution.pug`：群控三步布局、当前设备目标卡和 Airtest 未接入空状态。
- `vendor/devicefarmer-stf/res/app/control-panes/workspace-tools.pug`：设备工具分类导航与单一活动模板容器。

**Modify:**

- `vendor/devicefarmer-stf/res/app/control-panes/control-panes-controller.js`：工作区模式、工具分组、过滤和选择行为。
- `vendor/devicefarmer-stf/res/app/control-panes/index.js`：把两个新 Pug 模板注册到 `$templateCache`。
- `vendor/devicefarmer-stf/res/app/control-panes/control-panes.pug`：用双模式工作区替换现有顶层 `nice-tabs`。
- `vendor/devicefarmer-stf/res/app/control-panes/control-panes.css`：工作区顶栏、步骤、空状态、分类侧栏和紧凑视口样式。
- `vendor/devicefarmer-stf/MOBILE_MATRIX_CHANGES.md`：记录右侧工作区改造和 Airtest 非目标。
- `openspec/changes/mobile-matrix-stf-foundation/tasks.md`：完成后更新 8.31–8.33 的真实状态。

**Must remain unchanged:**

- `design-system/mobile-matrix/theme.css`
- `doc/project-theme.md`
- `vendor/devicefarmer-stf/res/app/components/stf/control/control-service.js`
- `vendor/devicefarmer-stf/res/app/control-panes/dashboard/**`
- `vendor/devicefarmer-stf/res/app/control-panes/logs/**`
- `vendor/devicefarmer-stf/res/app/control-panes/screenshots/**`
- `vendor/devicefarmer-stf/res/app/control-panes/automation/**`
- `vendor/devicefarmer-stf/res/app/control-panes/advanced/**`
- `vendor/devicefarmer-stf/res/app/control-panes/explorer/**`
- `vendor/devicefarmer-stf/res/app/control-panes/info/**`

---

### Task 1: 建立工作区页面状态和工具分类

**Files:**

- Modify: `vendor/devicefarmer-stf/res/app/control-panes/control-panes-controller.js`
- Modify: `vendor/devicefarmer-stf/res/app/control-panes/index.js`

**Interfaces:**

- Consumes: `$scope.device`、`$scope.$root.platform` 和现有工具 template URL。
- Produces: `workspaceMode: 'execution' | 'tools'`、`deviceToolGroups`、`activeDeviceTool`、`selectWorkspaceMode(mode)`、`selectDeviceTool(tool)`、`deviceToolVisible(tool)`。

- [x] **Step 1: 在 controller 中用明确常量替换 `sharedTabs` / `topTabs`**

在 controller 函数内部、设备请求之前定义以下状态；工具模板 URL 必须保持现有值：

```js
    $scope.workspaceMode = 'execution'
    $scope.deviceToolGroups = [
      {
        title: gettext('Quick Actions'),
        tools: [
          {
            title: gettext('Dashboard'),
            materialIcon: 'dashboard',
            templateUrl: 'control-panes/dashboard/dashboard.pug',
            filters: ['native', 'web']
          }
        ]
      },
      {
        title: gettext('Records & Diagnostics'),
        tools: [
          {
            title: gettext('Logs'),
            materialIcon: 'receipt_long',
            templateUrl: 'control-panes/logs/logs.pug',
            filters: ['native', 'web']
          },
          {
            title: gettext('Screenshots'),
            materialIcon: 'photo_camera',
            templateUrl: 'control-panes/screenshots/screenshots.pug',
            filters: ['native', 'web']
          }
        ]
      },
      {
        title: gettext('Device Management'),
        tools: [
          {
            title: gettext('Automation'),
            materialIcon: 'route',
            templateUrl: 'control-panes/automation/automation.pug',
            filters: ['native', 'web']
          },
          {
            title: gettext('File Explorer'),
            materialIcon: 'folder_open',
            templateUrl: 'control-panes/explorer/explorer.pug',
            filters: ['native', 'web']
          },
          {
            title: gettext('Advanced'),
            materialIcon: 'tune',
            templateUrl: 'control-panes/advanced/advanced.pug',
            filters: ['native', 'web']
          },
          {
            title: gettext('Info'),
            materialIcon: 'info',
            templateUrl: 'control-panes/info/info.pug',
            filters: ['native', 'web']
          }
        ]
      }
    ]

    $scope.activeDeviceTool = $scope.deviceToolGroups[0].tools[0]
```

- [x] **Step 2: 增加模式切换、工具选择和平台过滤**

将以下函数放在状态定义之后；不访问服务、不写入 Settings 或 localStorage：

```js
    $scope.selectWorkspaceMode = function(mode) {
      if (mode === 'execution' || mode === 'tools') {
        $scope.workspaceMode = mode
      }
    }

    $scope.selectDeviceTool = function(tool) {
      if (tool && $scope.deviceToolVisible(tool)) {
        $scope.activeDeviceTool = tool
      }
    }

    $scope.deviceToolVisible = function(tool) {
      return !tool.filters || tool.filters.indexOf($scope.$root.platform) !== -1
    }
```

- [x] **Step 3: 保持设备加载和平台初始化边界不变**

保留 `getDevice()`、`GroupService.invite(device)`、`ControlService.create()`、`SettingsService.set()` 和 FatalMessage watcher 原样。确认没有创建 `executionTargets` 副本；群控模板直接读取 `$scope.device`。

- [x] **Step 4: 注册两个局部工作区模板**

在 `index.js` 的 `.config(...)` 后追加模板缓存注册，不新增 Angular 模块或目录：

```js
  .run(['$templateCache', function($templateCache) {
    $templateCache.put(
      'control-panes/workspace-execution.pug',
      require('./workspace-execution.pug')
    )
    $templateCache.put(
      'control-panes/workspace-tools.pug',
      require('./workspace-tools.pug')
    )
  }])
```

- [x] **Step 5: 对 controller 和模板注册执行定向 ESLint**

Run from `vendor/devicefarmer-stf/`:

```bash
rtk npm exec -- eslint \
  res/app/control-panes/control-panes-controller.js \
  res/app/control-panes/index.js
```

Expected: 0 errors；上游已有注释类警告可保留，但不得新增错误或新的未使用变量。

- [x] **Step 6: 检查点**

记录本任务修改文件和 ESLint 输出，不提交 Git。后续任务只依赖本节声明的六个 `$scope` 接口。

### Task 2: 实现双模式壳层和诚实的群控空状态

**Files:**

- Modify: `vendor/devicefarmer-stf/res/app/control-panes/control-panes.pug`
- Create: `vendor/devicefarmer-stf/res/app/control-panes/workspace-execution.pug`

**Interfaces:**

- Consumes: Task 1 的 `workspaceMode`、`selectWorkspaceMode(mode)` 和 `$scope.device`。
- Produces: `.mm-workspace-header`、`.mm-workspace-mode-switch`、`.mm-execution-workspace` 结构，供 Task 4 样式化。

- [x] **Step 1: 用工作区壳层替换右侧顶层 `nice-tabs`**

保留左侧 `fa-pane` 和设备模板不变，将右侧 pane 内容替换为：

```pug
    div(fa-pane, pane-id='control-top-tabs', pane-anchor='')
      .widget-container.fluid-height.mm-tool-workspace
        .mm-workspace-header
          .mm-workspace-title
            i.material-icons-round(aria-hidden='true') workspaces
            span Workbench
          .mm-workspace-mode-switch(role='tablist', aria-label='Workspace mode')
            button.mm-workspace-mode(
              type='button'
              role='tab'
              ng-class='{active: workspaceMode === "execution"}'
              ng-attr-aria-selected='{{workspaceMode === "execution"}}'
              ng-click='selectWorkspaceMode("execution")')
              i.material-icons-round(aria-hidden='true') account_tree
              span Group Execution
            button.mm-workspace-mode(
              type='button'
              role='tab'
              ng-class='{active: workspaceMode === "tools"}'
              ng-attr-aria-selected='{{workspaceMode === "tools"}}'
              ng-click='selectWorkspaceMode("tools")')
              i.material-icons-round(aria-hidden='true') construction
              span Device Tools
        .mm-workspace-content(ng-switch='workspaceMode')
          div(ng-switch-when='execution')
            div(ng-include='"control-panes/workspace-execution.pug"')
          div(ng-switch-when='tools')
            div(ng-include='"control-panes/workspace-tools.pug"')
```

- [x] **Step 2: 创建三步群控布局**

`workspace-execution.pug` 使用以下完整语义结构；后两步必须是禁用状态而不是可点击预览：

```pug
section.mm-execution-workspace(aria-labelledby='mm-execution-title')
  .mm-execution-heading
    div
      h2#mm-execution-title Group Execution
      p Prepare multiple devices for a shared automation task.
    span.mm-capability-badge Layout only

  ol.mm-execution-steps(aria-label='Execution steps')
    li.mm-execution-step.active(aria-current='step')
      span.mm-step-index 1
      span
        strong Select devices
        small Current device selected
    li.mm-execution-step.disabled(aria-disabled='true')
      span.mm-step-index 2
      span
        strong Configure action
        small Requires Airtest
    li.mm-execution-step.disabled(aria-disabled='true')
      span.mm-step-index 3
      span
        strong Review & run
        small Not available yet

  .mm-execution-target
    .mm-execution-target-heading
      span Target device
      span 1 selected
    .mm-target-device
      i.material-icons-round(aria-hidden='true') phone_android
      span.mm-target-device-copy
        strong {{device.name || device.model || 'Android device'}}
        small {{device.serial}}
      span.mm-target-device-state
        i.material-icons-round(aria-hidden='true') fiber_manual_record
        span {{device.state | translate}}

  .mm-execution-empty
    i.material-icons-round.mm-execution-empty-icon(aria-hidden='true') route
    h3 Airtest execution engine is not connected
    p The current device is ready as the first target. Action configuration and execution will be enabled in a dedicated Airtest change.
    button.mm-disabled-action(type='button', disabled, aria-disabled='true')
      span Next step unavailable
```

- [x] **Step 3: 验证模板只引用真实设备状态**

Search:

```bash
rtk rg -n "setTimeout|setInterval|progress|mock|executionTargets|localStorage" \
  res/app/control-panes/workspace-execution.pug \
  res/app/control-panes/control-panes-controller.js
```

Expected: no matches，除非匹配到解释性文案；不得存在定时器、模拟进度或目标列表副本。

- [x] **Step 4: 执行第一次模板构建**

Run from `vendor/devicefarmer-stf/`:

```bash
rtk npm exec -- gulp build
```

Expected: exit 0；Pug 和 webpack 能解析两个 `$templateCache` key，现有控制页 bundle 构建成功。

- [x] **Step 5: 检查点**

记录构建结果，不启动 STF、不提交 Git。确认左侧 `fa-pane`、`device-control.pug` 和快捷键 controller 无修改。

### Task 3: 将七个设备工具收纳为分类侧栏

**Files:**

- Create: `vendor/devicefarmer-stf/res/app/control-panes/workspace-tools.pug`

**Interfaces:**

- Consumes: Task 1 的 `deviceToolGroups`、`activeDeviceTool`、`selectDeviceTool(tool)` 和 `deviceToolVisible(tool)`。
- Produces: `.mm-device-tools`、`.mm-device-tool-nav` 和 `.mm-device-tool-content`，内容区继续加载现有工具模板。

- [x] **Step 1: 创建分类导航和单一内容区**

`workspace-tools.pug` 使用以下结构；不复制任何 Dashboard 或工具模板：

```pug
section.mm-device-tools(aria-labelledby='mm-device-tools-title')
  nav.mm-device-tool-nav(aria-label='Device tools')
    h2#mm-device-tools-title.sr-only Device Tools
    section.mm-device-tool-group(ng-repeat='group in deviceToolGroups')
      h3.mm-device-tool-group-title {{group.title | translate}}
      button.mm-device-tool(
        type='button'
        ng-repeat='tool in group.tools'
        ng-if='deviceToolVisible(tool)'
        ng-class='{active: activeDeviceTool === tool}'
        ng-attr-aria-current='{{activeDeviceTool === tool ? "page" : undefined}}'
        ng-click='selectDeviceTool(tool)')
        i.material-icons-round(aria-hidden='true') {{tool.materialIcon}}
        span {{tool.title | translate}}
  main.mm-device-tool-content
    div(ng-if='activeDeviceTool', ng-include='activeDeviceTool.templateUrl')
```

- [x] **Step 2: 核对现有七个模板只出现一次**

Run from `vendor/devicefarmer-stf/`:

```bash
rtk rg -n "control-panes/(dashboard|logs|screenshots|automation|explorer|advanced|info)/.*\.pug" \
  res/app/control-panes/control-panes-controller.js \
  res/app/control-panes/control-panes.pug \
  res/app/control-panes/workspace-tools.pug
```

Expected: each top-level tool template URL appears once in `control-panes-controller.js`;模板文件不复制这些 URL 或业务内容。

- [x] **Step 3: 构建验证所有现有工具仍可解析**

Run:

```bash
rtk npm exec -- gulp build
```

Expected: exit 0；Dashboard、Logs、Screenshots、Automation、File Explorer、Advanced、Info 模块仍由现有 `index.js` 注册。

- [x] **Step 4: 检查点**

记录构建结果，不修改 `nice-tabs` 通用组件。Advanced 等工具内部如继续使用 `nice-tabs`，其行为必须保持不变。

### Task 4: 实现双主题、响应式和可访问样式

**Files:**

- Modify: `vendor/devicefarmer-stf/res/app/control-panes/control-panes.css`

**Interfaces:**

- Consumes: Task 2/3 的 `.mm-workspace-*`、`.mm-execution-*` 和 `.mm-device-tool-*` class。
- Produces: 使用现有 `--mm-*` token 的宽桌面和紧凑视口布局。

- [x] **Step 1: 将工具工作区改为固定顶栏 + 可滚动内容**

在现有 `.mm-tool-workspace` 样式附近追加：

```css
.mm-control-workspace .mm-tool-workspace {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.mm-control-workspace .mm-workspace-header {
  align-items: center;
  background: var(--mm-bg-secondary);
  border-bottom: 1px solid var(--mm-outline);
  display: flex;
  gap: 16px;
  min-height: 64px;
  padding: 8px 16px;
}

.mm-control-workspace .mm-workspace-title,
.mm-control-workspace .mm-workspace-mode-switch,
.mm-control-workspace .mm-workspace-mode {
  align-items: center;
  display: flex;
}

.mm-control-workspace .mm-workspace-title {
  color: var(--mm-text-primary);
  font-size: 16px;
  font-weight: 700;
  gap: 8px;
}

.mm-control-workspace .mm-workspace-mode-switch {
  background: var(--mm-bg);
  border: 1px solid var(--mm-outline);
  border-radius: 12px;
  gap: 4px;
  margin-left: auto;
  padding: 4px;
}

.mm-control-workspace .mm-workspace-mode {
  background: transparent;
  border: 1px solid transparent;
  border-radius: 8px;
  color: var(--mm-text-secondary);
  gap: 6px;
  min-height: 44px;
  padding: 8px 12px;
}

.mm-control-workspace .mm-workspace-mode.active {
  background: var(--mm-highlight);
  border-color: var(--mm-metal-edge);
  color: var(--mm-text-primary);
}

.mm-control-workspace .mm-workspace-mode:focus-visible,
.mm-control-workspace .mm-device-tool:focus-visible {
  outline: 2px solid var(--mm-primary);
  outline-offset: 2px;
}

.mm-control-workspace .mm-workspace-content {
  flex: 1 1 auto;
  min-height: 0;
  overflow: auto;
  padding: 16px;
}
```

- [x] **Step 2: 样式化群控步骤、真实目标卡和禁用空状态**

追加以下规则；不得出现十六进制、rgb 或新的颜色变量：

```css
.mm-control-workspace .mm-execution-workspace {
  margin: 0 auto;
  max-width: 1180px;
}

.mm-control-workspace .mm-execution-heading,
.mm-control-workspace .mm-execution-target-heading,
.mm-control-workspace .mm-target-device {
  align-items: center;
  display: flex;
}

.mm-control-workspace .mm-execution-heading {
  justify-content: space-between;
  margin-bottom: 16px;
}

.mm-control-workspace .mm-execution-heading h2,
.mm-control-workspace .mm-execution-heading p {
  margin: 0;
}

.mm-control-workspace .mm-execution-heading p,
.mm-control-workspace .mm-target-device small,
.mm-control-workspace .mm-execution-empty p {
  color: var(--mm-text-secondary);
}

.mm-control-workspace .mm-capability-badge {
  border: 1px solid var(--mm-outline);
  border-radius: 8px;
  color: var(--mm-text-secondary);
  padding: 6px 8px;
}

.mm-control-workspace .mm-execution-steps {
  display: grid;
  gap: 8px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  list-style: none;
  margin: 0 0 16px;
  padding: 0;
}

.mm-control-workspace .mm-execution-step {
  align-items: center;
  background: var(--mm-bg);
  border: 1px solid var(--mm-outline);
  border-radius: 12px;
  color: var(--mm-text-secondary);
  display: flex;
  gap: 8px;
  min-height: 64px;
  padding: 12px;
}

.mm-control-workspace .mm-execution-step.active {
  background: var(--mm-highlight);
  border-color: var(--mm-metal-edge);
  color: var(--mm-text-primary);
}

.mm-control-workspace .mm-execution-step.disabled {
  color: var(--mm-disabled);
}

.mm-control-workspace .mm-step-index {
  align-items: center;
  border: 1px solid currentColor;
  border-radius: 50%;
  display: inline-flex;
  flex: 0 0 28px;
  height: 28px;
  justify-content: center;
}

.mm-control-workspace .mm-execution-step span:last-child,
.mm-control-workspace .mm-target-device-copy {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.mm-control-workspace .mm-execution-target,
.mm-control-workspace .mm-execution-empty {
  background: var(--mm-bg);
  border: 1px solid var(--mm-outline);
  border-radius: 16px;
  padding: 16px;
}

.mm-control-workspace .mm-execution-target {
  margin-bottom: 16px;
}

.mm-control-workspace .mm-execution-target-heading {
  justify-content: space-between;
  margin-bottom: 12px;
}

.mm-control-workspace .mm-target-device {
  background: var(--mm-highlight);
  border: 1px solid var(--mm-metal-edge);
  border-radius: 12px;
  gap: 10px;
  min-height: 56px;
  padding: 10px 12px;
}

.mm-control-workspace .mm-target-device-state {
  align-items: center;
  display: inline-flex;
  gap: 4px;
  margin-left: auto;
}

.mm-control-workspace .mm-target-device-state .material-icons-round {
  color: var(--mm-text-secondary);
  font-size: 12px;
}

.mm-control-workspace .mm-execution-empty {
  border-style: dashed;
  min-height: 280px;
  text-align: center;
}

.mm-control-workspace .mm-execution-empty-icon {
  color: var(--mm-primary);
  font-size: 40px;
  margin-top: 48px;
}

.mm-control-workspace .mm-disabled-action {
  background: var(--mm-bg-secondary);
  border: 1px solid var(--mm-outline);
  border-radius: 8px;
  color: var(--mm-disabled);
  min-height: 44px;
  padding: 8px 12px;
}
```

- [x] **Step 3: 样式化工具分类侧栏和单一内容区**

追加：

```css
.mm-control-workspace .mm-device-tools {
  display: grid;
  gap: 16px;
  grid-template-columns: 200px minmax(0, 1fr);
  margin: 0 auto;
  max-width: 1180px;
  min-height: 100%;
}

.mm-control-workspace .mm-device-tool-nav,
.mm-control-workspace .mm-device-tool-content {
  background: var(--mm-bg-secondary);
  border: 1px solid var(--mm-outline);
  border-radius: 16px;
}

.mm-control-workspace .mm-device-tool-nav {
  padding: 8px;
}

.mm-control-workspace .mm-device-tool-group-title {
  color: var(--mm-text-secondary);
  font-size: 11px;
  font-weight: 700;
  margin: 16px 8px 6px;
  text-transform: uppercase;
}

.mm-control-workspace .mm-device-tool {
  align-items: center;
  background: transparent;
  border: 1px solid transparent;
  border-radius: 8px;
  color: var(--mm-text-secondary);
  display: flex;
  gap: 8px;
  min-height: 44px;
  padding: 8px 10px;
  text-align: left;
  width: 100%;
}

.mm-control-workspace .mm-device-tool.active,
.mm-control-workspace .mm-device-tool:hover {
  background: var(--mm-highlight);
  border-color: var(--mm-metal-edge);
  color: var(--mm-text-primary);
}

.mm-control-workspace .mm-device-tool-content {
  min-width: 0;
  overflow: hidden;
  padding: 0;
}
```

- [x] **Step 4: 增加紧凑视口降级**

在现有 `@media (max-width: 1100px)` 内加入：

```css
  .mm-control-workspace .mm-workspace-header {
    align-items: flex-start;
    flex-direction: column;
  }

  .mm-control-workspace .mm-workspace-mode-switch {
    margin-left: 0;
    width: 100%;
  }

  .mm-control-workspace .mm-workspace-mode {
    flex: 1 1 0;
    justify-content: center;
  }

  .mm-control-workspace .mm-execution-steps {
    grid-template-columns: minmax(0, 1fr);
  }

  .mm-control-workspace .mm-device-tools {
    grid-template-columns: minmax(0, 1fr);
  }

  .mm-control-workspace .mm-device-tool-nav {
    display: flex;
    gap: 4px;
    overflow-x: auto;
  }

  .mm-control-workspace .mm-device-tool-group {
    display: flex;
    flex: 0 0 auto;
    gap: 4px;
  }

  .mm-control-workspace .mm-device-tool-group-title {
    position: absolute;
    clip: rect(0 0 0 0);
    clip-path: inset(50%);
    height: 1px;
    overflow: hidden;
    white-space: nowrap;
    width: 1px;
  }

  .mm-control-workspace .mm-device-tool {
    white-space: nowrap;
    width: auto;
  }
```

- [x] **Step 5: 检查没有新增硬编码色值**

Run:

```bash
rtk rg -n "#[0-9A-Fa-f]{3,8}|rgba?\(" res/app/control-panes/control-panes.css
```

Expected: 本任务新增块无匹配；如果文件旧代码已有匹配，只审查本次 diff，禁止新增颜色字面量。

- [x] **Step 6: 执行 ESLint、模板构建和差异格式检查**

Run:

```bash
rtk npm exec -- eslint \
  res/app/control-panes/control-panes-controller.js \
  res/app/control-panes/index.js
rtk npm exec -- gulp build
cd /Users/salton/codeGit/mobile-matrix
rtk git diff --check
```

Expected: all exit 0；ESLint 可保留上游注释类警告但不得有 error。

- [x] **Step 7: 检查点**

记录静态和构建结果，不提交 Git。

### Task 5: 真实控制页视觉验收和文档收尾

**Files:**

- Modify: `vendor/devicefarmer-stf/MOBILE_MATRIX_CHANGES.md`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/tasks.md`

**Interfaces:**

- Consumes: 完成构建后的 STF 控制页和一台真实在线 Android 设备。
- Produces: 双主题、宽/紧凑视口、现有工具切换和左侧控制会话的运行证据。

- [x] **Step 1: 在获得运行授权后重启现有 STF**

Run from repository root:

```bash
rtk ./mobile-matrix.sh
```

Expected: `http://127.0.0.1:7100/` 可访问；不启动 7121。若本轮没有运行授权，停在此步骤并报告需要用户确认，不把构建结果写成运行通过。

- [x] **Step 2: 在真实设备控制页检查默认群控状态**

Open `http://127.0.0.1:7100/#!/control/<真实设备 serial>` and verify:

- 左侧真机画面可见且触控、Home、Back 保持可用。
- 右侧默认激活 Group Execution。
- 当前设备真实名称、serial 和 STF 状态可见。
- Step 2 / Step 3 有文字和禁用语义，不能点击。
- 页面没有 Airtest 执行按钮、模拟进度或虚构结果。

- [x] **Step 3: 检查设备工具分类和原功能**

切换 Device Tools，逐项打开 Dashboard、Logs、Screenshots、Automation、File Explorer、Advanced、Info。Expected: 每次只有一个工具内容；各模板可加载；切换不释放设备、不刷新左侧屏幕、不产生第二套底部标签。

- [x] **Step 4: 检查双主题和响应式**

分别在 `default` 与 `roseGlow` 下检查至少 1600px 宽桌面和约 1000px 紧凑视口。Expected: 只使用当前主题 token；工具侧栏在紧凑视口成为顶部可滚动导航；三步布局变为单列；无横向溢出；键盘焦点可见。

- [x] **Step 5: 回写 vendor 改动记录**

在 `MOBILE_MATRIX_CHANGES.md` 新增一项，明确：

```markdown
- 将单设备控制页右侧整理为默认群控三步布局与分类设备工具区；当前设备自动显示，Airtest 未接入时后两步明确禁用。现有 STF 工具模板、事件和左侧控制会话保持不变。
```

- [x] **Step 6: 只按真实证据更新 OpenSpec 任务**

在 `tasks.md` 中：

- 静态布局和代码完成后勾选 8.31、8.32。
- 只有 Task 4 构建与 Task 5 双主题/视口/真实控制页检查均完成后才勾选 8.33。
- 未启动或未看到真实控制页时，8.33 保持未完成并写明验收边界，不得用静态 mockup 替代。

- [x] **Step 7: 执行最终规范和差异检查**

Run from repository root:

```bash
rtk openspec validate mobile-matrix-stf-foundation --strict
rtk git diff --check
rtk git status --short
```

Expected: OpenSpec valid，diff check exit 0；状态列表只包含本计划文件和用户已有未提交变更，不提交 Git。

## Completion Criteria

- 右侧默认显示诚实的群控执行第一步，当前设备直接来自 STF 控制页状态。
- Airtest 未接入的能力明确禁用，没有伪执行、模拟结果或额外状态仓库。
- 七个现有工具按三组进入分类导航，每次只挂载一个模板。
- 左侧真机控制、租约、快捷键和工具业务事件保持不变。
- 两套主题和紧凑视口符合现有 token、Material 图标和 44px 触达约束。
- 定向 ESLint、vendor 构建、OpenSpec strict 和 diff check 通过；真实页面证据与静态证据清楚区分。
- 没有新增测试、依赖、主题色、端口、服务或 Git 提交。
