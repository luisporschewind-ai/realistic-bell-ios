import Foundation
import simd

struct BellClapperDisplayMotion {
    private(set) var direction = BellClapperState.rest.direction

    private var angularVelocity = SIMD3<Double>.zero
    private var targetState = BellClapperState.rest
    private var hasTarget = false

    mutating func setTarget(_ state: BellClapperState) {
        guard state.direction.x.isFinite,
              state.direction.y.isFinite,
              state.direction.z.isFinite,
              state.tangentVelocity.x.isFinite,
              state.tangentVelocity.y.isFinite,
              state.tangentVelocity.z.isFinite else { return }

        targetState = state
        if !hasTarget {
            direction = state.direction
            angularVelocity = state.tangentVelocity
            hasTarget = true
        }
    }

    mutating func advance(by deltaTime: TimeInterval) {
        guard hasTarget else { return }
        let step = min(max(deltaTime, 0), 0.05)
        guard step > 0 else { return }

        let error = targetState.direction - direction
        let tangentError = error - direction * dot(error, direction)
        let desiredVelocity = targetState.tangentVelocity + tangentError * 28
        let response = 1 - exp(-18 * step)
        angularVelocity += (desiredVelocity - angularVelocity) * response
        angularVelocity -= direction * dot(angularVelocity, direction)
        angularVelocity = clampMagnitude(angularVelocity, maximum: 12)

        let nextDirection = direction + angularVelocity * step
        let length = magnitude(nextDirection)
        if length.isFinite, length > 0.000_001 {
            direction = nextDirection / length
            constrainToBellInterior()
        }
    }

    private mutating func constrainToBellInterior() {
        let mouthAxis = SIMD3<Double>(0, -1, 0)
        let axial = min(max(dot(direction, mouthAxis), -1), 1)
        let angle = acos(axial)
        let radialDirection = normalized(
            direction - mouthAxis * axial,
            fallback: SIMD3(1, 0, 0)
        )
        let geometry = BellClapperGeometry.referenceTuned
        let contactAngle = geometry.maximumSafeAngle(
            toward: SIMD2(radialDirection.x, radialDirection.z),
            hardLimit: Double(geometry.contactAngle)
        )
        guard angle > contactAngle else { return }

        direction = mouthAxis * cos(contactAngle) +
            radialDirection * sin(contactAngle)
        let outwardNormal = -mouthAxis * sin(contactAngle) +
            radialDirection * cos(contactAngle)
        let outwardSpeed = max(0, dot(angularVelocity, outwardNormal))
        angularVelocity -= outwardNormal * outwardSpeed
        angularVelocity -= direction * dot(angularVelocity, direction)
    }

    private func dot(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }

    private func magnitude(_ value: SIMD3<Double>) -> Double {
        sqrt(dot(value, value))
    }

    private func normalized(
        _ value: SIMD3<Double>,
        fallback: SIMD3<Double>
    ) -> SIMD3<Double> {
        let length = magnitude(value)
        return length.isFinite && length > 1e-9 ? value / length : fallback
    }

    private func clampMagnitude(
        _ value: SIMD3<Double>,
        maximum: Double
    ) -> SIMD3<Double> {
        let length = magnitude(value)
        guard length.isFinite, length > maximum else { return value }
        return value * (maximum / length)
    }
}

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
