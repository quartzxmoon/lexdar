import Foundation
import simd

#if canImport(RoomPlan)
import RoomPlan

/// Converts a processed `CapturedRoom` into this app's own `FloorPlan`
/// model (see `Models/FloorPlan.swift` for why that model exists). This is
/// a one-time, one-directional conversion done when the user asks to
/// generate a floor plan from a scan — the resulting `FloorPlan` is then
/// editable independently (e.g. hand-correcting a wall RoomPlan
/// misjudged), same as a fully hand-drawn plan.
enum RoomPlanImporter {
    static func makeFloorPlan(from room: CapturedRoom, scanID: UUID, name: String) -> FloorPlan {
        let walls = room.walls.map { surface -> FloorPlanWall in
            let (start, end) = topDownEndpoints(of: surface)
            return FloorPlanWall(id: surface.identifier, start: start, end: end,
                                  height: surface.dimensions.y,
                                  thickness: max(surface.dimensions.z, 0.05))
        }

        var openings: [FloorPlanOpening] = []
        openings += room.doors.map { makeOpening($0, kind: .door, walls: room.walls) }
        openings += room.windows.map { makeOpening($0, kind: .window, walls: room.walls) }
        openings += room.openings.map { makeOpening($0, kind: .opening, walls: room.walls) }

        let rooms = room.floors.enumerated().map { index, floor -> FloorPlanRoom in
            let polygon = floor.polygonCorners.map { SIMD2<Float>($0.x, $0.z) }
            return FloorPlanRoom(id: floor.identifier, name: "Room \(index + 1)", polygon: polygon)
        }

        return FloorPlan(name: name, source: .lidarScan(scanID: scanID),
                          walls: walls, openings: openings, rooms: rooms)
    }

    private static func topDownEndpoints(of surface: CapturedRoom.Surface) -> (SIMD2<Float>, SIMD2<Float>) {
        let t = surface.transform
        let center = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        let xAxis = SIMD3<Float>(t.columns.0.x, t.columns.0.y, t.columns.0.z)
        let half = surface.dimensions.x / 2
        let p1 = center - xAxis * half
        let p2 = center + xAxis * half
        return (SIMD2(p1.x, p1.z), SIMD2(p2.x, p2.z))
    }

    /// RoomPlan ties a door/window/opening to its containing wall via
    /// `Surface.parentIdentifier`. Fall back to nearest-wall-by-center (for
    /// any case where a parent identifier isn't populated) so an opening is
    /// never silently dropped.
    private static func makeOpening(_ surface: CapturedRoom.Surface, kind: OpeningKind,
                                     walls: [CapturedRoom.Surface]) -> FloorPlanOpening {
        let wall: CapturedRoom.Surface? = surface.parentIdentifier.flatMap { parentID in
            walls.first { $0.identifier == parentID }
        } ?? walls.min { distanceBetweenCenters($0, surface) < distanceBetweenCenters($1, surface) }

        guard let wall else {
            // No walls at all in this scan (shouldn't normally happen) --
            // keep the opening with a dangling wallID rather than crash;
            // the blueprint renderer simply won't find a wall to draw it on.
            return FloorPlanOpening(wallID: UUID(), kind: kind,
                                     distanceFromWallStart: 0, width: surface.dimensions.x)
        }

        let (wallStart, _) = topDownEndpoints(of: wall)
        let t = surface.transform
        let center2D = SIMD2<Float>(t.columns.3.x, t.columns.3.z)
        let distance = simd_length(center2D - wallStart)

        return FloorPlanOpening(wallID: wall.identifier, kind: kind,
                                 distanceFromWallStart: distance, width: surface.dimensions.x)
    }

    private static func distanceBetweenCenters(_ a: CapturedRoom.Surface, _ b: CapturedRoom.Surface) -> Float {
        let ac = SIMD3<Float>(a.transform.columns.3.x, a.transform.columns.3.y, a.transform.columns.3.z)
        let bc = SIMD3<Float>(b.transform.columns.3.x, b.transform.columns.3.y, b.transform.columns.3.z)
        return simd_length(ac - bc)
    }
}
#endif
