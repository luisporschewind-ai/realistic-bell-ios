# Realistic Bell iOS — V0.1

一个苹果原生 SwiftUI 仿真摇铃实验：摇动 iPhone 时，根据 CoreMotion 的真实运动数据触发铃铛碰撞声和 Core Haptics 触觉反馈。

## V0.1 已实现

- SwiftUI 单页交互
- CoreMotion `deviceMotion` 100Hz 采样
- 加速度峰值 + 方向反转/jerk 碰撞判定
- 8 voice `AVAudioEngine` 重叠播放，允许自然余音叠加
- 5 个临时 WAV 铃声样本随机播放
- 根据碰撞力度控制音量
- 小范围随机 Pitch，降低机械重复感
- CoreHaptics 短促碰撞反馈
- 长按主界面打开 Debug Panel，可实时调整 threshold / cooldown / jerk / volume / pitch / haptic

## 运行

1. 使用 Xcode 26.x 打开 `RealisticBell.xcodeproj`
2. 在 Signing & Capabilities 选择自己的 Development Team
3. 连接 iPhone 真机
4. Run
5. 摇动手机测试

> CoreMotion 与触觉体验必须以真机为准，模拟器不用于验收。

## 调参

主界面长按约 0.7 秒打开调参面板。

默认参数：

- Collision Threshold: `0.82`
- Cooldown: `0.115s`
- Jerk Threshold: `0.55`
- Minimum Strength: `0.12`
- Volume Gain: `1.0`
- Pitch Randomness: `0.018`
- Haptic Gain: `0.72`

第一轮真机测试重点观察：

- 轻微拿起手机是否误响
- 普通左右摇是否稳定触发
- 快速摇动是否过密/漏响
- 停止后是否不再生成新碰撞
- 声音与触觉是否主观同步

## 当前已知限制

- 当前 5 个 WAV 是为 V0.1 算法验证生成的临时铃声，不代表最终音色品质。
- V0.1 尚未使用虚拟铃珠刚体模型；当前碰撞算法是启发式算法。
- 尚未进行具体 iPhone 型号的真机参数标定。
- 无 3D、无联网、无账号、无商业化功能。

## 下一阶段

V0.2 的核心不是继续堆 UI，而是把碰撞系统升级为“虚拟铃珠”：根据设备加速度、重力、虚拟球位置和速度计算真实撞壁事件，再用真实铃铛多力度录音替换临时资源。
