import Foundation

struct BellMotionInput: Equatable {
    let gravity: SIMD3<Double>
    let userAcceleration: SIMD3<Double>
    let rotationRate: SIMD3<Double>
    let timestamp: TimeInterval

    init(
        gravity: SIMD3<Double>,
        userAcceleration: SIMD3<Double>,
        rotationRate: SIMD3<Double>,
        timestamp: TimeInterval
    ) {
        self.gravity = gravity
        self.userAcceleration = userAcceleration
        self.rotationRate = rotationRate
        self.timestamp = timestamp
    }

    static let zero = BellMotionInput(
        gravity: SIMD3(0, -1, 0),
        userAcceleration: .zero,
        rotationRate: .zero,
        timestamp: 0
    )

    init(sample: MotionSample) {
        self.init(
            gravity: SIMD3(sample.gravityX, sample.gravityY, sample.gravityZ),
            userAcceleration: SIMD3(
                sample.accelerationX,
                sample.accelerationY,
                sample.accelerationZ
            ),
            rotationRate: SIMD3(sample.rotationX, sample.rotationY, sample.rotationZ),
            timestamp: sample.timestamp
        )
    }

    var isFinite: Bool {
        gravity.x.isFinite && gravity.y.isFinite && gravity.z.isFinite &&
        userAcceleration.x.isFinite && userAcceleration.y.isFinite && userAcceleration.z.isFinite &&
        rotationRate.x.isFinite && rotationRate.y.isFinite && rotationRate.z.isFinite &&
        timestamp.isFinite
    }
}
