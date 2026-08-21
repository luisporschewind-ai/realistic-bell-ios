import Foundation

struct BellSurfaceMesh {
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let textureCoordinates: [SIMD2<Float>]
    let indices: [Int32]
}

enum BellRevolvedMesh {
    static func make(
        profile: [BellProfilePoint],
        radialSegments requestedSegments: Int
    ) -> BellSurfaceMesh {
        guard profile.count >= 2 else {
            return BellSurfaceMesh(vertices: [], normals: [], textureCoordinates: [], indices: [])
        }

        let radialSegments = max(requestedSegments, 8)
        let verticesPerRow = radialSegments + 1
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var textureCoordinates: [SIMD2<Float>] = []
        var indices: [Int32] = []

        vertices.reserveCapacity(profile.count * verticesPerRow)
        normals.reserveCapacity(profile.count * verticesPerRow)
        textureCoordinates.reserveCapacity(profile.count * verticesPerRow)
        indices.reserveCapacity((profile.count - 1) * radialSegments * 6)

        for profileIndex in profile.indices {
            let previous = profile[max(profileIndex - 1, profile.startIndex)]
            let next = profile[min(profileIndex + 1, profile.index(before: profile.endIndex))]
            let radialNormal = Float(-(next.height - previous.height))
            let verticalNormal = Float(next.radius - previous.radius)
            let normalLength = max(sqrt(radialNormal * radialNormal + verticalNormal * verticalNormal), 0.000_001)
            let normalizedRadial = radialNormal / normalLength
            let normalizedVertical = verticalNormal / normalLength

            for segment in 0...radialSegments {
                let fraction = Float(segment) / Float(radialSegments)
                let angle = fraction * 2 * Float.pi
                let cosine = cos(angle)
                let sine = sin(angle)

                vertices.append(SIMD3(
                    Float(profile[profileIndex].radius) * cosine,
                    Float(profile[profileIndex].height),
                    Float(profile[profileIndex].radius) * sine
                ))
                normals.append(SIMD3(
                    normalizedRadial * cosine,
                    normalizedVertical,
                    normalizedRadial * sine
                ))
                textureCoordinates.append(SIMD2(
                    fraction,
                    Float(profileIndex) / Float(profile.count - 1)
                ))
            }
        }

        for profileIndex in 0..<(profile.count - 1) {
            let row = profileIndex * verticesPerRow
            let nextRow = (profileIndex + 1) * verticesPerRow
            for segment in 0..<radialSegments {
                let topLeft = Int32(row + segment)
                let topRight = Int32(row + segment + 1)
                let bottomLeft = Int32(nextRow + segment)
                let bottomRight = Int32(nextRow + segment + 1)
                indices.append(contentsOf: [topLeft, topRight, bottomLeft])
                indices.append(contentsOf: [topRight, bottomRight, bottomLeft])
            }
        }

        return BellSurfaceMesh(
            vertices: vertices,
            normals: normals,
            textureCoordinates: textureCoordinates,
            indices: indices
        )
    }
}
