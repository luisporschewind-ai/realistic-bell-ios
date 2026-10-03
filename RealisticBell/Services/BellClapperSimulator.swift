import Foundation

struct BellClapperState: Equatable {
    let direction: SIMD3<Double>
    let tangentVelocity: SIMD3<Double>
    let isTouchingWall: Bool

    static let rest = BellClapperState(
        direction: SIMD3(0, -1, 0),
        tangentVelocity: .zero,
        isTouchingWall: false
    )
}

struct BellSimulationStep: Equatable {
    let state: BellClapperState
    let contact: BellContactState
    let impact: BellImpactEvent?
}

struct BellClapperSimulator {
    private static let mouthAxis = SIMD3<Double>(0, -1, 0)
    private static let gravityAcceleration = 9.80665

    private var parameters: BellClapperParameters
    private(set) var state = BellClapperState.rest

    private var lastTimestamp: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    private var previousRotationRate = SIMD3<Double>.zero
    private var lastStableGravity = mouthAxis
    private var lastSide = SIMD3<Double>(1, 0, 0)
    private var lastImpactTime: TimeInterval = -.infinity
    private var contactDriveBaseline = 0.0
    private var contact = BellContactState.detached(timestamp: 0)

    init(parameters: BellClapperParameters = .referenceTuned) {
        self.parameters = parameters
    }

    mutating func update(parameters: BellClapperParameters) {
        self.parameters = parameters
    }

    mutating func reset() {
        state = .rest
        lastTimestamp = nil
        accumulatedTime = 0
        previousRotationRate = .zero
        lastStableGravity = Self.mouthAxis
        lastSide = SIMD3(1, 0, 0)
        lastImpactTime = -.infinity
        contactDriveBaseline = 0
        contact = .detached(timestamp: 0)
    }

    mutating func step(input: BellMotionInput) -> BellSimulationStep {
        guard input.isFinite else {
            dampAfterInvalidInput()
            contact = .detached(timestamp: input.timestamp)
            return BellSimulationStep(state: state, contact: contact, impact: nil)
        }

        let gravityLength = magnitude(input.gravity)
        let gravity = gravityLength > 0.5
            ? normalized(input.gravity, fallback: lastStableGravity)
            : lastStableGravity

        if gravityLength > 0.5 {
            lastStableGravity = gravity
        }

        guard let previousTimestamp = lastTimestamp else {
            lastTimestamp = input.timestamp
            previousRotationRate = input.rotationRate
            contact = .detached(timestamp: input.timestamp)
            return BellSimulationStep(state: state, contact: contact, impact: nil)
        }

        let elapsed = input.timestamp - previousTimestamp
        guard elapsed > 0, elapsed <= parameters.maximumAccumulatedTime else {
            lastTimestamp = input.timestamp
            previousRotationRate = input.rotationRate
            accumulatedTime = 0
            contact = .detached(timestamp: input.timestamp)
            return BellSimulationStep(state: state, contact: contact, impact: nil)
        }

        lastTimestamp = input.timestamp
        accumulatedTime += elapsed

        let sampleAngularAcceleration = clampMagnitude(
            (input.rotationRate - previousRotationRate) / elapsed,
            maximum: 40
        )
        previousRotationRate = input.rotationRate

        var strongestImpact: BellImpactEvent?
        let fixedTimeStep = parameters.fixedTimeStep
        while accumulatedTime + 1e-12 >= fixedTimeStep {
            let substep = integrate(
                gravity: gravity,
                userAcceleration: clampMagnitude(input.userAcceleration, maximum: 4),
                rotationRate: clampMagnitude(input.rotationRate, maximum: 12),
                angularAcceleration: sampleAngularAcceleration,
                timestamp: input.timestamp,
                deltaTime: fixedTimeStep
            )
            if let impact = substep,
               strongestImpact == nil || impact.strength > strongestImpact!.strength {
                strongestImpact = impact
            }
            accumulatedTime -= fixedTimeStep
        }

        return BellSimulationStep(state: state, contact: contact, impact: strongestImpact)
    }

