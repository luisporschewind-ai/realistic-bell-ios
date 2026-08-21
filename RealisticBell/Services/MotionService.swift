import CoreMotion
import Foundation

final class MotionService {
    private let motionManager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.realisticbell.motion"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    var onSample: ((MotionSample) -> Void)?
    var onAvailabilityChanged: ((Bool) -> Void)?

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            onAvailabilityChanged?(false)
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 100.0
        onAvailabilityChanged?(true)

        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard self != nil, error == nil, let motion else { return }

            let sample = MotionSample(
                accelerationX: motion.userAcceleration.x,
                accelerationY: motion.userAcceleration.y,
                accelerationZ: motion.userAcceleration.z,
                gravityX: motion.gravity.x,
                gravityY: motion.gravity.y,
                gravityZ: motion.gravity.z,
                rotationX: motion.rotationRate.x,
                rotationY: motion.rotationRate.y,
                rotationZ: motion.rotationRate.z,
                timestamp: motion.timestamp
            )

            self?.onSample?(sample)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
