import simd

enum BellClapperOrientation {
    private static let restDirection = SIMD3<Float>(0, -1, 0)

    static func quaternion(for direction: SIMD3<Double>) -> simd_quatf {
        guard direction.x.isFinite, direction.y.isFinite, direction.z.isFinite else {
            return simd_quatf(real: 1, imag: .zero)
        }

        let target = SIMD3<Float>(
            Float(direction.x),
            Float(direction.y),
            Float(direction.z)
        )
        let length = simd_length(target)
        guard length.isFinite, length > 0.000_001 else {
            return simd_quatf(real: 1, imag: .zero)
        }

        return simd_quatf(from: restDirection, to: target / length)
    }
}
