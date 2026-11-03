import Foundation
import simd

/// Vertical extent of a wall opening, shared by the mesh and IFC exporters
/// so a door or window is the same size in every output format.
enum OpeningProfile {
    static func vertical(for kind: OpeningKind, wallHeight: Float) -> (sill: Float, head: Float) {
        switch kind {
        case .door: return (0, min(2.032, wallHeight))
        case .window:
            let sill: Float = 0.9
            return (sill, min(sill + 1.2, wallHeight))
        case .opening: return (0, wallHeight)
        }
    }
}

/// A plain triangle mesh built straight from a `FloorPlan` (walls with
/// real door/window cut-outs, plus room floors). World axes: x = plan x,
/// y = up, z = plan y, in meters. Independent of SceneKit so the text
/// writers below (OBJ / PLY / XYZ) are pure string formatting.
struct FloorPlanMesh {
    var vertices: [SIMD3<Float>] = []
    var triangles: [SIMD3<Int>] = []

    init(plan: FloorPlan) {
        for wall in plan.walls where wall.lengthMeters > 0.02 {
            addWall(wall, openings: plan.openings(on: wall.id))
        }
        for room in plan.rooms where room.polygon.count >= 3 {
            addFloor(room.polygon)
        }
    }

    private mutating func addWall(_ wall: FloorPlanWall, openings: [FloorPlanOpening]) {
        let sorted = openings.sorted { $0.distanceFromWallStart < $1.distanceFromWallStart }
        var cursor: Float = 0
        for opening in sorted {
            let openStart = max(0, opening.distanceFromWallStart - opening.width / 2)
            let openEnd = min(wall.lengthMeters, opening.distanceFromWallStart + opening.width / 2)
            if openStart > cursor + 0.01 {
                addBox(wall, from: cursor, to: openStart, y0: 0, y1: wall.height)
            }
            let (sill, head) = OpeningProfile.vertical(for: opening.kind, wallHeight: wall.height)
            if openEnd - openStart > 0.01 {
                if sill > 0.01 { addBox(wall, from: openStart, to: openEnd, y0: 0, y1: sill) }
                if wall.height - head > 0.01 { addBox(wall, from: openStart, to: openEnd, y0: head, y1: wall.height) }
            }
            cursor = max(cursor, openEnd)
        }
        if wall.lengthMeters - cursor > 0.01 {
            addBox(wall, from: cursor, to: wall.lengthMeters, y0: 0, y1: wall.height)
        }
    }

    private mutating func addBox(_ wall: FloorPlanWall, from d0: Float, to d1: Float, y0: Float, y1: Float) {
        let half = max(wall.thickness, 0.05) / 2
        let a = wall.point(atDistance: d0)
        let b = wall.point(atDistance: d1)
        let n = wall.normal * half
        // bit0: start/end, bit1: -n/+n, bit2: bottom/top
        let plan: [SIMD2<Float>] = [a - n, b - n, a + n, b + n]
        var c: [SIMD3<Float>] = []
        for i in 0..<8 {
            let p = plan[i & 3]
            c.append(SIMD3<Float>(p.x, (i & 4) == 0 ? y0 : y1, p.y))
        }
        let center = c.reduce(SIMD3<Float>.zero, +) / 8
        let faces: [[Int]] = [[0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6], [0, 1, 3, 2], [4, 5, 7, 6]]
        for face in faces {
            addQuad(c[face[0]], c[face[1]], c[face[2]], c[face[3]], awayFrom: center)
        }
    }

    private mutating func addQuad(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>, _ p2: SIMD3<Float>,
                                   _ p3: SIMD3<Float>, awayFrom center: SIMD3<Float>) {
        let faceCenter = (p0 + p1 + p2 + p3) / 4
        let outward = faceCenter - center
        let flip = simd_dot(simd_cross(p1 - p0, p2 - p0), outward) < 0
        let base = vertices.count
        vertices.append(contentsOf: [p0, p1, p2, p3])
        if flip {
            triangles.append(SIMD3(base, base + 2, base + 1))
            triangles.append(SIMD3(base, base + 3, base + 2))
        } else {
            triangles.append(SIMD3(base, base + 1, base + 2))
            triangles.append(SIMD3(base, base + 2, base + 3))
        }
    }

