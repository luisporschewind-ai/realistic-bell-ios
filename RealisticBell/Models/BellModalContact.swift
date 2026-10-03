import Foundation

struct BellModalContactPayload: Equatable {
    let timestamp: TimeInterval
    let isTouchingWall: Bool
    let normalAcceleration: Double
    let contactDirection: SIMD3<Double>
    let tangentialSpeed: Double

    static let safeDetached = BellModalContactPayload(
        timestamp: 0,
        isTouchingWall: false,
        normalAcceleration: 0,
        contactDirection: SIMD3(0, -1, 0),
        tangentialSpeed: 0
    )
}

enum BellModalContactMapping {
    static func payload(for state: BellContactState) -> BellModalContactPayload {
        guard state.isFinite else { return .safeDetached }

        let length = sqrt(
            state.contactDirection.x * state.contactDirection.x +
            state.contactDirection.y * state.contactDirection.y +
            state.contactDirection.z * state.contactDirection.z
        )
        let direction = length > 1e-9
            ? state.contactDirection / length
            : SIMD3<Double>(0, -1, 0)

        return BellModalContactPayload(
            timestamp: state.timestamp,
            isTouchingWall: state.isTouchingWall,
            normalAcceleration: max(state.normalAcceleration, 0),
            contactDirection: direction,
            tangentialSpeed: max(state.tangentialSpeed, 0)
        )
    }
}
