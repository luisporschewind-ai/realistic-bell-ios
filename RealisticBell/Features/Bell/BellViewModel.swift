import Foundation
import SwiftUI

@MainActor
final class BellViewModel: ObservableObject {
    @Published var config = BellConfig()
    @Published var accelerationMagnitude: Double = 0
    @Published var lastCollisionStrength: Double = 0
    @Published var collisionCount: Int = 0
    @Published var motionAvailable: Bool = true
    @Published var debugVisible: Bool = false
    @Published var isRunning: Bool = false
    @Published var soundEnabled = BellSoundPreference().isEnabled {
        didSet {
            guard soundEnabled != oldValue else { return }
            if soundEnabled {
                prepareAudioIfNeeded()
            } else {
                stopAudio()
            }
        }
    }
    @Published private(set) var clapperState = BellClapperState.rest

    private let motionService = MotionService()
    private var clapperSimulator = BellClapperSimulator()
    private var impactMetrics = BellImpactMetrics()
    private var audioEngine: BellAudioEngine?
    private var audioSessionController: BellAudioSessionController?
    private lazy var hapticService = HapticService()

    init() {
        motionService.onAvailabilityChanged = { [weak self] available in
            Task { @MainActor in
                self?.motionAvailable = available
            }
        }

        motionService.onSample = { [weak self] sample in
            guard let self else { return }
            Task { @MainActor in
                self.handle(sample)
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        clapperSimulator.reset()
        clapperState = .rest
        if BellSoundPreference(isEnabled: soundEnabled).shouldPrepareAudio {
            prepareAudioIfNeeded()
        }
        hapticService.prepare()
        motionService.start()
    }

    func stop() {
        motionService.stop()
        stopAudio()
        clapperSimulator.reset()
        clapperState = .rest
        isRunning = false
    }

    private func handle(_ sample: MotionSample) {
        accelerationMagnitude = sample.accelerationMagnitude
        clapperSimulator.update(parameters: config.clapperParameters)
        let step = clapperSimulator.step(input: BellMotionInput(sample: sample))
        clapperState = step.state
        guard let impact = step.impact else { return }

        handleImpact(impact)
    }

    private func handleImpact(_ impact: BellImpactEvent) {
        impactMetrics.record(impact)
        collisionCount = impactMetrics.count
        lastCollisionStrength = impactMetrics.lastStrength
        if BellSoundPreference(isEnabled: soundEnabled).shouldPlaySound {
            audioEngine?.play(impact: impact, config: config)
        }
        hapticService.playImpact(strength: impact.strength, gain: config.hapticGain)
    }

    private func prepareAudioIfNeeded() {
        guard isRunning else { return }
        if audioEngine != nil { return }

        let sessionController = BellAudioSessionController()
        sessionController.onRecoveryNeeded = { [weak self] in
            self?.recoverAudioIfNeeded()
        }
        guard sessionController.activate() else {
            sessionController.deactivate()
            return
        }

        let engine = BellAudioEngine(
            modal: BellModalAudioEngine(),
            sample: BellSampleAudioEngine()
        )
        guard engine.prepare() else {
            engine.stop()
            sessionController.deactivate()
            return
        }
        audioSessionController = sessionController
        audioEngine = engine
    }

    private func stopAudio() {
        audioEngine?.stop()
        audioEngine = nil
        audioSessionController?.deactivate()
        audioSessionController = nil
    }

    private func recoverAudioIfNeeded() {
        guard soundEnabled, isRunning else { return }
        stopAudio()
        prepareAudioIfNeeded()
    }
}
