# Realistic Bell iOS — V0.2

Realistic Bell 是一个原生 iPhone 仿真摇铃 App。它读取设备运动数据，模拟铃舌在铃体中的三维运动，并在碰撞时播放铃声和触觉反馈。

## 当前实现

- SwiftUI 主界面和长按呼出的调试面板。
- CoreMotion `deviceMotion`，采样间隔 100 Hz。
- 固定步长三维铃舌模拟，综合重力、平移加速度与设备旋转，计算铃舌方向、速度和撞击事件。
- 按铃体内部几何约束铃舌运动，并在 SceneKit 显示层插值方向和角速度，改善换向惯性与边界穿透。
- 48 kHz 双声道 C11 模态合成器优先；合成引擎无法准备或接受冲击时，回退到五组 WAV 采样和八个重叠播放声部。
- Core Haptics 瞬态反馈；声音可单独开关。
- 处理音频中断、路由变化与音频服务重置后的恢复。

## 打开和运行

1. 用 Xcode 打开 `RealisticBell.xcodeproj`。
2. 在 Signing & Capabilities 中选择自己的 Development Team。
3. 连接 iPhone，选择设备并运行。
4. 摇动手机体验；长按铃铛约 0.7 秒打开调试参数。

项目最低部署版本为 iOS 17。CoreMotion、Core Haptics 和实际音频体验需要在支持相应能力的真机上评估；本仓库状态不代表已发布 App Store 或 TestFlight 版本。

## 调试参数

调试面板可以调整铃舌阻尼、回弹、最小撞击速度、碰撞冷却、平移与旋转响应、音量、音高随机范围和触觉强度，也可以恢复默认值。默认值以 `RealisticBell/Models/BellConfig.swift` 为准。

## 目录

```text
RealisticBell/
  App/                 SwiftUI 应用入口
  Features/Bell/       页面、视图模型、SceneKit 场景和调试面板
  Models/              运动输入、铃舌状态、几何、配置与撞击事件
  Services/            CoreMotion、铃舌模拟、音频路由、采样音频和触觉
  AudioDSP/            C11 模态声音合成器
  Resources/Audio/     WAV 采样回退资源
  Support/             Swift 与 C 的桥接头
Tests/                 独立 Swift/C 行为检查源码
docs/superpowers/      设计规格与实施计划记录
```

## 当前边界

- `main` 分支的接触期间会依据新增外力产生离散冲击事件；连续接触声音另在 `feature/continuous-contact-sound` 分支实现，尚未合入 `main`。
- 五组 WAV 是采样回退资源，不是完整的多力度真实录音库。
- 尚无 App Store/TestFlight 发布包；需本机配置签名后从 Xcode 安装。
- 参数和物理观感仍应以目标 iPhone 真机体验为准。
- `Tests/` 收录独立 Swift/C 行为检查源码；当前 Xcode 工程没有单独的测试 target。
