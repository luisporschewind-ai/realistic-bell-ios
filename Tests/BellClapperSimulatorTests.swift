import Foundation

@main
struct BellClapperSimulatorTests {
    private static let mouthAxis = SIMD3<Double>(0, -1, 0)

    static func main() {
        testUprightInputStaysCentered()
        testGravityMovesInEveryHorizontalDirection()
        testDirectionRemainsContinuousAcrossCombinedTilts()
        testClapperNeverLeavesConeUnderStress()
        testFrontContactKeepsTheWholeBallInsideTheShell()
        testRotationalShakeMakesTheClapperLagThePhone()
        testFastBoundaryCrossingEmitsImpact()
        testInversionKeepsInheritedSideAndBecomesQuiet()
        testNewInvertedImpulseCreatesOneNewImpact()
        testColdLaunchExactlyInvertedWaitsForDirectionalMotion()
        testInvalidAndStaleInputsDoNotCreateImpacts()
        testParameterUpdatePreservesDynamicState()
        print("BellClapperSimulatorTests passed")
    }

    private static func testUprightInputStaysCentered() {
        var simulator = BellClapperSimulator()
        var impacts = 0
        var state = BellClapperState.rest

        for index in 0...300 {
            let step = simulator.step(input: input(
                gravity: mouthAxis,
                timestamp: Double(index) * 0.01
            ))
            state = step.state
            if step.impact != nil { impacts += 1 }
        }

        precondition(distance(state.direction, mouthAxis) < 0.0001)
        precondition(magnitude(state.tangentVelocity) < 0.0001)
        precondition(!state.isTouchingWall)
        precondition(impacts == 0)
    }

    private static func testGravityMovesInEveryHorizontalDirection() {
        let cases: [(SIMD3<Double>, (SIMD3<Double>) -> Bool)] = [
            (normalized(SIMD3(-0.20, -0.98, 0)), { $0.x < -0.08 }),
            (normalized(SIMD3(0.20, -0.98, 0)), { $0.x > 0.08 }),
            (normalized(SIMD3(0, -0.98, 0.20)), { $0.z > 0.08 }),
            (normalized(SIMD3(0, -0.98, -0.20)), { $0.z < -0.08 }),
            (normalized(SIMD3(0.14, -0.98, 0.14)), { $0.x > 0.04 && $0.z > 0.04 })
        ]

        for (gravity, assertion) in cases {
            var simulator = BellClapperSimulator()
            _ = simulator.step(input: input(gravity: mouthAxis, timestamp: 0))
            var state = BellClapperState.rest
            for index in 1...400 {
                state = simulator.step(input: input(
                    gravity: gravity,
                    timestamp: Double(index) * 0.01
                )).state
            }
            precondition(assertion(state.direction), "Clapper did not follow gravity \(gravity)")
        }
    }

    private static func testDirectionRemainsContinuousAcrossCombinedTilts() {
        var simulator = BellClapperSimulator()
        var previous = simulator.step(input: input(gravity: mouthAxis, timestamp: 0)).state

        for index in 1...720 {
            let phase = Double(index) / 720.0 * Double.pi * 2
            let gravity = normalized(SIMD3(
                sin(phase) * 0.28,
                -0.92,
                cos(phase) * 0.28
            ))
            let next = simulator.step(input: input(
                gravity: gravity,
                timestamp: Double(index) * 0.01
            )).state

            precondition(next.direction.x.isFinite)
            precondition(next.direction.y.isFinite)
            precondition(next.direction.z.isFinite)
            precondition(distance(previous.direction, next.direction) < 0.12)
            previous = next
        }
    }

    private static func testClapperNeverLeavesConeUnderStress() {
        var simulator = BellClapperSimulator()

        for index in 0..<2_000 {
            let t = Double(index) * 0.01
            let gravity = normalized(SIMD3(
                sin(t * 1.7),
                cos(t * 0.9),
                cos(t * 1.3)
            ))
            let acceleration = SIMD3(
                sin(t * 8.0) * 3.0,
                cos(t * 6.0) * 2.0,
                sin(t * 7.0) * 2.5
            )
            let rotation = SIMD3(
                cos(t * 3.0) * 4.0,
                sin(t * 2.0) * 3.5,
                cos(t * 4.0) * 4.5
            )
            let state = simulator.step(input: input(
                gravity: gravity,
                acceleration: acceleration,
                rotationRate: rotation,
                timestamp: t
            )).state

            let angle = acos(clamp(dot(state.direction, mouthAxis), -1, 1))
            precondition(angle <= 0.360_001)
            precondition(abs(magnitude(state.direction) - 1) < 0.000_001)
            precondition(state.tangentVelocity.x.isFinite)
            precondition(state.tangentVelocity.y.isFinite)
            precondition(state.tangentVelocity.z.isFinite)
        }
    }

