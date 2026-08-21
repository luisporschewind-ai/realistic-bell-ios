import Foundation

@main
struct BellRevolvedMeshTests {
    static func main() {
        let outerProfile = [
            BellProfilePoint(radius: 0.20, height: 0.50),
            BellProfilePoint(radius: 0.30, height: 0.00),
            BellProfilePoint(radius: 0.50, height: -0.50)
        ]
        let outer = BellRevolvedMesh.make(profile: outerProfile, radialSegments: 8)

        precondition(outer.vertices.count == 27, "The seam needs one duplicated vertex per profile row")
        precondition(outer.normals.count == outer.vertices.count, "Every vertex must have an explicit smooth normal")
        precondition(outer.textureCoordinates.count == outer.vertices.count, "Every vertex must carry brushed-metal texture coordinates")
        precondition(outer.indices.count == 96, "Only adjacent profile rows should be connected")
        precondition(outer.indices.max() == 26, "Mesh indices must remain inside the generated vertex buffer")

        let outerFrontNormal = outer.normals[9]
        precondition(outerFrontNormal.x > 0.90, "Top-to-bottom outer profiles must face away from the bell axis")

        let innerProfile = outerProfile.reversed()
        let inner = BellRevolvedMesh.make(profile: Array(innerProfile), radialSegments: 8)
        let innerFrontNormal = inner.normals[9]
        precondition(innerFrontNormal.x < -0.90, "Bottom-to-top inner profiles must face into the hollow cavity")

        for normal in outer.normals + inner.normals {
            let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            precondition(abs(length - 1) < 0.0001, "Smooth normals must be normalized")
        }

        print("BellRevolvedMeshTests passed")
    }
}
