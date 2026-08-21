import Foundation

struct BellClapperParameters: Equatable {
    let length: Double
    let maximumAngle: Double
    let damping: Double
    let restitution: Double
    let maximumAngularSpeed: Double
    let minimumImpactSpeed: Double
    let fullStrengthImpactSpeed: Double
    let contactImpulseThreshold: Double
    let collisionCooldown: TimeInterval
    let fixedTimeStep: TimeInterval
    let maximumAccumulatedTime: TimeInterval
    let translationGain: Double
    let rotationGain: Double

    static let referenceTuned = BellClapperParameters(
        length: 0.82,
        maximumAngle: 0.36,
        damping: 1.35,
        restitution: 0.24,
        maximumAngularSpeed: 9.0,
        minimumImpactSpeed: 0.30,
        fullStrengthImpactSpeed: 2.40,
        contactImpulseThreshold: 0.08,
        collisionCooldown: 0.080,
        fixedTimeStep: 0.010,
        maximumAccumulatedTime: 0.050,
        translationGain: 1.0,
        rotationGain: 1.0
    )
}
