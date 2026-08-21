@main
struct BellModalContactMappingTests {
    static func main() {
        testValidPhysicalUnitsAndDirectionArePreserved()
        testNegativeLoadAndSpeedAreClampedToZero()
        testNonFiniteInputBecomesSafeDetachedPayload()
        print("BellModalContactMappingTests passed")
    }

    private static func testValidPhysicalUnitsAndDirectionArePreserved() {
        let state = BellContactState(
            timestamp: 4.25,
            isTouchingWall: true,
            normalAcceleration: 12.75,
            tangentialSpeed: 0.42,
            contactDirection: SIMD3(3, 4, 0)
        )

        let payload = BellModalContactMapping.payload(for: state)
        precondition(payload.timestamp == 4.25)
        precondition(payload.isTouchingWall)
        precondition(payload.normalAcceleration == 12.75)
        precondition(payload.tangentialSpeed == 0.42)
        precondition(abs(payload.contactDirection.x - 0.6) < 0.000_001)
        precondition(abs(payload.contactDirection.y - 0.8) < 0.000_001)
        precondition(abs(payload.contactDirection.z) < 0.000_001)
    }

    private static func testNegativeLoadAndSpeedAreClampedToZero() {
        let state = BellContactState(
            timestamp: 5,
            isTouchingWall: true,
            normalAcceleration: -2,
            tangentialSpeed: -0.3,
            contactDirection: .zero
        )

        let payload = BellModalContactMapping.payload(for: state)
        precondition(payload.normalAcceleration == 0)
        precondition(payload.tangentialSpeed == 0)
        precondition(payload.contactDirection == SIMD3(0, -1, 0))
    }

    private static func testNonFiniteInputBecomesSafeDetachedPayload() {
        let state = BellContactState(
            timestamp: .nan,
            isTouchingWall: true,
            normalAcceleration: .infinity,
            tangentialSpeed: -.infinity,
            contactDirection: SIMD3(.nan, 0, 0)
        )

        precondition(BellModalContactMapping.payload(for: state) == .safeDetached)
    }
}
