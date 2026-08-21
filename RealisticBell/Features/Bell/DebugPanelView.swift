import SwiftUI

struct DebugPanelView: View {
    @Binding var config: BellConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("铃舌物理") {
                    parameter("阻尼", value: $config.clapperDamping, range: 0.6...3.0, format: "%.2f")
                    parameter("回弹", value: $config.clapperRestitution, range: 0...0.6, format: "%.2f")
                    parameter("最小撞击速度", value: $config.minimumImpactSpeed, range: 0.1...1.0, format: "%.2f")
                    parameter("碰撞冷却", value: $config.collisionCooldown, range: 0.04...0.25, format: "%.3f s")
                    parameter("平移响应", value: $config.translationGain, range: 0.5...1.8, format: "%.2f")
                    parameter("旋转响应", value: $config.rotationGain, range: 0.5...1.4, format: "%.2f")
                }

                Section("反馈") {
                    parameter("Volume", value: $config.volumeGain, range: 0.3...1.3, format: "%.2f")
                    parameter("Pitch Random", value: $config.pitchRandomness, range: 0...0.05, format: "%.3f")
                    parameter("Haptic", value: $config.hapticGain, range: 0...1, format: "%.2f")
                }

                Section {
                    Button("恢复默认值") {
                        config = BellConfig()
                    }
                }
            }
            .navigationTitle("调试参数")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func parameter(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
