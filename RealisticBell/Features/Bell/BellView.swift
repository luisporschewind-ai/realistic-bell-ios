import SwiftUI

struct BellView: View {
    @StateObject private var viewModel = BellViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                BellSceneView(
                    clapperState: viewModel.clapperState
                )
                .frame(height: 440)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.black.opacity(0.05), lineWidth: 1)
                }

                VStack(spacing: 6) {
                    Text("摇动手机")
                        .font(.largeTitle.bold())
                    Text("像摇一只真的铃一样")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Toggle("声音", isOn: $viewModel.soundEnabled)
                    .font(.headline)
                    .tint(.orange)
                    .padding(.horizontal, 8)

                if !viewModel.motionAvailable {
                    Label("当前设备不支持 CoreMotion 真机数据", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }

                HStack(spacing: 24) {
                    metric(title: "加速度", value: String(format: "%.2f g", viewModel.accelerationMagnitude))
                    metric(title: "碰撞", value: "\(viewModel.collisionCount)")
                    metric(title: "力度", value: String(format: "%.2f", viewModel.lastCollisionStrength))
                }

                Spacer(minLength: 8)

                Text("长按铃铛显示调试参数")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.7) {
                viewModel.debugVisible.toggle()
            }
            .sheet(isPresented: $viewModel.debugVisible) {
                DebugPanelView(config: $viewModel.config)
                    .presentationDetents([.medium, .large])
            }
            .onAppear { viewModel.start() }
            .onDisappear { viewModel.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.start()
                } else {
                    viewModel.stop()
                }
            }
            .navigationTitle("Realistic Bell")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.headline, design: .monospaced))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
