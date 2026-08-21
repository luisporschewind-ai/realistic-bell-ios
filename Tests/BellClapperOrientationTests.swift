import Foundation
import simd

@main
struct BellClapperOrientationTests {
    private static let rest = SIMD3<Float>(0, -1, 0)

    static func main() {
        testRestDirectionProducesIdentityMapping()
        testQuaternionMapsRestAxisOntoThreeDimensionalDirection()
        testInvalidDirectionFallsBackToRest()
        print("BellClapperOrientationTests passed")
    }

    private static func testRestDirectionProducesIdentityMapping() {
        let quaternion = BellClapperOrientation.quaternion(for: SIMD3(0, -1, 0))
        precondition(simd_distance(quaternion.act(rest), rest) < 0.000_001)
    }

    private static func testQuaternionMapsRestAxisOntoThreeDimensionalDirection() {
        let requested = simd_normalize(SIMD3<Double>(0.22, -0.94, 0.26))
        let expected = SIMD3<Float>(
            Float(requested.x),
            Float(requested.y),
            Float(requested.z)
        )
        let quaternion = BellClapperOrientation.quaternion(for: requested)
        let actual = quaternion.act(rest)

        precondition(simd_distance(actual, expected) < 0.000_01)
        precondition(abs(simd_length(actual) - 1) < 0.000_01)
    }

    private static func testInvalidDirectionFallsBackToRest() {
        let quaternion = BellClapperOrientation.quaternion(for: SIMD3(.nan, 0, 0))
        precondition(simd_distance(quaternion.act(rest), rest) < 0.000_001)
    }
}
