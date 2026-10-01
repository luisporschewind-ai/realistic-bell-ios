import Foundation
import simd

@main
struct BellClapperOrientationTests {
    private static let rest = SIMD3<Float>(0, -1, 0)

    static func main() {
        testRestDirectionProducesIdentityMapping()
        testQuaternionMapsRestAxisOntoThreeDimensionalDirection()
        testInvalidDirectionFallsBackToRest()
        testDisplayMotionRetainsMomentumAcrossDirectionReversal()
        testDisplayMotionKeepsClapperBallInsideBell()
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

    private static func testDisplayMotionRetainsMomentumAcrossDirectionReversal() {
        var motion = BellClapperDisplayMotion()
        let movingRight = BellClapperState(
            direction: simd_normalize(SIMD3<Double>(0.22, -0.976, 0)),
            tangentVelocity: SIMD3<Double>(2.4, 0, 0),
            isTouchingWall: false
        )
        let movingLeft = BellClapperState(
            direction: simd_normalize(SIMD3<Double>(-0.22, -0.976, 0)),
            tangentVelocity: SIMD3<Double>(-2.4, 0, 0),
            isTouchingWall: false
        )

        motion.setTarget(.rest)
        motion.advance(by: 1.0 / 60.0)
        motion.setTarget(movingRight)
        motion.advance(by: 1.0 / 60.0)
        motion.setTarget(movingLeft)
        motion.advance(by: 1.0 / 60.0)

        precondition(
            motion.direction.x > -0.02,
            "Display motion must retain rightward momentum briefly after a leftward target update"
        )
    }

    private static func testDisplayMotionKeepsClapperBallInsideBell() {
        let geometry = BellClapperGeometry.referenceTuned
        let angle = 0.28
        let direction = SIMD3<Double>(0, -cos(angle), sin(angle))
        let outwardTangent = SIMD3<Double>(0, sin(angle), cos(angle))
        var motion = BellClapperDisplayMotion()

        motion.setTarget(BellClapperState(
            direction: direction,
            tangentVelocity: outwardTangent * 9,
            isTouchingWall: false
        ))
        motion.advance(by: 1.0 / 60.0)

        let horizontalDistance = Double(geometry.ballCenterDistance) * hypot(
            motion.direction.x,
            motion.direction.z
        )
        let radialLength = hypot(motion.direction.x, motion.direction.z)
        let radialDirection = radialLength > 1e-9
            ? SIMD2(motion.direction.x, motion.direction.z) / radialLength
            : SIMD2<Double>(1, 0)
        let centerRadius = hypot(
            horizontalDistance * radialDirection.x,
            Double(geometry.forwardOffset) + horizontalDistance * radialDirection.y
        )
        let centerHeight = Double(geometry.pivotHeight) +
            Double(geometry.ballCenterDistance) * motion.direction.y
        let clearance = BellGeometryProfile.innerRadius(atHeight: centerHeight) -
            centerRadius - Double(geometry.ballRadius)

        precondition(
            clearance >= 0.0079,
            "Display interpolation must keep the whole clapper ball inside the bell"
        )
    }
}
