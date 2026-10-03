import Foundation

@main
struct BellContactStateTests {
    static func main() {
        testValidContactPreservesPhysicalFields()
        testNonFiniteContactIsRejected()
        testDetachedContactUsesSafePhysicalDefaults()
        print("BellContactStateTests passed")
    }

    private static func testValidContactPreservesPhysicalFields() {
        let state = BellContactState(
            timestamp: 2.5,
            isTouchingWall: true,
            normalAcceleration: 4.2,
            tangentialSpeed: 0.37,
            contactDirection: SIMD3(0.6, -0.8, 0)
        )

        precondition(state.timestamp == 2.5)
        precondition(state.isTouchingWall)
        precondition(state.normalAcceleration == 4.2)
        precondition(state.tangentialSpeed == 0.37)
        precondition(state.contactDirection == SIMD3(0.6, -0.8, 0))
        precondition(state.isFinite)
    }

    private static func testNonFiniteContactIsRejected() {
        let invalidStates = [
            BellContactState(
                timestamp: .nan,
                isTouchingWall: true,
                normalAcceleration: 1,
                tangentialSpeed: 0.2,
                contactDirection: SIMD3(0, -1, 0)
            ),
            BellContactState(
                timestamp: 1,
                isTouchingWall: true,
                normalAcceleration: .infinity,
                tangentialSpeed: 0.2,
                contactDirection: SIMD3(0, -1, 0)
            ),
            BellContactState(
                timestamp: 1,
                isTouchingWall: true,
                normalAcceleration: 1,
                tangentialSpeed: -.infinity,
                contactDirection: SIMD3(0, -1, 0)
            ),
            BellContactState(
                timestamp: 1,
                isTouchingWall: true,
                normalAcceleration: 1,
                tangentialSpeed: 0.2,
                contactDirection: SIMD3(.nan, -1, 0)
            ),
            BellContactState(
                timestamp: 1,
                isTouchingWall: true,
                normalAcceleration: 1,
                tangentialSpeed: 0.2,
                contactDirection: SIMD3(0, .infinity, 0)
            ),
            BellContactState(
                timestamp: 1,
                isTouchingWall: true,
                normalAcceleration: 1,
                tangentialSpeed: 0.2,
                contactDirection: SIMD3(0, -1, -.infinity)
            )
        ]

        precondition(invalidStates.allSatisfy { !$0.isFinite })
    }

    private static func testDetachedContactUsesSafePhysicalDefaults() {
        let state = BellContactState.detached(timestamp: 2.5)

        precondition(state.timestamp == 2.5)
        precondition(!state.isTouchingWall)
        precondition(state.normalAcceleration == 0)
        precondition(state.tangentialSpeed == 0)
        precondition(state.contactDirection == SIMD3(0, -1, 0))
        precondition(state.isFinite)
    }
}