    private static func testFrontContactKeepsTheWholeBallInsideTheShell() {
        var simulator = BellClapperSimulator()
        _ = simulator.step(input: input(gravity: mouthAxis, timestamp: 0))
        var state = BellClapperState.rest

        for index in 1...120 {
            state = simulator.step(input: input(
                gravity: mouthAxis,
                acceleration: SIMD3(0, 0, -3),
                timestamp: Double(index) * 0.01
            )).state
        }

        let geometry = BellClapperGeometry.referenceTuned
        let centerRadius = hypot(
            Double(geometry.ballCenterDistance) * state.direction.x,
            Double(geometry.forwardOffset) +
                Double(geometry.ballCenterDistance) * state.direction.z
        )
        let centerHeight = Double(geometry.pivotHeight) +
            Double(geometry.ballCenterDistance) * state.direction.y
        let clearance = BellGeometryProfile.innerRadius(atHeight: centerHeight) -
            centerRadius - Double(geometry.ballRadius)

        precondition(
            clearance >= 0.0079,
            "Front contact must constrain the full clapper ball, not only its center direction"
        )
    }

    private static func testRotationalShakeMakesTheClapperLagThePhone() {
        var simulator = BellClapperSimulator(parameters: BellConfig().clapperParameters)
        _ = simulator.step(input: input(
            gravity: mouthAxis,
            rotationRate: .zero,
            timestamp: 0
        ))
        var state = BellClapperState.rest

        for index in 1...12 {
            state = simulator.step(input: input(
                gravity: mouthAxis,
                rotationRate: SIMD3(0, 0, Double(index) * 0.1),
                timestamp: Double(index) * 0.01
            )).state
        }

        precondition(
            state.direction.x < -0.025,
            "A positive wrist rotation must leave the clapper visibly lagging in the opposite direction"
        )
        precondition(
            state.tangentVelocity.x < -0.35,
            "The clapper must retain angular momentum instead of visually following the phone"
        )
    }

    private static func testFastBoundaryCrossingEmitsImpact() {
        var simulator = BellClapperSimulator()
        _ = simulator.step(input: input(gravity: mouthAxis, timestamp: 0))
        var impact: BellImpactEvent?

        for index in 1...80 {
            let step = simulator.step(input: input(
                gravity: mouthAxis,
                acceleration: SIMD3(-3.0, 0, 0),
                timestamp: Double(index) * 0.01
            ))
            if impact == nil { impact = step.impact }
        }

        guard let impact else {
            preconditionFailure("A fast first wall crossing must emit an impact")
        }
        precondition(impact.strength > 0 && impact.strength <= 1)
        precondition(impact.normalSpeed >= 0.30)
        precondition(abs(magnitude(impact.contactDirection) - 1) < 0.000_001)
        precondition(abs(magnitude(impact.contactPoint) - 0.82) < 0.000_001)
    }

    private static func testInversionKeepsInheritedSideAndBecomesQuiet() {
        var simulator = BellClapperSimulator()
        var timestamp = 0.0
        _ = simulator.step(input: input(gravity: mouthAxis, timestamp: timestamp))

        for index in 1...300 {
            timestamp += 0.01
            let angle = Double(index) / 300.0 * Double.pi
            let gravity = SIMD3(sin(angle), -cos(angle), 0)
            _ = simulator.step(input: input(gravity: gravity, timestamp: timestamp))
        }

        for _ in 0..<500 {
            timestamp += 0.01
            _ = simulator.step(input: input(gravity: SIMD3(0, 1, 0), timestamp: timestamp))
        }

        var quietImpacts = 0
        var finalState = BellClapperState.rest
        for _ in 0..<300 {
            timestamp += 0.01
            let step = simulator.step(input: input(
                gravity: SIMD3(0, 1, 0),
                timestamp: timestamp
            ))
            finalState = step.state
            if step.impact != nil { quietImpacts += 1 }
        }

        let angle = acos(clamp(dot(finalState.direction, mouthAxis), -1, 1))
        precondition(finalState.isTouchingWall)
        precondition(abs(angle - 0.36) < 0.001)
        precondition(finalState.direction.x > 0.1, "Inversion must retain the selected side")
        precondition(quietImpacts == 0, "Static inverted pressure must not repeat impacts")
    }

    private static func testNewInvertedImpulseCreatesOneNewImpact() {
        var simulator = BellClapperSimulator()
        var timestamp = prepareInvertedSimulator(&simulator)
        var impacts: [BellImpactEvent] = []

        for index in 0..<30 {
            timestamp += 0.01
            let acceleration = index < 3 ? SIMD3(-3.0, 0, 0) : SIMD3<Double>.zero
            let step = simulator.step(input: input(
                gravity: SIMD3(0, 1, 0),
                acceleration: acceleration,
                timestamp: timestamp
            ))
            if let impact = step.impact { impacts.append(impact) }
        }

        precondition(impacts.count == 1, "A new inverted impulse should emit one collision")
        precondition(impacts[0].strength > 0)
        precondition(impacts[0].normalSpeed > 0)
    }