    private mutating func integrate(
        gravity: SIMD3<Double>,
        userAcceleration: SIMD3<Double>,
        rotationRate: SIMD3<Double>,
        angularAcceleration: SIMD3<Double>,
        timestamp: TimeInterval,
        deltaTime: TimeInterval
    ) -> BellImpactEvent? {
        let wasTouchingWall = state.isTouchingWall
        let radius = state.direction * parameters.length
        let tangentLinearVelocity = state.tangentVelocity * parameters.length
        let pivotAcceleration = userAcceleration * (
            Self.gravityAcceleration * parameters.translationGain
        )
        let rotatingFrameAcceleration =
            -cross(angularAcceleration, radius) -
            cross(rotationRate, cross(rotationRate, radius)) -
            2 * cross(rotationRate, tangentLinearVelocity)
        let effectiveAcceleration =
            gravity * Self.gravityAcceleration -
            pivotAcceleration +
            rotatingFrameAcceleration * parameters.rotationGain
        let tangentAcceleration = effectiveAcceleration -
            state.direction * dot(effectiveAcceleration, state.direction)

        var velocity = state.tangentVelocity +
            tangentAcceleration / parameters.length * deltaTime
        velocity *= exp(-parameters.damping * deltaTime)
        velocity = clampMagnitude(velocity, maximum: parameters.maximumAngularSpeed)

        var direction = normalized(
            state.direction + velocity * deltaTime,
            fallback: state.direction
        )
        velocity -= direction * dot(velocity, direction)

        let axial = clamp(dot(direction, Self.mouthAxis), minimum: -1, maximum: 1)
        let angle = acos(axial)
        let radialDirection = normalized(
            direction - Self.mouthAxis * axial,
            fallback: lastSide
        )
        let contactAngle = BellClapperGeometry.referenceTuned.maximumSafeAngle(
            toward: SIMD2(radialDirection.x, radialDirection.z),
            hardLimit: parameters.maximumAngle
        )
        guard angle >= contactAngle else {
            state = BellClapperState(
                direction: direction,
                tangentVelocity: velocity,
                isTouchingWall: false
            )
            contactDriveBaseline = 0
            contact = .detached(timestamp: timestamp)
            updateLastSide(from: direction)
            return nil
        }

        lastSide = radialDirection
        direction = Self.mouthAxis * cos(contactAngle) +
            radialDirection * sin(contactAngle)

        let outwardNormal = normalized(
            -Self.mouthAxis * sin(contactAngle) +
            radialDirection * cos(contactAngle),
            fallback: radialDirection
        )
        let outwardAngularSpeed = max(0, dot(velocity, outwardNormal))
        let crossingNormalSpeed = outwardAngularSpeed * parameters.length

        let boundaryTangentAcceleration = effectiveAcceleration -
            direction * dot(effectiveAcceleration, direction)
        let outwardDrive = max(
            0,
            dot(boundaryTangentAcceleration / parameters.length, outwardNormal)
        )
        let previousBaseline = contactDriveBaseline
        let baselineBlend = 1 - exp(-deltaTime / 0.15)
        contactDriveBaseline += (outwardDrive - contactDriveBaseline) * baselineBlend
        let dynamicContactSpeed = wasTouchingWall
            ? max(0, outwardDrive - previousBaseline) * deltaTime * parameters.length
            : 0

        if outwardAngularSpeed > 0 {
            velocity -= outwardNormal * outwardAngularSpeed * (1 + parameters.restitution)
        }
        velocity -= direction * dot(velocity, direction)

        if crossingNormalSpeed < parameters.minimumImpactSpeed {
            velocity -= outwardNormal * dot(velocity, outwardNormal)
        }

        state = BellClapperState(
            direction: direction,
            tangentVelocity: velocity,
            isTouchingWall: true
        )

        let normalComponent = outwardNormal * dot(velocity, outwardNormal)
        let tangentialVelocity = velocity - normalComponent -
            direction * dot(velocity, direction)
        contact = BellContactState(
            timestamp: timestamp,
            isTouchingWall: true,
            normalAcceleration: outwardDrive * parameters.length,
            tangentialSpeed: magnitude(tangentialVelocity) * parameters.length,
            contactDirection: direction
        )

        let impactNormalSpeed = max(crossingNormalSpeed, dynamicContactSpeed)
        let crossedWall = !wasTouchingWall &&
            crossingNormalSpeed >= parameters.minimumImpactSpeed
        let receivedNewContactImpulse = wasTouchingWall &&
            dynamicContactSpeed >= parameters.contactImpulseThreshold
        guard crossedWall || receivedNewContactImpulse else { return nil }
        guard timestamp - lastImpactTime >= parameters.collisionCooldown else { return nil }

        let strength = clamp(
            (impactNormalSpeed - parameters.minimumImpactSpeed) /
                (parameters.fullStrengthImpactSpeed - parameters.minimumImpactSpeed),
            minimum: 0.001,
            maximum: 1
        )
        lastImpactTime = timestamp

        return BellImpactEvent(
            timestamp: timestamp,
            strength: strength,
            normalSpeed: impactNormalSpeed,
            contactDirection: direction,
            contactPoint: direction * parameters.length,
            tangentialSpeed: magnitude(tangentialVelocity) * parameters.length
        )
    }

    private mutating func updateLastSide(from direction: SIMD3<Double>) {
        let radial = direction - Self.mouthAxis * dot(direction, Self.mouthAxis)
        if magnitude(radial) > 1e-6 {
            lastSide = normalized(radial, fallback: lastSide)
        }
    }

    private mutating func dampAfterInvalidInput() {
        state = BellClapperState(
            direction: state.direction,
            tangentVelocity: state.tangentVelocity * 0.9,
            isTouchingWall: state.isTouchingWall
        )
    }

    private func dot(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }

    private func cross(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(
            lhs.y * rhs.z - lhs.z * rhs.y,
            lhs.z * rhs.x - lhs.x * rhs.z,
            lhs.x * rhs.y - lhs.y * rhs.x
        )
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

    private func clamp(_ value: Double, minimum: Double, maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}
