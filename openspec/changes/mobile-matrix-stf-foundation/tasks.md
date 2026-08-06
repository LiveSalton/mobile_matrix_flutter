## 1. 项目与运行配置

- [x] 1.1 建立 Mobile Matrix 控制面最小目录、Node.js 20 LTS 运行约束和 TypeScript 编译/检查入口；验证不覆盖系统 Node.js 22
- [x] 1.2 定义 STF `3.7.9`、STF_BASE_URL、STF_TOKEN、超时、并发和日志脱敏配置契约；确认 secret 不进入版本库
- [ ] 1.3 编写 Mac 原生 ADB/STF 验证运行说明；明确宿主机 ADB、RethinkDB、STF Provider 和 Docker Desktop 无 USB 直通的边界

## 2. STF 适配与设备模型

- [ ] 2.1 实现 STF REST 客户端，封装设备列表、单设备查询、占用、释放和远程连接请求
- [ ] 2.2 实现统一设备模型和 `present`、`ready`、`using`、`owner` 到 `ready`、`busy`、`offline`、`unavailable`、`unknown` 的状态映射
- [ ] 2.3 为 STF 响应、超时、非 2xx 和无效 JSON 建立可测试的适配器错误类型，并保留安全诊断上下文
- [ ] 2.4 实现 `GET /api/v1/devices` 与 `GET /api/v1/devices/:serial`；验证设备状态来自 STF 而非陈旧本地缓存

## 3. 单设备操作 API

- [ ] 3.1 实现 `POST /api/v1/devices/:serial/lease`，处理可用、离线、未就绪、忙和 STF 鉴权失败场景
- [ ] 3.2 实现 `DELETE /api/v1/devices/:serial/lease`，校验当前客户端所有权并保持释放幂等
- [ ] 3.3 实现 `POST /api/v1/devices/:serial/remote-connect`，返回当前会话临时地址并禁止持久化敏感值
- [ ] 3.4 为单设备接口补充输入校验、稳定错误码和不泄露 Token/ADB key/完整连接地址的响应与日志规则

## 4. 批量操作

- [ ] 4.1 实现 serial 列表校验，拒绝空列表、重复 serial 和无效输入，不在校验失败时调用 STF
- [ ] 4.2 实现 `POST /api/v1/batch/lease`，逐台执行并返回 `accepted`、`succeeded`、`failed` 与每台错误原因
- [ ] 4.3 实现 `POST /api/v1/batch/release`，只释放当前客户端持有的租约并保留其他目标结果
- [ ] 4.4 增加有上限的并发、超时和查询重试；对不确定的租约操作先重查 STF，禁止盲目重复变更
- [ ] 4.5 为一台忙/离线/超时而其他设备成功的场景生成 `partial_failure`，并完成适配器级测试

## 5. 健康检查与诊断

- [ ] 5.1 实现 `GET /health`，分别报告控制面、STF API、Provider/ADB 和鉴权配置状态
- [ ] 5.2 固定并验证 `stf_unreachable`、`provider_unavailable`、`device_offline`、`device_not_ready`、`device_busy`、`auth_failed`、`operation_timeout`、`partial_failure`
- [ ] 5.3 实现统一日志脱敏和错误序列化；确认 Token、ADB key、凭据和不必要的完整远程地址不出现在日志或错误正文
- [ ] 5.4 增加服务自身的单元/契约检查，覆盖正常 STF 响应、认证失败、依赖不可达和部分批量失败

## 6. Mac 真机与多设备验收

- [ ] 6.1 在当前 arm64 Mac 上以宿主机 ADB 识别并授权第一台 Android 真机，记录 ADB 与 STF 设备列表证据
- [ ] 6.2 启动固定版本 STF，验证第一台设备可在 STF 中显示、占用、释放并建立远程连接
- [ ] 6.3 接入第二台 Android 真机，验证两台设备同时列出、状态独立且 Mobile Matrix API 能读到两台设备
- [ ] 6.4 通过 Mobile Matrix 完成单设备占用/释放和两台设备批量占用/释放，保存逐台成功与失败结果
- [ ] 6.5 拔掉一台设备并重新查询，验证该设备进入离线/不可用，另一台设备仍可操作；记录恢复或重连结果
- [ ] 6.6 验证 STF 不可达、Token 错误、设备忙和 Docker 无 USB 直通时的明确错误/降级，不以模拟状态替代

## 7. 进度与交付记录

- [ ] 7.1 将实现文件、配置、运行命令、测试结果和真实设备证据回写到本 change 的相关工件
- [ ] 7.2 执行 OpenSpec 严格校验、格式/类型检查和 API 契约检查，修复所有规范错误
- [ ] 7.3 完成 requirement-by-requirement 验收审计；未有真实证据的条目保持未完成，并记录阻塞原因
