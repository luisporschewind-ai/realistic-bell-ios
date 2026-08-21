# iOS 仿真摇铃 App — V0.1 实施文档

## 1. 项目目标

开发一个使用苹果原生技术栈实现的“仿真摇铃” App。

核心体验：

> 用户摇动 iPhone 时，App 根据手机真实运动状态实时产生铃铛碰撞声与触觉反馈，让用户感觉手机内部真的存在一只铃铛。

V0.1 不追求完整产品形态，优先验证以下三件事：

1. 摇动识别是否自然
2. 铃声反馈是否与运动强度匹配
3. 声音与触觉是否具有明显的“物理碰撞感”

---

## 2. V0.1 范围

### 必须实现

- Swift / SwiftUI 原生 App
- CoreMotion 实时读取设备运动数据
- 检测有效摇动/碰撞事件
- 根据摇动强度控制音量
- 多铃声采样随机播放，避免机械重复
- AVAudioEngine 音频播放
- CoreHaptics 碰撞触觉
- 基础参数调试面板
- 真机运行

### 暂不实现

- 3D 铃铛
- RealityKit
- AI 音频生成
- 账号系统
- 云端服务
- 数据统计
- 内购
- 儿童玩法
- 多主题 UI
- App Store 上架素材

---

## 3. 技术栈

- Language: Swift
- UI: SwiftUI
- Motion: CoreMotion
- Audio: AVFoundation / AVAudioEngine
- Haptics: CoreHaptics
- Minimum target: iOS 17+
- IDE: Xcode 26.x
- Architecture: 简单 MVVM / Service 分层即可

禁止为了架构而架构。

V0.1 不引入：

- RxSwift
- Combine 复杂流
- 第三方依赖
- CocoaPods
- SPM 第三方库

系统 Framework 足够完成首版。

---

## 4. 核心架构

建议结构：

```text
BellApp
├── App
│   └── BellApp.swift
│
├── Features
│   └── Bell
│       ├── BellView.swift
│       ├── BellViewModel.swift
│       └── DebugPanelView.swift
│
├── Services
│   ├── MotionService.swift
│   ├── BellPhysicsEngine.swift
│   ├── BellAudioEngine.swift
│   └── HapticService.swift
│
├── Models
│   ├── MotionSample.swift
│   ├── BellCollision.swift
│   └── BellConfig.swift
│
└── Resources
    └── Audio
        ├── bell_hit_01.wav
        ├── bell_hit_02.wav
        ├── bell_hit_03.wav
        ├── bell_hit_04.wav
        └── bell_hit_05.wav
```

---

## 5. 数据流

```text
CoreMotion
    ↓
MotionService
    ↓
设备运动数据
    ↓
BellPhysicsEngine
    ↓
判断虚拟铃珠是否发生碰撞
    ↓
BellCollision
    ├── strength
    ├── direction
    └── timestamp
    ↓
┌──────────────┬──────────────┐
│              │              │
AudioEngine    HapticService
│              │
铃声            触觉
```

原则：

**MotionService 只负责采集数据。**

**BellPhysicsEngine 决定什么时候“撞铃”。**

**AudioEngine 不负责判断摇动。**

避免把所有逻辑堆进 ViewModel。

---

## 6. MotionService

使用：

```swift
CMMotionManager
```

优先读取：

```swift
deviceMotion
```

而不是只使用 accelerometer。

建议：

```swift
motionManager.deviceMotionUpdateInterval = 1.0 / 100.0
```

即约 100Hz。

采集：

```swift
userAcceleration
gravity
rotationRate
attitude
```

定义：

```swift
struct MotionSample {
    let acceleration: SIMD3<Double>
    let gravity: SIMD3<Double>
    let rotationRate: SIMD3<Double>
    let timestamp: TimeInterval
}
```

注意：

`userAcceleration` 已经去除了重力影响，比直接使用 accelerometer 更适合判断主动摇动。

---

## 7. V0.1 碰撞算法

第一版不要做完整刚体物理模拟。

采用：

**加速度峰值 + 方向反转 + 冷却时间**

### 7.1 合加速度

```text
magnitude = sqrt(x² + y² + z²)
```

### 7.2 基础触发条件

当：

```text
magnitude > threshold
```

