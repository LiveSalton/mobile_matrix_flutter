## Purpose

让 Flutter 桌面控制台与 Web STF 共用同一设备屏幕流协议、投影尺寸和启停生命周期，在保持最新画面优先的同时提供可诊断的实时渲染结果。

## ADDED Requirements

### Requirement: STF 是唯一实时画面来源
控制台 SHALL 只通过当前设备的 STF 屏幕 WebSocket 接收实时 JPEG 帧，不得自行启动、停止或直连另一套 minicap 生产进程，也不得将 ADB 截图伪装成实时流。

#### Scenario: STF 屏幕地址可用
- **WHEN** 当前设备具有可连接的 STF 屏幕 WebSocket 地址
- **THEN** 控制台 SHALL 连接该地址并只展示从该连接收到的实时帧

#### Scenario: STF 屏幕地址不可用
- **WHEN** 控制台无法解析或连接当前设备的 STF 屏幕 WebSocket
- **THEN** 控制台 SHALL 展示明确的屏幕连接错误，且 SHALL NOT 静默切换到 ADB 截图或自启 minicap

### Requirement: 屏幕流协议与 Web STF 一致
控制台 SHALL 使用 STF Web 屏幕客户端相同的 `size <w>x<h>`、`on` 和 `off` 控制消息管理设备画面兴趣。

#### Scenario: 首次建立连接
- **WHEN** WebSocket 已打开且设备画面处于可见状态
- **THEN** 控制台 SHALL 先发送当前投影尺寸，再发送 `on`

#### Scenario: 可见画面尺寸变化
- **WHEN** 设备画面保持可见且有效投影尺寸发生变化
- **THEN** 控制台 SHALL 只发送新的 `size <w>x<h>`，不得为相同尺寸重复重启生产流

#### Scenario: 画面隐藏和恢复
- **WHEN** 用户隐藏设备画面
- **THEN** 控制台 SHALL 发送 `off`；恢复可见后 SHALL 重新发送当前尺寸并发送 `on`

#### Scenario: 连接恢复
- **WHEN** STF 屏幕 WebSocket 断开后重新连接成功且画面仍应可见
- **THEN** 控制台 SHALL 按首次连接顺序重新发送当前尺寸和 `on`

### Requirement: 投影尺寸与 Web STF 一致
控制台 SHALL 按 Web STF 的规则从当前画面逻辑边界、设备像素比、设备真实尺寸和旋转方向计算投影尺寸：像素密度限制在 1.0 至 1.5，最小缩放比例为设备真实尺寸的 0.36，并对结果向上取整。

#### Scenario: 高像素密度显示器
- **WHEN** 桌面显示器的设备像素比大于 1.5
- **THEN** 投影尺寸计算 SHALL 使用 1.5 作为像素密度上限

#### Scenario: 画面区域小于最小缩放尺寸
- **WHEN** 初始投影宽度或高度小于设备对应真实尺寸的 0.36
- **THEN** 控制台 SHALL 等比例放大宽高，直到两个维度均满足 Web STF 的最小缩放规则

#### Scenario: 横屏设备
- **WHEN** 当前设备旋转角度为 90 度或 270 度
- **THEN** 控制台 SHALL 交换逻辑边界的宽高后再应用投影尺寸算法

### Requirement: 最新帧优先渲染
控制台 SHALL 使用 Flutter 等价图片管线解码 STF JPEG 帧，任何时刻最多保留一个正在解码的帧和一个最新待解码帧，不得形成无界帧队列。

#### Scenario: 接收速度高于解码速度
- **WHEN** 解码尚未完成时连续收到多个 JPEG 帧
- **THEN** 控制台 SHALL 保留最新待解码帧并丢弃被更新替代的中间帧

#### Scenario: 新帧完成解码
- **WHEN** 最新 JPEG 帧成功解码
- **THEN** 控制台 SHALL 在同一画面区域替换当前图片、保持外层界面不随每帧重绘，并释放不再使用的图片与解码资源

#### Scenario: 帧损坏
- **WHEN** 单个 JPEG 帧无法解码
- **THEN** 控制台 SHALL 保留上一张有效画面并继续处理后续帧

### Requirement: 屏幕性能可诊断
控制台 SHALL 分别记录收到的帧数、完成渲染的帧数、被替代丢弃的帧数和最近一次解码耗时，不得仅用解码完成次数笼统表示整个链路性能。

#### Scenario: 用户验收滚动画面
- **WHEN** 用户在相同设备、相同 STF 投影尺寸下执行连续滚动
- **THEN** 调试信息 SHALL 能区分来源帧率、渲染帧率、丢帧数量和解码耗时，以便与 Web 表现对照
