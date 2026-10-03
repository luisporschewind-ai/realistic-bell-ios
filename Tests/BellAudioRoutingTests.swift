@main
struct BellAudioRoutingTests {
    static func main() {
        testModalPreparationHasPriority()
        testSampleFallbackIsSelectedWhenModalPreparationFails()
        testBothPreparationFailuresStayStopped()
        testRejectedModalEventFallsBackToPreparedSamples()
        testModalBackendReceivesContinuousContact()
        testSampleFallbackDoesNotFakeContinuousContact()
        testStopReachesBothPlayers()
        print("BellAudioRoutingTests passed")
    }

    private static func testModalPreparationHasPriority() {
        let modal = FakePlayer(prepareResult: true)
        let sample = FakePlayer(prepareResult: true)
        let engine = BellAudioEngine(modal: modal, sample: sample)

        precondition(engine.prepare())
        precondition(engine.activeEngine == .modal)
        precondition(modal.prepareCount == 1)
        precondition(sample.prepareCount == 1)
    }

    private static func testSampleFallbackIsSelectedWhenModalPreparationFails() {
        let modal = FakePlayer(prepareResult: false)
        let sample = FakePlayer(prepareResult: true)
        let engine = BellAudioEngine(modal: modal, sample: sample)

        precondition(engine.prepare())
        precondition(engine.activeEngine == .sampleFallback)
    }

    private static func testBothPreparationFailuresStayStopped() {
        let engine = BellAudioEngine(
            modal: FakePlayer(prepareResult: false),
            sample: FakePlayer(prepareResult: false)
        )

        precondition(!engine.prepare())
        precondition(engine.activeEngine == .stopped)
    }

    private static func testRejectedModalEventFallsBackToPreparedSamples() {
        let modal = FakePlayer(prepareResult: true, playResults: [false])
        let sample = FakePlayer(prepareResult: true, playResults: [true])
        let engine = BellAudioEngine(modal: modal, sample: sample)
        precondition(engine.prepare())

        precondition(engine.play(impact: event(), config: BellConfig()))
        precondition(modal.playCount == 1)
        precondition(sample.playCount == 1)
        precondition(engine.activeEngine == .sampleFallback)
    }

    private static func testStopReachesBothPlayers() {
        let modal = FakePlayer(prepareResult: true)
        let sample = FakePlayer(prepareResult: true)
        let engine = BellAudioEngine(modal: modal, sample: sample)
        _ = engine.prepare()

        engine.stop()
        precondition(modal.stopCount == 1)
        precondition(sample.stopCount == 1)
        precondition(engine.activeEngine == .stopped)
    }

    private static func testModalBackendReceivesContinuousContact() {
        let modal = FakePlayer(prepareResult: true)
        let sample = FakePlayer(prepareResult: true)
        let engine = BellAudioEngine(modal: modal, sample: sample)
        precondition(engine.prepare())

        engine.update(contact: contact(), profile: .smallBrassHandbell)

        precondition(modal.contactUpdates.count == 1)
        precondition(sample.contactUpdates.isEmpty)
        precondition(engine.activeEngine == .modal)
    }

    private static func testSampleFallbackDoesNotFakeContinuousContact() {
        let modal = FakePlayer(prepareResult: false)
        let sample = FakePlayer(prepareResult: true)
        let engine = BellAudioEngine(modal: modal, sample: sample)
        precondition(engine.prepare())

        engine.update(contact: contact(), profile: .smallBrassHandbell)

        precondition(modal.contactUpdates.isEmpty)
        precondition(sample.contactUpdates.isEmpty)
        precondition(engine.activeEngine == .sampleFallback)
    }

    private static func event() -> BellImpactEvent {
        BellImpactEvent(
            timestamp: 1,
            strength: 0.6,
            normalSpeed: 1,
            contactDirection: SIMD3(0.2, -0.9, 0.1),
            contactPoint: SIMD3(0.1, -0.8, 0.05),
            tangentialSpeed: 0.2
        )
    }

    private static func contact() -> BellContactState {
        BellContactState(
            timestamp: 1,
            isTouchingWall: true,
            normalAcceleration: 4.5,
            tangentialSpeed: 0.3,
            contactDirection: SIMD3(0.2, -0.9, 0.1)
        )
    }
}

private final class FakePlayer: BellAudioPlaying {
    let prepareResult: Bool
    var playResults: [Bool]
    private(set) var prepareCount = 0
    private(set) var playCount = 0
    private(set) var stopCount = 0
    private(set) var contactUpdates: [BellContactState] = []

    init(prepareResult: Bool, playResults: [Bool] = [true]) {
        self.prepareResult = prepareResult
        self.playResults = playResults
    }

    func prepare() -> Bool {
        prepareCount += 1
        return prepareResult
    }

    func play(impact: BellImpactEvent, config: BellConfig) -> Bool {
        playCount += 1
        return playResults.isEmpty ? false : playResults.removeFirst()
    }

    func update(contact: BellContactState, profile: BellContactSoundProfile) {
        contactUpdates.append(contact)
    }

    func stop() {
        stopCount += 1
    }
}
