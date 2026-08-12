## Why

控制台的“群控执行”工作台目前仅展示 Airtest 未连接的占位信息；即使本机已具备可连接真机的 Airtest 运行环境，用户仍不能配置或执行下一步。需要在不改变 STF 设备事实来源的前提下，提供可验证的 Airtest 多设备执行闭环。

## What Changes

- 为本机/可信网络中的 STF 控制台增加 Airtest 执行引擎就绪状态查询。
- 让一个或多个已选定且可用的 Android 真机可以选择受限、安全的动作并获得逐设备真实执行结果。
- 将现有的抖音 Airtest 任务作为项目内脚本资源登记，允许在执行工作台中选择脚本后运行。
- 将群控执行工作台的步骤状态与引擎、设备和执行结果联动，不再以静态占位阻塞后续操作。
- 在每台设备的执行结果中展示本次真实截屏，并允许执行完成后再次运行。
- 在启动脚本中准备隔离的 Airtest Python 环境，并把运行路径传递给 STF 进程。

## Capabilities

### New Capabilities

- `airtest-execution`: 在 Mobile Matrix 控制台内选择一个或多个可用 Android 真机执行受限 Airtest 动作并展示逐设备真实结果。
- `airtest-task-catalog`: 登记和选择项目内受限 Airtest 任务脚本。

### Modified Capabilities

- 无。

## Impact

- 影响 STF 应用服务端的本机 Airtest 状态与执行 API。
- 影响控制页面的群控执行工作台及根目录启动脚本。
- 新增本机 Python Airtest 运行时依赖；不引入远程任务队列、脚本上传或任意代码执行。
