@main
struct BellImpactPipelineTests {
    static func main() {
        testNoEventLeavesMetricsUnchanged()
        testEachRealImpactUpdatesCountAndStrengthOnce()
        print("BellImpactPipelineTests passed")
    }

    private static func testNoEventLeavesMetricsUnchanged() {
        let metrics = BellImpactMetrics()
        precondition(metrics.count == 0)
        precondition(metrics.lastStrength == 0)
    }

    private static func testEachRealImpactUpdatesCountAndStrengthOnce() {
        var metrics = BellImpactMetrics()
        metrics.record(event(timestamp: 1, strength: 0.25))
        metrics.record(event(timestamp: 2, strength: 0.80))

        precondition(metrics.count == 2)
        precondition(metrics.lastStrength == 0.80)
    }

    private static func event(timestamp: Double, strength: Double) -> BellImpactEvent {
        BellImpactEvent(
            timestamp: timestamp,
            strength: strength,
            normalSpeed: 1,
            contactDirection: SIMD3(1, 0, 0),
            contactPoint: SIMD3(0.82, 0, 0),
            tangentialSpeed: 0.1
        )
    }
}
