protocol BellAudioPlaying: AnyObject {
    @discardableResult
    func prepare() -> Bool

    @discardableResult
    func play(impact: BellImpactEvent, config: BellConfig) -> Bool

    func stop()
}
