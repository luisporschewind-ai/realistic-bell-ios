import SceneKit
import UIKit

enum BellSceneFactory {
    static func makeScene() -> (
        scene: SCNScene,
        presentationRoot: SCNNode,
        bellRoot: SCNNode,
        clapperPivot: SCNNode
    ) {
        let presentation = BellPresentationConfiguration.referenceTuned
        let scene = SCNScene()
        scene.background.contents = UIColor(white: presentation.backgroundWhite, alpha: 1)
        scene.lightingEnvironment.contents = makeStudioEnvironment()
        scene.lightingEnvironment.intensity = 0.72

        let presentationRoot = SCNNode()
        scene.rootNode.addChildNode(presentationRoot)

        let bellRoot = SCNNode()
        bellRoot.position = SCNVector3(0, -0.04, 0)
        presentationRoot.addChildNode(bellRoot)

        let modelRoot = SCNNode()
        modelRoot.eulerAngles.x = presentation.tiltTowardViewer
        modelRoot.eulerAngles.z = -0.055
        bellRoot.addChildNode(modelRoot)

        let outerBrass = makeBrassMaterial(
            color: UIColor(red: 0.66, green: 0.47, blue: 0.18, alpha: 1),
            roughness: 0.46,
            brushed: true
        )
        let innerBrass = makeBrassMaterial(
            color: UIColor(red: 0.42, green: 0.285, blue: 0.105, alpha: 1),
            roughness: 0.54,
            brushed: true
        )
        let wood = makeWoodMaterial()
        let silver = makeMetalMaterial(
            color: UIColor(red: 0.64, green: 0.65, blue: 0.63, alpha: 1),
            metalness: 0.92,
            roughness: 0.34
        )
        let clapperBrass = makeBrassMaterial(
            color: UIColor(red: 0.45, green: 0.285, blue: 0.095, alpha: 1),
            roughness: 0.50,
            brushed: false
        )

        addSurface(
            named: "bell-body-outer",
            profile: BellGeometryProfile.bodyOuter,
            radialSegments: 192,
            material: outerBrass,
            to: modelRoot
        )
        addSurface(
            named: "bell-body-inner",
            profile: BellGeometryProfile.bodyInner,
            radialSegments: 192,
            material: innerBrass,
            to: modelRoot
        )
        addSurface(
            named: "bell-rim",
            profile: BellGeometryProfile.rim,
            radialSegments: 192,
            material: outerBrass,
            to: modelRoot
        )
        addSurface(
            named: "bell-crown",
            profile: BellGeometryProfile.crown,
            radialSegments: 192,
            material: outerBrass,
            to: modelRoot
        )

        let collar = SCNCylinder(radius: 0.086, height: 0.070)
        collar.radialSegmentCount = 96
        collar.materials = [silver]
        let collarNode = SCNNode(geometry: collar)
        collarNode.name = "handle-collar"
        collarNode.position.y = 0.755
        modelRoot.addChildNode(collarNode)

        let handleNode = SCNNode(geometry: makeGeometry(
            from: BellRevolvedMesh.make(
                profile: BellGeometryProfile.handle,
                radialSegments: 128
            ),
            material: wood
        ))
        handleNode.name = "bell-handle"
        handleNode.position.y = 0.785
        handleNode.eulerAngles.z = -0.025
        modelRoot.addChildNode(handleNode)

        let clapperGeometry = BellClapperGeometry.referenceTuned
        let clapperPivot = SCNNode()
        clapperPivot.name = "clapper-pivot"
        clapperPivot.position = SCNVector3(
            0,
            Float(clapperGeometry.pivotHeight),
            Float(clapperGeometry.forwardOffset)
        )
        modelRoot.addChildNode(clapperPivot)

        let clapperStem = SCNCylinder(radius: 0.014, height: clapperGeometry.stemHeight)
        clapperStem.radialSegmentCount = 48
        clapperStem.materials = [clapperBrass]
        let stemNode = SCNNode(geometry: clapperStem)
        stemNode.name = "clapper-stem"
        stemNode.position.y = -Float(clapperGeometry.stemHeight / 2)
        clapperPivot.addChildNode(stemNode)

        let clapper = SCNSphere(radius: clapperGeometry.ballRadius)
        clapper.segmentCount = 64
        clapper.materials = [clapperBrass]
        let clapperNode = SCNNode(geometry: clapper)
        clapperNode.name = "clapper"
        clapperNode.position.y = -Float(clapperGeometry.ballCenterDistance)
        clapperPivot.addChildNode(clapperNode)

        addCamera(to: scene)
        addLights(to: scene)

        return (scene, presentationRoot, bellRoot, clapperPivot)
    }

