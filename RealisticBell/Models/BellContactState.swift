import Foundation

struct BellContactState: Equatable {
    let timestamp: TimeInterval
    let isTouchingWall: Bool
    let normalAcceleration: Double
    let tangentialSpeed: Double
    let contactDirection: SIMD3<Double>

    static func detached(timestamp: TimeInterval) -> BellContactState {
        BellContactState(
            timestamp: timestamp,
            isTouchingWall: false,
            normalAcceleration: 0,
            tangentialSpeed: 0,
            contactDirection: SIMD3(0, -1, 0)
        )
    }

    var isFinite: Bool {
        timestamp.isFinite &&
            normalAcceleration.isFinite &&
            tangentialSpeed.isFinite &&
            contactDirection.x.isFinite &&
            contactDirection.y.isFinite &&
            contactDirection.z.isFinite
    }
}
