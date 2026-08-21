import Foundation

@main
struct BellGeometryProfileTests {
    static func main() {
        testRestingClapperReachesOpening()
        testClapperFitsInsideAtMaximumSwing()
        testDirectionalContactLimitKeepsTheWholeBallInsideTheShell()

        let outer = BellGeometryProfile.bodyOuter
        let inner = BellGeometryProfile.bodyInner
        let handle = BellGeometryProfile.handle

        precondition(outer.count >= 48, "The reference bell needs a densely sampled outer curve")
        precondition(inner.count >= 40, "The hollow inner wall needs a densely sampled curve")
        precondition(outer.last!.radius > outer.first!.radius, "The bell must flare toward the rim")
        precondition(inner.first!.radius < outer.last!.radius, "The rim must have wall thickness")
        precondition(inner.last!.radius < inner.first!.radius, "The inner wall must narrow toward the crown")

        let bodyHeight = outer.first!.height - outer.last!.height
        let maximumBodyRadius = outer.map(\.radius).max()!
        let bodyAspectRatio = bodyHeight / maximumBodyRadius
        precondition((2.20...2.36).contains(bodyAspectRatio), "The body aspect ratio must follow the measured reference silhouette")

        let preRimRadius = outer[outer.count - 8].radius
        let rimFlare = outer.last!.radius / preRimRadius
        precondition((1.02...1.16).contains(rimFlare), "The thin lip must flare subtly instead of forming a broad bell mouth")

        let wallThicknessRatio = (outer.last!.radius - inner.first!.radius) / outer.last!.radius
        precondition((0.02...0.08).contains(wallThicknessRatio), "The rim must read as thin sheet brass")

        let handleHeight = handle.first!.height - handle.last!.height
        let maximumHandleRadius = handle.map(\.radius).max()!
        precondition(handle.count >= 32, "The long wooden handle needs a smooth sampled profile")
        precondition((0.45...0.65).contains(handleHeight / bodyHeight), "The measured wooden handle is about half the body height")
        precondition(maximumHandleRadius < maximumBodyRadius * 0.14, "The handle must stay narrow and lightweight")

        let bodyToHandleHeight = bodyHeight / handleHeight
        let bodyToHandleWidth = maximumBodyRadius / maximumHandleRadius
        precondition((1.45...1.65).contains(bodyToHandleHeight), "The body must be 20 percent smaller relative to the unchanged handle")
        precondition((7.2...8.0).contains(bodyToHandleWidth), "The body width must be balanced against the slim handle")

        let visibleRimThickness = inner.first!.height - outer.last!.height
        precondition(visibleRimThickness > 0 && visibleRimThickness <= 0.026, "The reduced body needs a thin visible brass lip")
        print("BellGeometryProfileTests passed")
    }

    private static func testRestingClapperReachesOpening() {
        let clapper = BellClapperGeometry.referenceTuned
        let restingBallBottom = clapper.pivotHeight
            - clapper.ballCenterDistance
            - clapper.ballRadius
        let rimHeight = BellGeometryProfile.bodyOuter.last!.height

        precondition(
            abs(restingBallBottom - rimHeight) <= 0.005,
            "The resting clapper ball must reach the opening instead of hiding behind the shell"
        )
    }

    private static func testClapperFitsInsideAtMaximumSwing() {
        let clapper = BellClapperGeometry.referenceTuned
        let centerX = clapper.ballCenterDistance * sin(clapper.contactAngle)
        let centerHeight = clapper.pivotHeight
            - clapper.ballCenterDistance * cos(clapper.contactAngle)
        let radialCenterDistance = sqrt(
            centerX * centerX + clapper.forwardOffset * clapper.forwardOffset
        )
        let nearestInnerPoint = BellGeometryProfile.bodyInner.min {
            abs($0.height - centerHeight) < abs($1.height - centerHeight)
        }!

        precondition(
            radialCenterDistance + clapper.ballRadius <= nearestInnerPoint.radius,
            "The visible clapper must remain inside the cavity at maximum swing"
        )
    }

    private static func testDirectionalContactLimitKeepsTheWholeBallInsideTheShell() {
        let clapper = BellClapperGeometry.referenceTuned
        let directions = [
            SIMD2<Double>(1, 0),
            SIMD2<Double>(0, 1),
            SIMD2<Double>(-1, 0),
            SIMD2<Double>(0, -1),
            SIMD2<Double>(0.7071067812, 0.7071067812)
        ]

        let frontLimit = clapper.maximumSafeAngle(
            toward: SIMD2(0, 1),
            hardLimit: Double(clapper.contactAngle)
        )
        let backLimit = clapper.maximumSafeAngle(
            toward: SIMD2(0, -1),
            hardLimit: Double(clapper.contactAngle)
        )
        precondition(frontLimit < Double(clapper.contactAngle))
        precondition(backLimit > frontLimit)

        for radialDirection in directions {
            let angle = clapper.maximumSafeAngle(
                toward: radialDirection,
                hardLimit: Double(clapper.contactAngle)
            )
            let horizontalDistance = Double(clapper.ballCenterDistance) * sin(angle)
            let centerRadius = hypot(
                horizontalDistance * radialDirection.x,
                Double(clapper.forwardOffset) + horizontalDistance * radialDirection.y
            )
            let centerHeight = Double(clapper.pivotHeight) -
                Double(clapper.ballCenterDistance) * cos(angle)
            let clearance = BellGeometryProfile.innerRadius(atHeight: centerHeight) -
                centerRadius - Double(clapper.ballRadius)

            precondition(
                clearance >= 0.0079,
                "The collision limit must retain an 8 mm visual clearance in every direction"
            )
        }
    }
}
