@main
struct BellConfigTests {
    static func main() {
        testDebugParametersMapIntoSimulatorWithoutChangingGeometrySafety()
        print("BellConfigTests passed")
    }

    private static func testDebugParametersMapIntoSimulatorWithoutChangingGeometrySafety() {
        var config = BellConfig()
        config.clapperDamping = 1.7
        config.clapperRestitution = 0.31
        config.minimumImpactSpeed = 0.42
        config.collisionCooldown = 0.12
        config.translationGain = 0.9
        config.rotationGain = 0.24

        let parameters = config.clapperParameters
        precondition(parameters.damping == 1.7)
        precondition(parameters.restitution == 0.31)
        precondition(parameters.minimumImpactSpeed == 0.42)
        precondition(parameters.collisionCooldown == 0.12)
        precondition(parameters.translationGain == 0.9)
        precondition(parameters.rotationGain == 0.24)
        precondition(parameters.length == 0.82)
        precondition(parameters.maximumAngle == 0.36)
        precondition(parameters.fixedTimeStep == 0.01)
    }
}
