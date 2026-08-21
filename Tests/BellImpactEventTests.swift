@main
struct BellImpactEventTests {
    static func main() {
        testReferenceParametersPreserveGeometryAndStabilityBounds()
        testImpactCarriesThreeDimensionalContactData()
        print("BellImpactEventTests passed")
    }

    private static func testReferenceParametersPreserveGeometryAndStabilityBounds() {
        let parameters = BellClapperParameters.referenceTuned

        precondition(parameters.length == 0.82)
        precondition(parameters.maximumAngle == 0.36)
        precondition(parameters.restitution == 0.24)
        precondition(parameters.minimumImpactSpeed < parameters.fullStrengthImpactSpeed)
        precondition(parameters.fixedTimeStep == 0.01)
        precondition(parameters.maximumAccumulatedTime == 0.05)
    }

    private static func testImpactCarriesThreeDimensionalContactData() {
        let event = BellImpactEvent(
            timestamp: 2.5,
            strength: 0.7,
            normalSpeed: 1.4,
            contactDirection: SIMD3(0.2, -0.9, 0.3),
            contactPoint: SIMD3(0.1, -0.7, 0.2),
            tangentialSpeed: 0.45
        )

        precondition(event.timestamp == 2.5)
        precondition(event.strength == 0.7)
        precondition(event.normalSpeed == 1.4)
        precondition(event.contactDirection == SIMD3(0.2, -0.9, 0.3))
        precondition(event.contactPoint == SIMD3(0.1, -0.7, 0.2))
        precondition(event.tangentialSpeed == 0.45)
    }
}
