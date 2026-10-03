# Realistic Bell iOS — V0.2

Realistic Bell 是一个原生 SwiftUI / SceneKit 手铃仿真 App。它读取设备运动数据，模拟铃舌在铃体中的三维运动，并在碰撞或持续接触时播放铜铃声音和触觉反馈。

## 当前实现

- SwiftUI 主界面和长按呼出的调试面板，设备锁定竖屏。
- CoreMotion `deviceMotion`，采样间隔 100 Hz；使用重力、平移加速度和旋转速度驱动铃舌。
- 固定步长三维铃舌模拟，包含惯性、碰撞、回弹和铃体边界约束；SceneKit 显示层对方向和角速度插值。
- 撞击声由 48 kHz 双声道 C11 模态合成器播放，余音可以自然叠加；合成引擎不可用时回退到五组 WAV 采样。
- 持续接触声由铃舌的法向载荷和切向速度驱动。慢速转动时声音较稀疏、偏暗，快速转动时声音更密、更亮。
- 接触声使用固定的多尺度表面粗糙度轨迹激发高阶模态，不直接混入白噪声或粉红噪声。接触状态中断超过 `80 ms` 后自动释放。
- 声音默认开启，可单独关闭。Core Haptics 提供瞬态反馈；音频中断、路由变化和音频服务重置后会尝试恢复。
- 只有铃舌模拟产生的真实碰撞事件会增加碰撞计数并触发撞击反馈。

## 打开和运行

1. 用 Xcode 打开 `RealisticBell.xcodeproj`。
2. 在 Signing & Capabilities 中选择自己的 Development Team。
3. 连接 iPhone，保持竖屏并运行。
4. 摇动设备体验；打开“声音”开关可启用声音，长按铃铛约 0.7 秒打开调试参数。

项目最低部署版本为 iOS 17。CoreMotion、Core Haptics、三维惯性和最终声音体验需要在真机上评估；模拟器不能代替真机验收。本仓库不是 App Store 或 TestFlight 发布包。

## 调试参数

调试面板可以调整铃舌阻尼、回弹、最小撞击速度、碰撞冷却、平移与旋转响应、音量、音高随机范围和触觉强度，也可以恢复默认值。默认物理参数以 `RealisticBell/Models/BellConfig.swift` 为准。

## 持续接触声验收矩阵

1. 静止或只把铃舌压在铃壁上：不应出现持续刮擦声。
2. 缓慢转圈：应出现稀疏、安静、偏暗的铜质细颗粒声。
3. 中速转圈：颗粒更密，但仍保留不规则的表面感。
4. 快速转圈：声音更亮、更密，不应变成连续白噪声或突兀的摩擦声。
5. 慢速到快速再减速：音色和密度应连续变化，不应在传感器数据包边界产生点击声。
6. 铃舌脱离后反向撞击：接触层应先释放，随后保留清晰撞击声和余音。
7. 正置与倒置摇铃：画面、撞击、接触声、计数和触觉应保持物理一致。
8. 关闭声音并播放系统音乐：本应用不应抢占或中断音乐。

如需调整真机听感，优先修改 `BellContactSoundProfile.smallBrassHandbell` 的声学参数，不要改变已验收的铃铛几何与碰撞物理来迁就声音。

## 自动验证记录

2026-08-21 的记录包括：

- Swift 独立测试：`18/18` 通过。
- C11 模态 DSP 普通构建、AddressSanitizer 和 UndefinedBehaviorSanitizer 检查通过。
- 无签名 `iphoneos` Debug 构建通过。
- 音频渲染回调内无动态内存分配、锁、日志、文件 I/O 或 Swift 回调。
- 接触状态的物理判定只由 `BellClapperSimulator` 产生。

这些自动验证记录不能代替本次合并后的构建检查或真机听感验收。

## 目录

```text
RealisticBell/
  App/                 SwiftUI 应用入口
  Features/Bell/       页面、视图模型、SceneKit 场景和调试面板
  Models/              运动输入、铃舌状态、几何、声音配置与撞击事件
  Services/            CoreMotion、铃舌模拟、音频路由、音频引擎和触觉
  AudioDSP/            C11 模态声音合成器
  Assets.xcassets/     App 图标
  Resources/Audio/     WAV 撞击采样回退资源
  Support/             Swift 与 C 的桥接头
Tests/                 独立 Swift/C 行为检查源码
docs/superpowers/      设计规格与实施计划记录
```

## 当前边界

- 五组 WAV 是合成撞击引擎的回退采样，不是完整的多力度真实录音库，也不用于模拟持续摩擦声。
- `Tests/` 收录独立 Swift/C 行为检查源码；当前 Xcode 工程没有单独的测试 target。
- 参数和物理观感仍应以目标 iPhone 真机体验为准。
- 持续接触声功能已合入 `main`；上一版基线标签为 `realistic-bell-baseline-v1`（提交 `8d86d14`）。
