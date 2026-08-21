@main
struct BellModalImpactMappingTests {
    static func main() {
        let event = BellImpactEvent(
            timestamp: 3.5,
            strength: 1.4,
            normalSpeed: -0.2,
            contactDirection: SIMD3(3, 4, 0),
            contactPoint: SIMD3(2, -3, 1),
            tangentialSpeed: 9
        )

        let payload = BellModalImpactMapping.payload(for: event)
        precondition(payload.timestamp == 3.5)
        precondition(payload.strength == 1)
        precondition(payload.normalSpeed == 0)
        precondition(abs(payload.contactDirection.x - 0.6) < 0.000_001)
        precondition(abs(payload.contactDirection.y - 0.8) < 0.000_001)
        precondition(abs(payload.contactDirection.z) < 0.000_001)
        precondition(payload.tangentialSpeed == 4)

        let invalid = BellImpactEvent(
            timestamp: .nan,
            strength: .nan,
            normalSpeed: .infinity,
            contactDirection: SIMD3(.nan, 0, 0),
            contactPoint: .zero,
            tangentialSpeed: -.infinity
        )
        precondition(BellModalImpactMapping.payload(for: invalid) == .safeFallback)
        print("BellModalImpactMappingTests passed")
    }
}
