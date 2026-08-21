import Foundation

@main
struct BellInteractionLimitsTests {
    static func main() {
        precondition(BellInteractionLimits.maximumYaw <= 0.07, "Manual yaw must stay within about four degrees")
        precondition(BellInteractionLimits.maximumPitch <= 0.04, "Manual pitch must remain a tiny appearance check")
        precondition(BellInteractionLimits.yawSensitivity <= 0.14, "A full-width drag must not expose a panorama")
        precondition(BellInteractionLimits.pitchSensitivity <= 0.08, "Vertical dragging must not overturn the bell")
        print("BellInteractionLimitsTests passed")
    }
}
