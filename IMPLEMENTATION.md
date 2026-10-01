# Realistic Bell iOS — V0.2 实现说明

本文记录当前仓库中的实现，作为 V0.2 基线说明；设计演进过程保留在 `docs/superpowers/specs/` 和 `docs/superpowers/plans/`。

## 产品行为

App 启动后开始采集设备运动。铃舌模拟器根据重力、用户加速度和角速度推进内部状态；发生撞击时，界面更新计数和力度，并按设置播放声音与触觉。切到后台或离开页面时停止采集、音频和模拟器。

主界面显示 SceneKit 铃铛、摇动提示、声音开关和碰撞指标。长按铃铛约 0.7 秒打开调试面板。声音开关状态由 `BellSoundPreference` 持久化；调试参数在运行期间通过 `BellConfig` 即时应用。

## 架构与数据流

```text
CMMotionManager (deviceMotion, 100 Hz)
  → MotionService
  → MotionSample / BellMotionInput
  → BellViewModel
  → BellClapperSimulator（固定步长积分、几何碰撞、撞击事件）
      ├─ BellClapperState → BellSceneView / SceneKit
      └─ BellImpactEvent
          ├─ BellAudioEngine → 模态合成 / WAV 回退
          └─ HapticService → Core Haptics 瞬态反馈
```

### 运动与物理

- `MotionService` 以 `1 / 100` 秒间隔请求 CoreMotion `deviceMotion`，提供重力、用户加速度、旋转率和时间戳。
- `BellMotionInput` 校验输入有限值；`BellClapperSimulator` 用固定时间步积分铃舌方向和切向速度，并限制单帧累积时间、输入向量和角速度。
- 模拟器计算铃壁接触、法向撞击速度、接触方向/位置及切向速度，按冷却时间限制撞击事件。
- `BellGeometryProfile` 与 `BellClapperParameters` 提供参考几何和物理参数。模拟层和 SceneKit 显示层都会约束铃舌摆角，以避免铃珠穿过铃体；显示层另行平滑方向和速度，保留换向惯性。

### 音频和触觉

- `BellAudioEngine` 先准备 `BellModalAudioEngine`。模态引擎通过 `AVAudioSourceNode` 调用 C11 DSP，以 48 kHz 双声道实时合成；撞击消息通过有界队列传给渲染器。
- 如果模态引擎无法准备，或模态引擎拒绝某次撞击且 WAV 回退已就绪，则走 `BellSampleAudioEngine`。回退引擎加载五组 WAV、转换到 48 kHz 双声道，并用八个播放声部重叠播放。
- `BellAudioSessionController` 管理音频会话，并在中断、路由变化或媒体服务重置后通知上层恢复。
- `HapticService` 在设备支持时使用 Core Haptics 瞬态事件；不支持时跳过触觉，不影响模拟和音频。

## 调试参数

| 参数 | 当前默认值 | 用途 |
| --- | ---: | --- |
| 铃舌阻尼 | 1.35 | 控制运动衰减 |
| 回弹 | 0.24 | 控制法向碰撞后的恢复速度 |
| 最小撞击速度 | 0.30 | 过滤弱碰撞 |
| 碰撞冷却 | 0.080 s | 限制短时间内重复触发 |
| 平移响应 | 1.0 | 调整设备平移加速度对铃舌的影响 |
| 旋转响应 | 1.0 | 调整设备旋转对铃舌的影响 |
| 音量增益 | 1.0 | 调整采样回退音量 |
| 音高随机 | 0.018 | 调整采样回退音高微偏 |
| 触觉增益 | 0.72 | 调整撞击触觉强度 |

参数定义在 `RealisticBell/Models/BellConfig.swift`；几何、固定步长、速度上限和合成音色参数由各自模型提供。

## 当前实现状态

已实现三维铃舌模拟、几何安全边界、SceneKit 可交互铃体、显示惯性插值、模态撞击合成、WAV 采样回退、音频会话恢复、声音偏好和碰撞触觉。

接触时，`main` 模拟器可以根据持续外力变化发出新的离散冲击；**持续接触摩擦/滑动的连续声音尚未进入 `main`**。仓库另有 `feature/continuous-contact-sound` 分支（当前记录的分支头为 `c2526da`），包含该声音层的实现，但尚未合入 `main`。本节其余“当前实现”描述均指 `main`。

## 构建与验证边界

- Xcode 工程最低部署版本为 iOS 17；运行前需要选择可用的签名 Team。
- `Tests/` 中的 Swift/C 检查采用独立入口源码；当前 Xcode 工程仅定义应用 target，没有单独的测试 target。
- 是否构建通过、自动化检查通过或真机验收通过，需依据各自实际运行记录判断，不能从测试源码存在推断。
- CoreMotion、触觉、声音观感和铃舌显示仍需在目标真机上评估。
