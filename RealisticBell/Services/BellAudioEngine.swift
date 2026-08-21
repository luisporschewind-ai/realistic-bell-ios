final class BellAudioEngine: BellAudioPlaying {
    private let modal: BellAudioPlaying
    private let sample: BellAudioPlaying
    private var sampleReady = false
    private(set) var activeEngine: BellAudioBackend = .stopped

    init(modal: BellAudioPlaying, sample: BellAudioPlaying) {
        self.modal = modal
        self.sample = sample
    }

    @discardableResult
    func prepare() -> Bool {
        if activeEngine != .stopped { return true }
        let modalReady = modal.prepare()
        sampleReady = sample.prepare()
        activeEngine = BellAudioRoutingPolicy.preparedBackend(
            modalReady: modalReady,
            sampleReady: sampleReady
        )
        return activeEngine != .stopped
    }

    @discardableResult
    func play(impact: BellImpactEvent, config: BellConfig) -> Bool {
        switch activeEngine {
        case .modal:
            let modalAccepted = modal.play(impact: impact, config: config)
            activeEngine = BellAudioRoutingPolicy.eventBackend(
                active: .modal,
                modalAccepted: modalAccepted,
                sampleReady: sampleReady
            )
            if modalAccepted { return true }
            guard activeEngine == .sampleFallback else { return false }
            return sample.play(impact: impact, config: config)
        case .sampleFallback:
            return sample.play(impact: impact, config: config)
        case .stopped:
            return false
        }
    }

    func update(contact: BellContactState, profile: BellContactSoundProfile) {
        guard activeEngine == .modal else { return }
        modal.update(contact: contact, profile: profile)
    }

    func stop() {
        modal.stop()
        sample.stop()
        sampleReady = false
        activeEngine = .stopped
    }
}
