import Foundation

struct BellProfilePoint {
    let radius: CGFloat
    let height: CGFloat
}

struct BellClapperGeometry {
    let pivotHeight: CGFloat
    let ballCenterDistance: CGFloat
    let ballRadius: CGFloat
    let forwardOffset: CGFloat
    let contactAngle: CGFloat

    static let referenceTuned = BellClapperGeometry(
        pivotHeight: 0.56,
        ballCenterDistance: 0.82,
        ballRadius: 0.072,
        forwardOffset: 0.030,
        contactAngle: 0.36
    )

    var stemHeight: CGFloat {
        ballCenterDistance - ballRadius
    }

    func maximumSafeAngle(
        toward radialDirection: SIMD2<Double>,
        hardLimit: Double,
        safetyMargin: Double = 0.008
    ) -> Double {
        let directionLength = hypot(radialDirection.x, radialDirection.y)
        let direction = directionLength > 1e-9
            ? radialDirection / directionLength
            : SIMD2<Double>(1, 0)

        func clearance(at angle: Double) -> Double {
            let horizontalDistance = Double(ballCenterDistance) * sin(angle)
            let centerRadius = hypot(
                horizontalDistance * direction.x,
                Double(forwardOffset) + horizontalDistance * direction.y
            )
            let centerHeight = Double(pivotHeight) -
                Double(ballCenterDistance) * cos(angle)
            return BellGeometryProfile.innerRadius(atHeight: centerHeight) -
                centerRadius - Double(ballRadius)
        }

        let clampedLimit = max(0, hardLimit)
        guard clearance(at: clampedLimit) < safetyMargin else {
            return clampedLimit
        }

        var lower = 0.0
        var upper = clampedLimit
        for _ in 0..<32 {
            let candidate = (lower + upper) * 0.5
            if clearance(at: candidate) >= safetyMargin {
                lower = candidate
            } else {
                upper = candidate
            }
        }
        return lower
    }
}

enum BellGeometryProfile {
    static let bodyOuter: [BellProfilePoint] = makeCurve(
        anchors: [
            BellProfilePoint(radius: 0.084, height: 0.720),
            BellProfilePoint(radius: 0.192, height: 0.656),
            BellProfilePoint(radius: 0.248, height: 0.488),
            BellProfilePoint(radius: 0.288, height: 0.240),
            BellProfilePoint(radius: 0.352, height: -0.104),
            BellProfilePoint(radius: 0.412, height: -0.256),
            BellProfilePoint(radius: 0.456, height: -0.332)
        ],
        samplesPerSegment: 10
    )

    static let bodyInner: [BellProfilePoint] = makeCurve(
        anchors: [
            BellProfilePoint(radius: 0.430, height: -0.310),
            BellProfilePoint(radius: 0.396, height: -0.232),
            BellProfilePoint(radius: 0.340, height: -0.080),
            BellProfilePoint(radius: 0.264, height: 0.248),
            BellProfilePoint(radius: 0.220, height: 0.480),
            BellProfilePoint(radius: 0.176, height: 0.624),
            BellProfilePoint(radius: 0.062, height: 0.692)
        ],
        samplesPerSegment: 9
    )

    static let rim: [BellProfilePoint] = makeCurve(
        anchors: [
            bodyOuter.last!,
            BellProfilePoint(radius: 0.464, height: -0.326),
            BellProfilePoint(radius: 0.459, height: -0.316),
            bodyInner.first!
        ],
        samplesPerSegment: 6
    )

    static let crown: [BellProfilePoint] = makeCurve(
        anchors: [
            bodyInner.last!,
            BellProfilePoint(radius: 0.067, height: 0.710),
            bodyOuter.first!
        ],
        samplesPerSegment: 5
    )

    static let handle: [BellProfilePoint] = makeCurve(
        anchors: [
            BellProfilePoint(radius: 0.002, height: 0.68),
            BellProfilePoint(radius: 0.040, height: 0.66),
            BellProfilePoint(radius: 0.052, height: 0.52),
            BellProfilePoint(radius: 0.058, height: 0.36),
            BellProfilePoint(radius: 0.060, height: 0.20),
            BellProfilePoint(radius: 0.050, height: 0.06),
            BellProfilePoint(radius: 0.042, height: 0.00)
        ],
        samplesPerSegment: 7
    )

    static func innerRadius(atHeight height: Double) -> Double {
        let points = bodyInner.sorted { $0.height < $1.height }
        guard let first = points.first, let last = points.last else { return 0 }
        if height <= Double(first.height) { return Double(first.radius) }
        if height >= Double(last.height) { return Double(last.radius) }

        for index in 0..<(points.count - 1) {
            let lower = points[index]
            let upper = points[index + 1]
            let lowerHeight = Double(lower.height)
            let upperHeight = Double(upper.height)
            guard height >= lowerHeight, height <= upperHeight else { continue }

            let span = upperHeight - lowerHeight
            guard span > 1e-9 else { return Double(lower.radius) }
            let fraction = (height - lowerHeight) / span
            return Double(lower.radius) +
                (Double(upper.radius) - Double(lower.radius)) * fraction
        }
        return Double(last.radius)
    }

    private static func makeCurve(
        anchors: [BellProfilePoint],
        samplesPerSegment: Int
    ) -> [BellProfilePoint] {
        guard anchors.count >= 2 else { return anchors }

        var result: [BellProfilePoint] = []
        for index in 0..<(anchors.count - 1) {
            let previous = anchors[max(index - 1, 0)]
            let start = anchors[index]
            let end = anchors[index + 1]
            let next = anchors[min(index + 2, anchors.count - 1)]

            for sample in 0..<samplesPerSegment {
                let t = CGFloat(sample) / CGFloat(samplesPerSegment)
                result.append(catmullRom(previous, start, end, next, t: t))
            }
        }
        result.append(anchors.last!)
        return result
    }

    private static func catmullRom(
        _ p0: BellProfilePoint,
        _ p1: BellProfilePoint,
        _ p2: BellProfilePoint,
        _ p3: BellProfilePoint,
        t: CGFloat
    ) -> BellProfilePoint {
        let t2 = t * t
        let t3 = t2 * t

        func interpolate(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * ((2 * b) +
                (-a + c) * t +
                (2 * a - 5 * b + 4 * c - d) * t2 +
                (-a + 3 * b - 3 * c + d) * t3)
        }

        return BellProfilePoint(
            radius: max(0.001, interpolate(p0.radius, p1.radius, p2.radius, p3.radius)),
            height: interpolate(p0.height, p1.height, p2.height, p3.height)
        )
    }
}
