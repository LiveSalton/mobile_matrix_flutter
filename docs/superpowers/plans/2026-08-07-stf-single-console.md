# STF Single Console Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Mobile Matrix 合并进仓库内 STF，让 `7100` 无登录直达双主题设备矩阵，并移除默认 `7121` 服务。

**Architecture:** 固定复制 STF `v3.7.9` 到 `vendor/devicefarmer-stf`，在 App 鉴权中间件中以显式 `no-auth` 配置建立固定本地管理员 session，继续复用 STF WebSocket、设备跟踪和 GroupService 租约语义。设备页拆出主题状态与批量调度两个可测试小服务，根脚本只托管 vendor STF。

**Tech Stack:** Node.js 20、DeviceFarmer STF 3.7.9、AngularJS/ngRoute、Pug、CSS、Jasmine/Karma、Bash、RethinkDB、ADB。

## Global Constraints

- 项目主题唯一事实源为 `doc/project-theme.md`，只允许 `default` 与 `roseGlow`。
- STF 状态和租约仍是唯一事实来源，不新增状态数据库或租约数据库。
- 免登录只适用于绑定 `127.0.0.1` 的可信本地单身份配置。
- Token、ADB key、cookie secret 和完整远程连接地址不得进入源码、普通日志或页面存储。
- 不删除既有根 `src/` 历史基线，但默认启动不得构建或运行它。
- 不得用模拟设备证明双机、批量真机或拔线恢复能力。

---

### Task 1: 固定 STF 源码与来源记录

**Files:**
- Create: `vendor/devicefarmer-stf/**`
- Create: `vendor/devicefarmer-stf/MOBILE_MATRIX_CHANGES.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: GitHub `DeviceFarmer/stf` tag `v3.7.9`, commit `36d1a3e4336f2ecdf7885e3644fe34d0a4282c87`
- Produces: `vendor/devicefarmer-stf/bin/stf` 作为唯一默认 STF 可执行入口

- [ ] **Step 1: 复制固定 tag 源码并排除上游 `.git`**
- [ ] **Step 2: 写入来源、许可证和本项目改动记录**
- [ ] **Step 3: 静态验证版本、commit 记录、LICENSE 存在且未复制 `node_modules`**
- [ ] **Step 4: 在 OpenSpec 勾选 8.1**

### Task 2: 透明本地身份

**Files:**
- Modify: `vendor/devicefarmer-stf/lib/cli/local/index.js`
- Modify: `vendor/devicefarmer-stf/lib/cli/app/index.js`
- Modify: `vendor/devicefarmer-stf/lib/units/app/index.js`
- Modify: `vendor/devicefarmer-stf/lib/units/app/middleware/auth.js`
- Test: `vendor/devicefarmer-stf/lib/units/app/middleware/auth-test.js`

**Interfaces:**
- Consumes: `{noAuth, localUser, secret, authUrl}`
- Produces: `auth(options)` 中间件；`noAuth=true` 时设置 `req.user` 与 `req.session.jwt`

- [ ] **Step 1: 写出首次无 session 自动建立固定身份、复用既有用户和默认认证不变的失败测试**
- [ ] **Step 2: 运行定向测试并确认因 `noAuth` 未实现而失败**
- [ ] **Step 3: 最小实现 CLI 透传与中间件分支，固定管理员身份为 `administrator@fakedomain.com` / `administrator`**
- [ ] **Step 4: 运行定向测试并确认通过**
- [ ] **Step 5: 在 OpenSpec 勾选 8.2**

### Task 3: 主题状态与设备矩阵首页

**Files:**
- Create: `vendor/devicefarmer-stf/res/app/mobile-matrix/theme-service.js`
- Create: `vendor/devicefarmer-stf/res/app/mobile-matrix/theme-service-test.js`
- Create: `vendor/devicefarmer-stf/res/app/mobile-matrix/theme.css`
- Modify: `vendor/devicefarmer-stf/res/app/app.js`
- Modify: `vendor/devicefarmer-stf/res/app/views/index.pug`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/device-list-controller.js`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/device-list.pug`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/device-list.css`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/icons/device-list-icons.css`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/stats/device-list-stats.pug`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/stats/device-list-stats.css`

**Interfaces:**
- Produces: `MobileMatrixTheme.get()`, `MobileMatrixTheme.set(theme)`, `MobileMatrixTheme.toggle()`；仅返回 `default|roseGlow`
- Consumes: `DeviceService.trackAll`, `doc/project-theme.md` 的 `--mm-*` token

- [ ] **Step 1: 写主题允许列表、未知值回退和持久化的失败测试**
- [ ] **Step 2: 运行定向测试并确认失败原因是服务不存在**
- [ ] **Step 3: 实现主题服务和 App shell 初始化**
- [ ] **Step 4: 用语义 token 重构设备首页、统计、工具栏、卡片、空状态、响应式和 reduced-motion**
- [ ] **Step 5: 运行主题测试与 STF 前端构建**
- [ ] **Step 6: 在 OpenSpec 勾选 8.3–8.4**

### Task 4: 设备多选与批量占用/释放

**Files:**
- Create: `vendor/devicefarmer-stf/res/app/device-list/batch/device-batch-service.js`
- Create: `vendor/devicefarmer-stf/res/app/device-list/batch/device-batch-service-test.js`
- Create: `vendor/devicefarmer-stf/res/app/device-list/batch/index.js`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/index.js`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/device-list-controller.js`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/device-list.pug`
- Modify: `vendor/devicefarmer-stf/res/app/device-list/icons/device-list-icons-directive.js`

**Interfaces:**
- Produces: `DeviceBatchService.run(devices, operation, concurrency)`，解析为 `{total, succeeded, failed, results}`
- Consumes: `GroupService.invite(device)` / `GroupService.kick(device)`；页面选中的 serial 集合

- [ ] **Step 1: 写固定并发、顺序无关逐台结果和部分失败的失败测试**
- [ ] **Step 2: 运行定向测试并确认失败原因是服务不存在**
- [ ] **Step 3: 实现最小批量调度服务**
- [ ] **Step 4: 实现显式选择控件、选择清空、loading/disabled、批量占用/释放和结果反馈**
- [ ] **Step 5: 运行定向测试和前端构建**
- [ ] **Step 6: 在 OpenSpec 勾选 8.5**

### Task 5: 单运行时启动与验证

**Files:**
- Modify: `mobile-matrix.sh`
- Modify: `infra/stf/mac/README.md`
- Modify: `docs/validation/mobile-matrix-stf-foundation.md`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/tasks.md`

**Interfaces:**
- Consumes: `vendor/devicefarmer-stf/bin/stf local --no-auth --public-ip 127.0.0.1`
- Produces: 仅 `com.mobile-matrix.stf` launch service 和 `http://127.0.0.1:7100/`

- [ ] **Step 1: 增加启动脚本静态断言，要求 vendor STF、禁止 `start_api_if_configured` 和 `7121`**
- [ ] **Step 2: 修改脚本停止旧 API launch service、按需安装 vendor 依赖并只启动 vendor STF**
- [ ] **Step 3: 执行 shell 语法检查、vendor 定向测试与构建、根 `npm run check` / `npm test` / `npm run build`**
- [ ] **Step 4: 执行 `openspec validate mobile-matrix-stf-foundation --strict` 与 `git diff --check`**
- [ ] **Step 5: 重启并验证 7100 首次访问不跳登录、7121 无监听、终端退出后 7100 仍可访问**
- [ ] **Step 6: 回写验证边界并勾选 8.6–8.7；6.3–6.5 在第二台真机前保持未完成**
