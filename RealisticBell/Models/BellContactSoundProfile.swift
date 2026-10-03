struct BellContactSoundProfile: Equatable {
    let loadReference: Double
    let speedReference: Double
    let surfaceSamplesPerMeter: Double
    let excitationGain: Double
    let attackSeconds: Double
    let releaseSeconds: Double
    let timeoutSeconds: Double
    let firstExcitedModeIndex: Int

    static let smallBrassHandbell = BellContactSoundProfile(
        loadReference: 9.80665,
        speedReference: 0.55,
        surfaceSamplesPerMeter: 1_400,
        excitationGain: 1.8,
        attackSeconds: 0.008,
        releaseSeconds: 0.040,
        timeoutSeconds: 0.080,
        firstExcitedModeIndex: 4
    )
}