则认为发生一次潜在碰撞。

初始建议：

```text
threshold = 0.8
```

需要真机调整。

---

### 7.3 方向反转

真实摇铃通常发生：

```text
向左加速
→
减速
→
向右加速
→
铃珠撞击
```

因此增加方向变化检测。

可以先使用主运动轴：

```text
abs(currentAxis - previousAxis)
```

或检测 acceleration vector 的 dot product。

如果：

```text
dot(previousDirection, currentDirection) < 0
```

说明方向明显发生反转。

结合 magnitude 判断碰撞。

---

### 7.4 防止连续误触发

加入 cooldown：

```text
80 ~ 150ms
```

初始：

```text
120ms
```

一次碰撞发生后：

120ms 内不再触发新的铃声。

否则快速采样会导致：

```text
叮叮叮叮叮叮叮
```

变成机关枪。

---

## 8. BellCollision

定义：

```swift
struct BellCollision {
    let strength: Double
    let timestamp: TimeInterval
}
```

strength：

```text
0.0 ... 1.0
```

例如：

```text
0.2 = 轻碰
0.5 = 普通
0.9 = 重击
```

计算：

```text
strength = normalize(magnitude)
```

例如：

```text
0.8g → 0.2
1.5g → 0.6
2.5g → 1.0
```

实际曲线需要真机调试。

---

## 9. BellAudioEngine

不要使用单一音频循环播放。

使用：

```swift
AVAudioEngine
AVAudioPlayerNode
AVAudioMixerNode
```

至少准备：

```text
bell_hit_01.wav
bell_hit_02.wav
bell_hit_03.wav
bell_hit_04.wav
bell_hit_05.wav
```

每次 collision：

随机选择一个 sample。

同时加入轻微随机变化：

```text
Volume
Pitch
```

例如：

```text
volume = 0.25 ~ 1.0
pitch random = ±2%
```

注意：

随机范围必须小。

太大会让铃铛听起来像电子音效。

---

## 10. 播放规则

示例：

```text
collision.strength = 0.2

volume ≈ 0.3
pitch ≈ random(0.98...1.02)
```

重击：

```text
collision.strength = 0.9

volume ≈ 0.95
pitch ≈ random(0.99...1.03)
```

重要：

允许前一个铃声余音没有结束时播放下一个碰撞音。

否则不会产生真实铃铛的：

```text
叮——铃——叮——铃——
```

叠加效果。

---

## 11. 音频资源策略

V0.1 首先允许使用临时 WAV 资源验证算法。

最终正式版建议真实录制。

每一种铃铛至少录：

```text
轻碰：5~10 个
中碰：5~10 个
重碰：5~10 个
```

约：

```text
15~30 个样本 / 铃铛
```

录制格式推荐：

```text
WAV
44.1kHz / 48kHz
24-bit
```

正式资源必须确认版权可商用。

---

## 12. CoreHaptics

每次 BellCollision 同步产生触觉。

规则：

```text
strength → haptic intensity
```

例如：

```text
0.2 → 极轻
0.5 → 中等
1.0 → 强烈但短促
```

碰撞触觉应该：

- 短
- 脆
- 与声音同时发生

不要做成持续震动。

V0.1 可先使用：

```swift
CHHapticEvent
```

后续再调 transient sharpness。

---

## 13. 主界面

V0.1 UI 极简。

页面中心：

```text
🔔

摇动手机
```

下方显示：

```text
当前加速度
碰撞强度
触发次数
```

Debug 模式下显示参数。

普通模式隐藏。

---

## 14. Debug Panel

这一部分必须实现。

因为该项目 70% 的工作量实际上是“调参数”。

需要实时调整：

```text
Collision Threshold
Cooldown
Minimum Strength
Volume Gain
Pitch Randomness
Haptic Strength
```

例如：

```text
Threshold        0.8
Cooldown         120ms
Volume Gain      1.0
Pitch Random     0.02
Haptic Gain      0.7
```

所有参数放：

```swift
BellConfig
```

不要散落 magic number。

---

## 15. BellConfig

示例：

```swift
struct BellConfig {

    var collisionThreshold: Double = 0.8

    var collisionCooldown: TimeInterval = 0.12

    var minimumStrength: Double = 0.15

    var volumeGain: Double = 1.0

    var pitchRandomness: Double = 0.02

    var hapticGain: Double = 0.7
}
```