    private mutating func addFloor(_ polygon: [SIMD2<Float>]) {
        let base = vertices.count
        for p in polygon { vertices.append(SIMD3<Float>(p.x, 0, p.y)) }
        for tri in FloorPlanMesh.triangulate(polygon) {
            let a = vertices[base + tri.0], b = vertices[base + tri.1], c = vertices[base + tri.2]
            let up = simd_cross(b - a, c - a).y >= 0
            triangles.append(up ? SIMD3(base + tri.0, base + tri.1, base + tri.2)
                                : SIMD3(base + tri.0, base + tri.2, base + tri.1))
        }
    }

    /// Ear clipping; falls back to a fan for whatever is left if the
    /// polygon is degenerate or self-intersecting.
    static func triangulate(_ polygon: [SIMD2<Float>]) -> [(Int, Int, Int)] {
        var area: Float = 0
        for i in polygon.indices {
            let p = polygon[i], q = polygon[(i + 1) % polygon.count]
            area += p.x * q.y - q.x * p.y
        }
        var idx = Array(polygon.indices)
        if area < 0 { idx.reverse() }

        func cross(_ o: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        func inside(_ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Bool {
            cross(a, b, p) >= 0 && cross(b, c, p) >= 0 && cross(c, a, p) >= 0
        }

        var result: [(Int, Int, Int)] = []
        while idx.count > 3 {
            var clipped = false
            for i in idx.indices {
                let ip = idx[(i + idx.count - 1) % idx.count], ic = idx[i], inx = idx[(i + 1) % idx.count]
                let a = polygon[ip], b = polygon[ic], c = polygon[inx]
                if cross(a, b, c) <= 0 { continue }
                let blocked = idx.contains { k in
                    k != ip && k != ic && k != inx && inside(polygon[k], a, b, c)
                }
                if blocked { continue }
                result.append((ip, ic, inx))
                idx.remove(at: i)
                clipped = true
                break
            }
            if !clipped {
                for i in 1..<(idx.count - 1) { result.append((idx[0], idx[i], idx[i + 1])) }
                return result
            }
        }
        if idx.count == 3 { result.append((idx[0], idx[1], idx[2])) }
        return result
    }

    // MARK: - Writers

    private static func num(_ v: Float) -> String { String(format: "%.5f", v) }

    func objText(name: String) -> String {
        var out = "# Lexdar floor plan export - units: meters, Y up\no \(name.replacingOccurrences(of: " ", with: "_"))\n"
        for v in vertices { out += "v \(Self.num(v.x)) \(Self.num(v.y)) \(Self.num(v.z))\n" }
        for t in triangles { out += "f \(t.x + 1) \(t.y + 1) \(t.z + 1)\n" }
        return out
    }

    func plyText() -> String {
        var out = "ply\nformat ascii 1.0\ncomment Lexdar floor plan export - units: meters, Y up\n"
        out += "element vertex \(vertices.count)\nproperty float x\nproperty float y\nproperty float z\n"
        out += "element face \(triangles.count)\nproperty list uchar int vertex_indices\nend_header\n"
        for v in vertices { out += "\(Self.num(v.x)) \(Self.num(v.y)) \(Self.num(v.z))\n" }
        for t in triangles { out += "3 \(t.x) \(t.y) \(t.z)\n" }
        return out
    }

    /// Unique vertices only. These are the corners of the modeled walls and
    /// floors, not a sampled scan point cloud.
    func xyzText() -> String {
        var seen = Set<String>()
        var out = ""
        for v in vertices {
            let line = "\(Self.num(v.x)) \(Self.num(v.y)) \(Self.num(v.z))\n"
            if seen.insert(line).inserted { out += line }
        }
        return out
    }
}
