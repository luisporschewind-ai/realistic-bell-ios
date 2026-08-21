protocol BellAudioPlaying: AnyObject {
    @discardableResult
    func prepare() -> Bool

    @discardableResult
    func play(impact: BellImpactEvent, config: BellConfig) -> Bool

    func update(contact: BellContactState, profile: BellContactSoundProfile)

    func stop()
}

extension BellAudioPlaying {
    func update(contact: BellContactState, profile: BellContactSoundProfile) {}
}