调试面板直接修改 BellConfig。

---

## 16. 第一阶段验收标准

### 必须达到

轻轻晃动手机：

```text
基本不响 / 偶尔轻响
```

正常摇动：

```text
稳定产生铃声
```

快速左右摇：

```text
产生连续但不机械的铃声
```

停止摇动：

```text
立即停止产生新碰撞
只剩铃声自然余音
```

不同力度：

```text
声音大小明显不同
```

每次摇：

```text
音色存在细微随机变化
```

声音与触觉：

```text
主观感觉基本同步
```

---

## 17. 不允许出现的问题

### 1.

轻微拿起手机：

```text
叮
```

不能频繁发生。

### 2.

持续摇动：

```text
叮叮叮叮叮叮
```

每个声音完全一样。

### 3.

声音明显滞后于动作。

### 4.

停止动作后仍不断产生新铃声。

### 5.

App 在模拟器表现正常，但未进行真机调试。

本项目必须以真机测试结果为准。

---

## 18. 第二阶段物理升级

V0.1 完成后再考虑。

目标：

从：

```text
摇动检测
```

升级成：

```text
虚拟铃珠模拟
```

模型：

```text
手机 = 铃铛外壳

内部存在一个虚拟质量球
```

维护：

```text
position
velocity
acceleration
```

根据：

```text
设备加速度
+
重力
```

更新铃珠状态。

当：

```text
virtualBallPosition >= bellBoundary
```

发生碰撞。

然后：

```text
velocity *= -restitution
```

这时真正形成：

```text
手机运动
→
虚拟铃珠运动
→
碰撞
→
声音
```

这是未来“极度仿真”的关键版本。

V0.1 不做。

---

## 19. 开发顺序

Codex 请严格按照以下顺序开发。

### Phase 1

创建 SwiftUI 工程骨架。

完成：

```text
BellView
BellViewModel
MotionService
BellConfig
```

先显示实时 motion 数据。

---

### Phase 2

实现：

```text
BellPhysicsEngine
```

输出：

```swift
BellCollision
```

暂时只在 UI 显示：

```text
Collision!
strength: 0.63
```

不要急着接声音。

---

### Phase 3

加入：

```text
BellAudioEngine
```

实现多音频随机播放。

---

### Phase 4

加入：

```text
HapticService
```

完成声音 + 触觉同步。

---

### Phase 5

完成 Debug Panel。

真机调节：

```text
threshold
cooldown
strength curve
volume
haptic
```

---

### Phase 6

优化：

```text
误触发
快速摇动
慢速摇动
停止响应
```

---

## 20. Codex 开发原则

1. 优先可运行代码
2. 每完成一个 Phase 确保工程可编译
3. 不提前实现未来功能
4. 不引入无必要第三方依赖
5. 不过度抽象
6. Motion / Physics / Audio / Haptics 必须解耦
7. 所有物理参数统一放 BellConfig
8. 关键算法写注释说明原因
9. 所有功能以真机体验为最终标准

---

# 给 Codex 的执行指令

请根据本文件实现 `iOS 仿真摇铃 App V0.1`。

第一目标不是 UI，而是构建一个可靠的：

```text
Motion
→
Collision
→
Audio
→
Haptic
```

反馈闭环。

请按 Phase 1 → Phase 6 顺序实现。

每完成一个 Phase：

1. 编译工程
2. 修复所有编译错误
3. 简述修改内容
4. 再进入下一 Phase

不要自行扩大需求。

如果音频素材当前缺失：

建立 Audio Resources 接口和占位机制，不阻塞其他模块开发，并明确列出需要补充的 WAV 文件名。

最终交付应至少包含：

- 可编译 Xcode 工程
- 真机 CoreMotion 支持
- BellPhysicsEngine
- BellAudioEngine
- CoreHaptics
- Debug 参数面板
- README
- 当前已知问题列表

---

## V0.1 成功标准

不是：

> App 能检测 Shake。

而是：

> 闭上眼睛摇手机时，已经开始产生“手机里像有个铃铛”的感觉。

如果这个感觉没有出现，V0.1 就还没有完成。
