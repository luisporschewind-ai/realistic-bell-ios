import CoreHaptics
import Foundation

final class HapticService {
    private var engine: CHHapticEngine?

    init() {}

    func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine.start()
            self.engine = engine
        } catch {
            print("Haptic engine unavailable: \(error)")
        }
    }

    func playImpact(strength: Double, gain: Double) {
        guard let engine else { return }

        let intensityValue = Float(min(max(strength * gain, 0.08), 1.0))
        let sharpnessValue = Float(min(0.55 + strength * 0.4, 1.0))

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityValue),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessValue)
            ],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptic playback failed: \(error)")
        }
    }
}