    private static func addSurface(
        named name: String,
        profile: [BellProfilePoint],
        radialSegments: Int,
        material: SCNMaterial,
        to parent: SCNNode
    ) {
        let mesh = BellRevolvedMesh.make(profile: profile, radialSegments: radialSegments)
        let node = SCNNode(geometry: makeGeometry(from: mesh, material: material))
        node.name = name
        parent.addChildNode(node)
    }

    private static func makeGeometry(from mesh: BellSurfaceMesh, material: SCNMaterial) -> SCNGeometry {
        let vertices = mesh.vertices.map { SCNVector3($0.x, $0.y, $0.z) }
        let normals = mesh.normals.map { SCNVector3($0.x, $0.y, $0.z) }
        let textureCoordinates = mesh.textureCoordinates.map {
            CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))
        }

        let sources = [
            SCNGeometrySource(vertices: vertices),
            SCNGeometrySource(normals: normals),
            SCNGeometrySource(textureCoordinates: textureCoordinates)
        ]
        let element = SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: sources, elements: [element])
        geometry.materials = [material]
        return geometry
    }

    private static func makeBrassMaterial(
        color: UIColor,
        roughness: CGFloat,
        brushed: Bool
    ) -> SCNMaterial {
        let material = makeMetalMaterial(
            color: color,
            metalness: 0.88,
            roughness: roughness
        )
        if brushed {
            material.roughness.contents = makeBrushedRoughnessTexture(base: roughness)
            material.roughness.wrapS = .repeat
            material.roughness.wrapT = .repeat
            material.roughness.magnificationFilter = .linear
            material.roughness.minificationFilter = .linear
        }
        return material
    }

    private static func makeMetalMaterial(
        color: UIColor,
        metalness: CGFloat,
        roughness: CGFloat
    ) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.metalness.contents = metalness
        material.roughness.contents = roughness
        material.lightingModel = .physicallyBased
        material.isDoubleSided = false
        return material
    }

    private static func makeWoodMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.105, green: 0.042, blue: 0.019, alpha: 1)
        material.metalness.contents = 0.0
        material.roughness.contents = 0.32
        material.lightingModel = .physicallyBased
        return material
    }

    private static func makeBrushedRoughnessTexture(base: CGFloat) -> UIImage {
        let size = CGSize(width: 32, height: 1024)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            for row in 0..<Int(size.height) {
                let value = BellPresentationConfiguration.referenceTuned.brassRoughness(
                    base: base,
                    row: row
                )
                UIColor(white: value, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: row, width: Int(size.width), height: 1))
            }
        }
    }

    private static func makeStudioEnvironment() -> UIImage {
        let size = CGSize(width: 512, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [
                UIColor(white: 0.34, alpha: 1).cgColor,
                UIColor(white: 0.96, alpha: 1).cgColor,
                UIColor(white: 0.53, alpha: 1).cgColor,
                UIColor(red: 0.93, green: 0.86, blue: 0.73, alpha: 1).cgColor,
                UIColor(white: 0.30, alpha: 1).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.20, 0.43, 0.72, 1.0]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height / 2),
                end: CGPoint(x: size.width, y: size.height / 2),
                options: []
            )
        }
    }

    private static func addCamera(to scene: SCNScene) {
        let target = SCNNode()
        target.position = SCNVector3(0, 0.38, 0)
        scene.rootNode.addChildNode(target)

        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.1
        camera.zFar = 100
        let presentation = BellPresentationConfiguration.referenceTuned
        camera.wantsHDR = presentation.usesHDR
        camera.exposureOffset = 0
        camera.bloomIntensity = 0

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(
            0,
            -0.10,
            Float(presentation.cameraDistance(from: 4.0))
        )
        let lookAt = SCNLookAtConstraint(target: target)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.camera = camera
    }

    private static func addLights(to scene: SCNScene) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 210
        ambient.color = UIColor(white: 0.92, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .omni
        key.intensity = 520
        key.color = UIColor(red: 1.0, green: 0.95, blue: 0.84, alpha: 1)
        key.attenuationStartDistance = 2.0
        key.attenuationEndDistance = 8.0
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(-2.6, 2.4, 3.8)
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 240
        fill.color = UIColor(red: 0.88, green: 0.92, blue: 1.0, alpha: 1)
        fill.attenuationStartDistance = 2.0
        fill.attenuationEndDistance = 8.0
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(2.2, 0.8, 3.4)
        scene.rootNode.addChildNode(fillNode)
    }
}
