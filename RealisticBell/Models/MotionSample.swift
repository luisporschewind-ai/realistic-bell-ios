import Foundation

struct MotionSample {
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    let gravityX: Double
    let gravityY: Double
    let gravityZ: Double
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double
    let timestamp: TimeInterval

    var accelerationMagnitude: Double {
        sqrt(
            accelerationX * accelerationX +
            accelerationY * accelerationY +
            accelerationZ * accelerationZ
        )
    }
}