    private static func testColdLaunchExactlyInvertedWaitsForDirectionalMotion() {
        var simulator = BellClapperSimulator()
        var state = simulator.step(input: input(
            gravity: SIMD3(0, 1, 0),
            timestamp: 0
        )).state

        for index in 1...100 {
            let step = simulator.step(input: input(
                gravity: SIMD3(0, 1, 0),
                timestamp: Double(index) * 0.01
            ))
            precondition(step.impact == nil)
            state = step.state
        }
        precondition(distance(state.direction, mouthAxis) < 0.0001)

        for index in 101...250 {
            state = simulator.step(input: input(
                gravity: SIMD3(0, 1, 0),
                acceleration: SIMD3(-0.25, 0, 0),
                timestamp: Double(index) * 0.01
            )).state
        }
        precondition(state.direction.x > 0.1)
    }

    private static func testInvalidAndStaleInputsDoNotCreateImpacts() {
        var simulator = BellClapperSimulator()
        _ = simulator.step(input: input(gravity: mouthAxis, timestamp: 1))

        let invalid = simulator.step(input: BellMotionInput(
            gravity: SIMD3(.nan, -1, 0),
            userAcceleration: .zero,
            rotationRate: .zero,
            timestamp: 1.01
        ))
        precondition(invalid.impact == nil)
        precondition(invalid.state.direction.x.isFinite)

        let rollback = simulator.step(input: input(gravity: SIMD3(0, 1, 0), timestamp: 0.5))
        precondition(rollback.impact == nil)

        let largeGap = simulator.step(input: input(
            gravity: SIMD3(0, 1, 0),
            acceleration: SIMD3(-3, 0, 0),
            timestamp: 10
        ))
        precondition(largeGap.impact == nil)
        precondition(distance(largeGap.state.direction, mouthAxis) < 0.001)
    }

    private static func testParameterUpdatePreservesDynamicState() {
        var simulator = BellClapperSimulator()
        _ = simulator.step(input: input(gravity: mouthAxis, timestamp: 0))
        for index in 1...80 {
            _ = simulator.step(input: input(
                gravity: normalized(SIMD3(0.2, -0.98, 0)),
                timestamp: Double(index) * 0.01
            ))
        }
        let before = simulator.step(input: input(
            gravity: normalized(SIMD3(0.2, -0.98, 0)),
            timestamp: 0.81
        )).state

        var parameters = BellClapperParameters.referenceTuned
        parameters = BellClapperParameters(
            length: parameters.length,
            maximumAngle: parameters.maximumAngle,
            damping: 1.8,
            restitution: parameters.restitution,
            maximumAngularSpeed: parameters.maximumAngularSpeed,
            minimumImpactSpeed: parameters.minimumImpactSpeed,
            fullStrengthImpactSpeed: parameters.fullStrengthImpactSpeed,
            contactImpulseThreshold: parameters.contactImpulseThreshold,
            collisionCooldown: parameters.collisionCooldown,
            fixedTimeStep: parameters.fixedTimeStep,
            maximumAccumulatedTime: parameters.maximumAccumulatedTime,
            translationGain: parameters.translationGain,
            rotationGain: parameters.rotationGain
        )
        simulator.update(parameters: parameters)
        let after = simulator.step(input: input(
            gravity: normalized(SIMD3(0.2, -0.98, 0)),
            timestamp: 0.82
        )).state

        precondition(distance(before.direction, after.direction) < 0.02)
    }

    private static func prepareInvertedSimulator(_ simulator: inout BellClapperSimulator) -> Double {
        var timestamp = 0.0
        _ = simulator.step(input: input(gravity: mouthAxis, timestamp: timestamp))
        for index in 1...300 {
            timestamp += 0.01
            let angle = Double(index) / 300.0 * Double.pi
            _ = simulator.step(input: input(
                gravity: SIMD3(sin(angle), -cos(angle), 0),
                timestamp: timestamp
            ))
        }
        for _ in 0..<800 {
            timestamp += 0.01
            _ = simulator.step(input: input(gravity: SIMD3(0, 1, 0), timestamp: timestamp))
        }
        return timestamp
    }

    private static func input(
        gravity: SIMD3<Double>,
        acceleration: SIMD3<Double> = .zero,
        rotationRate: SIMD3<Double> = .zero,
        timestamp: TimeInterval
    ) -> BellMotionInput {
        BellMotionInput(
            gravity: gravity,
            userAcceleration: acceleration,
            rotationRate: rotationRate,
            timestamp: timestamp
        )
    }

    private static func dot(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }

    private static func magnitude(_ value: SIMD3<Double>) -> Double {
        sqrt(dot(value, value))
    }

    private static func normalized(_ value: SIMD3<Double>) -> SIMD3<Double> {
        value / magnitude(value)
    }

    private static func distance(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        magnitude(lhs - rhs)
    }

    private static func clamp(_ value: Double, _ minimum: Double, _ maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}
