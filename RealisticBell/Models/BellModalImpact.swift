import Foundation

struct BellModalImpactPayload: Equatable {
    let timestamp: TimeInterval
    let strength: Double
    let normalSpeed: Double
    let contactDirection: SIMD3<Double>
    let tangentialSpeed: Double

    static let safeFallback = BellModalImpactPayload(
        timestamp: 0,
        strength: 0,
        normalSpeed: 0,
        contactDirection: SIMD3(0, -1, 0),
        tangentialSpeed: 0
    )
}

enum BellModalImpactMapping {
    static func payload(for event: BellImpactEvent) -> BellModalImpactPayload {
        guard event.timestamp.isFinite,
              event.strength.isFinite,
              event.normalSpeed.isFinite,
              event.contactDirection.x.isFinite,
              event.contactDirection.y.isFinite,
              event.contactDirection.z.isFinite,
              event.tangentialSpeed.isFinite else {
            return .safeFallback
        }

        let length = sqrt(
            event.contactDirection.x * event.contactDirection.x +
            event.contactDirection.y * event.contactDirection.y +
            event.contactDirection.z * event.contactDirection.z
        )
        let direction = length > 1e-9
            ? event.contactDirection / length
            : SIMD3<Double>(0, -1, 0)

        return BellModalImpactPayload(
            timestamp: event.timestamp,
            strength: clamp(event.strength, 0, 1),
            normalSpeed: clamp(event.normalSpeed, 0, 4),
            contactDirection: direction,
            tangentialSpeed: clamp(event.tangentialSpeed, 0, 4)
        )
    }

    private static func clamp(_ value: Double, _ minimum: Double, _ maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}
