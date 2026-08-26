# 项目结构约束

## 模块职责与分层

- `lib/models/`：纯数据模型定义，不可变对象（Immutable），禁止反向依赖服务或 UI。
- `lib/services/`：ADB、STF、minicap 协议及系统级硬件通信接口，向视图层暴露纯异步或流式状态。
- `lib/views/`：页面与组件展示层，只依赖 Models 与 Services 接口，禁止直接执行底层 Process 命令。
- `lib/theme/`：设计令牌与主题扩展，提供跨组件语义色彩支持。

## 依赖与归属

- 依赖方向严格单向流动：`Views -> Services -> Models`。
- 资产文件放置于 `assets/` 并在 `pubspec.yaml` 中显式声明。
- 生成代码与临时脚本一律不得混入 `lib/` 生产目录。
