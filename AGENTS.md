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
