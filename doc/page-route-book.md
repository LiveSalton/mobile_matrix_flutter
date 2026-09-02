# 页面路书

## 页面清单

| 页面中文名 | 页面类名 | 职责描述 | 导航关系 |
| --- | --- | --- | --- |
| 设备控制工作台 | `DeviceControlPage` | 主控页面，集成设备扫描、屏幕舞台与工具箱 | 根路由入口 |
| 设备总览 | `DeviceOverviewPage` | 默认入口，以响应式网格展示所有 ADB 设备；每张卡片可直接触控并进入对应控制台 | 应用根路由；卡片进入 `DeviceControlPage` |
| 设备屏幕舞台 | `DeviceScreenStage` | 实时屏幕流渲染与触控手势坐标映射 | 嵌入主控页面左侧 |
| 设备操作工作区 | `DeviceWorkspace` | 硬件按键、剪贴板、网址直达与终端控制 | 嵌入主控页面右侧 |

## 共享会话

`DeviceSessionManager` 在应用生命周期内持有一个 STF Lite 运行时，并按设备序列号复用 `DeviceSession`。设备总览使用 preview 质量的屏幕流；进入单设备控制台时提升为 full 质量，返回总览后恢复 preview。设备扫描默认启动并约每 5 秒刷新，设备连续两次未出现在 ADB 结果中才移除对应卡片。
