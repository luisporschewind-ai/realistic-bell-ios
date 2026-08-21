import SceneKit
import SwiftUI
import UIKit

struct BellSceneView: UIViewRepresentable {
    let clapperState: BellClapperState

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let sceneParts = BellSceneFactory.makeScene()

        view.scene = sceneParts.scene
        view.backgroundColor = UIColor(
            white: BellPresentationConfiguration.referenceTuned.backgroundWhite,
            alpha: 1
        )
        view.isOpaque = true
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X

        context.coordinator.presentationRoot = sceneParts.presentationRoot
        context.coordinator.clapperPivot = sceneParts.clapperPivot

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        view.addGestureRecognizer(panGesture)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.apply(clapperState)
    }

    final class Coordinator: NSObject {
        var presentationRoot: SCNNode?
        var clapperPivot: SCNNode?
        private var dragStartAngles = SCNVector3Zero

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView, let presentationRoot else { return }

            switch gesture.state {
            case .began:
                dragStartAngles = presentationRoot.eulerAngles
            case .changed, .ended:
                let translation = gesture.translation(in: view)
                let yaw = dragStartAngles.y + Float(
                    translation.x / max(view.bounds.width, 1) * BellInteractionLimits.yawSensitivity
                )
                let pitch = dragStartAngles.x - Float(
                    translation.y / max(view.bounds.height, 1) * BellInteractionLimits.pitchSensitivity
                )

                SCNTransaction.begin()
                SCNTransaction.animationDuration = gesture.state == .ended ? 0.12 : 0
                presentationRoot.eulerAngles = SCNVector3(
                    clamped(
                        pitch,
                        minimum: -BellInteractionLimits.maximumPitch,
                        maximum: BellInteractionLimits.maximumPitch
                    ),
                    clamped(
                        yaw,
                        minimum: -BellInteractionLimits.maximumYaw,
                        maximum: BellInteractionLimits.maximumYaw
                    ),
                    0
                )
                SCNTransaction.commit()
            default:
                break
            }
        }

        private func clamped(_ value: Float, minimum: Float, maximum: Float) -> Float {
            min(max(value, minimum), maximum)
        }

        func apply(_ state: BellClapperState) {
            guard let clapperPivot else { return }
            clapperPivot.simdOrientation = BellClapperOrientation.quaternion(
                for: state.direction
            )
        }
    }
}
