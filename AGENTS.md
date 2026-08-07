## OpenSpec门禁

- 必须 处理 OpenSpec 任务前先读取：
    - `openspec/config.yaml`
    - 若存在 `openspec/AGENTS.md` / `openspec/project.md`，则作为兼容旧版 OpenSpec 的补充上下文读取。
- 必须 出现以下任一情况时，优先遵循 `openspec/config.yaml` 与 OpenSpec CLI 输出的 artifact
  instructions：
    - 提及 `proposal`/`spec`/`change`/`plan` 等规划/提案关键词
    - 引入新能力、破坏性变更、架构调整、重大性能/安全改造
    - 需求语义不清，需编码前确认权威规范
- 必须 用 `openspec/config.yaml`、`openspec instructions` 或兼容旧版 OpenSpec 文件明确以下内容后再推进：
    - change proposal 创建与应用方式
    - spec 格式与编写约定
    - OpenSpec 项目结构与执行指南
- 必须 `spec.md`/`proposal.md`/`tasks.md`/`design.md` 使用中文编写。
- 必须 保留 `OPENSPEC:START` / `OPENSPEC:END` 管控区块完整，不破坏自动刷新能力。
- 必须 在当前进行中的 OpenSpec 提案里，只要新增了需求建议、流程调整或实现约束，就自动同步更新对应提案文档（至少
  `proposal.md`，并按影响同步 `design.md`/`tasks.md`/`spec.md`/`README.md`），禁止只改代码不回写提案。

## 项目概览

Mobile Matrix 是移动设备群控项目，基于 DeviceFarmer STF 接入真实 Android 设备，并通过 TypeScript 控制平面提供设备状态查询、占用管理与批量任务执行能力。

## 最高门禁

- 必须先阅读 `AGENTS.md` 与 `doc/` 目录中的约束文档，再改任何代码或文档。
- 必须先读 `design-system/mobile-matrix/MASTER.md`，再修改任何与 UI 外观相关内容。
- 必须在 `doc/project-theme.md` 范围内调整主题，不允许新增硬编码界面色值。
- 禁止无用户确认进行大范围重构和无关文件修改。
- 禁止默认主动构建、发布、部署；默认禁止新增测试，除非任务要求。
- 任何引入新能力、架构调整、流程变更时，先按 OpenSpec 的现行流程补齐变更文档。

## 规范文档索引

| 路径 | 说明 |
| --- | --- |
| `doc/project-structure.md` | 文件组织、模块边界与变更范围约束。 |
| `doc/project-code-style.md` | 编码约束、跨层职责和禁止项。 |
| `doc/project-theme.md` | 主题配色、字体、间距、动效与禁用项。 |
| `doc/project-workflow.md` | 任务执行顺序与协作/评审边界。 |
