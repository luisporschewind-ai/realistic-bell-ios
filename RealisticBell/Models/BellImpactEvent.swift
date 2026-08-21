import Foundation

struct BellImpactEvent: Equatable {
    let timestamp: TimeInterval
    let strength: Double
    let normalSpeed: Double
    let contactDirection: SIMD3<Double>
    let contactPoint: SIMD3<Double>
    let tangentialSpeed: Double
}

struct BellImpactMetrics: Equatable {
    private(set) var count = 0
    private(set) var lastStrength = 0.0

    mutating func record(_ impact: BellImpactEvent) {
        count += 1
        lastStrength = impact.strength
    }
}
