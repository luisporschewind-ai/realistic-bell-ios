import Foundation

struct BellConfig {
    var clapperDamping: Double = 1.35
    var clapperRestitution: Double = 0.24
    var minimumImpactSpeed: Double = 0.30
    var collisionCooldown: TimeInterval = 0.080
    var translationGain: Double = 1.0
    var rotationGain: Double = 1.0
    var volumeGain: Double = 1.0
    var pitchRandomness: Double = 0.018
    var hapticGain: Double = 0.72

    var clapperParameters: BellClapperParameters {
        let tuned = BellClapperParameters.referenceTuned
        return BellClapperParameters(
            length: tuned.length,
            maximumAngle: tuned.maximumAngle,
            damping: clapperDamping,
            restitution: clapperRestitution,
            maximumAngularSpeed: tuned.maximumAngularSpeed,
            minimumImpactSpeed: minimumImpactSpeed,
            fullStrengthImpactSpeed: tuned.fullStrengthImpactSpeed,
            contactImpulseThreshold: tuned.contactImpulseThreshold,
            collisionCooldown: collisionCooldown,
            fixedTimeStep: tuned.fixedTimeStep,
            maximumAccumulatedTime: tuned.maximumAccumulatedTime,
            translationGain: translationGain,
            rotationGain: rotationGain
        )
    }
}
