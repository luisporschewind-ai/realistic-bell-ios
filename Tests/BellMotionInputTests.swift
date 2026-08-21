@main
struct BellMotionInputTests {
    static func main() {
        testMapsEverySensorAxis()
        testRejectsNonFiniteVectors()
        print("BellMotionInputTests passed")
    }

    private static func testMapsEverySensorAxis() {
        let sample = MotionSample(
            accelerationX: 0.11,
            accelerationY: -0.22,
            accelerationZ: 0.33,
            gravityX: -0.44,
            gravityY: 0.55,
            gravityZ: -0.66,
            rotationX: 0.77,
            rotationY: -0.88,
            rotationZ: 0.99,
            timestamp: 4.25
        )

        let input = BellMotionInput(sample: sample)

        precondition(input.gravity == SIMD3(-0.44, 0.55, -0.66))
        precondition(input.userAcceleration == SIMD3(0.11, -0.22, 0.33))
        precondition(input.rotationRate == SIMD3(0.77, -0.88, 0.99))
        precondition(input.timestamp == 4.25)
        precondition(input.isFinite)
    }

    private static func testRejectsNonFiniteVectors() {
        let input = BellMotionInput(
            gravity: SIMD3(0, -1, 0),
            userAcceleration: SIMD3(.nan, 0, 0),
            rotationRate: .zero,
            timestamp: 1
        )

        precondition(!input.isFinite)
    }
}
