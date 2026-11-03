import Foundation
import simd

/// App-owned 2D floor plan model — deliberately independent of RoomPlan's
/// `CapturedRoom`, which has no public initializer and can only ever be
/// produced by the framework itself. A `FloorPlan` is what makes a plan
/// drawn by hand with Apple Pencil and a plan generated from a LiDAR scan
/// into the *same kind of thing*: both end up as walls/openings/rooms in
/// this model, so the blueprint renderer, dimensioning, and PDF export all
/// work identically regardless of where the plan came from.
///
/// All geometry is top-down (plan view): a point is `SIMD2<Float>(x, z)` in
/// meters, matching ARKit/RoomPlan's world space with the vertical (height)
/// axis dropped. For a hand-drawn plan with no ARKit session behind it,
/// these are just plan-space meters with an arbitrary origin.
struct FloorPlanWall: Identifiable, Codable, Hashable {
    let id: UUID
    var start: SIMD2<Float>
    var end: SIMD2<Float>
    /// Floor-to-ceiling height in meters. Defaults to a standard 8ft wall
    /// when hand-drawn (no way to measure height without LiDAR).
    var height: Float
    /// Wall thickness in meters, drawn as a double line this thick in the
    /// blueprint renderer. Defaults to a standard 2x4 interior wall (~4.5in
    /// finished) when hand-drawn.
    var thickness: Float

    init(id: UUID = UUID(), start: SIMD2<Float>, end: SIMD2<Float>,
         height: Float = 2.4384, thickness: Float = 0.1143) {
        self.id = id
        self.start = start
        self.end = end
        self.height = height
        self.thickness = thickness
    }

    var lengthMeters: Float { simd_length(end - start) }

    /// Unit vector from `start` toward `end`; `.zero` for a degenerate
    /// (zero-length) wall, which the UI should prevent from being created.
    var direction: SIMD2<Float> {
        let d = end - start
        let len = simd_length(d)
        return len > 0.0001 ? d / len : .zero
    }

    /// Perpendicular (left-hand normal) unit vector, used to offset
    /// dimension/extension lines and to pick which side a door swings.
    var normal: SIMD2<Float> {
        let d = direction
        return SIMD2<Float>(-d.y, d.x)
    }

    func point(atDistance distance: Float) -> SIMD2<Float> {
        start + direction * distance
    }
}

enum OpeningKind: String, Codable, CaseIterable, Identifiable {
    case door
    case window
    case opening // a wall gap with no door/window (archway, pass-through)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .door: return "Door"
        case .window: return "Window"
        case .opening: return "Opening"
        }
    }
}

/// A door, window, or plain opening cut into exactly one wall.
struct FloorPlanOpening: Identifiable, Codable, Hashable {
    let id: UUID
    var wallID: UUID
    var kind: OpeningKind
    /// Distance in meters from the wall's `start` point to the opening's
    /// center, measured along the wall.
    var distanceFromWallStart: Float
    var width: Float
    /// Only meaningful for `.door`: which side of the wall (relative to its
    /// `normal`) the door swings open toward, for drawing the swing arc.
    var swingsTowardNormal: Bool

    init(id: UUID = UUID(), wallID: UUID, kind: OpeningKind, distanceFromWallStart: Float,
         width: Float, swingsTowardNormal: Bool = true) {
        self.id = id
        self.wallID = wallID
        self.kind = kind
        self.distanceFromWallStart = distanceFromWallStart
        self.width = width
        self.swingsTowardNormal = swingsTowardNormal
    }

    /// A few common U.S. residential sizes, offered as quick picks in the
    /// hand-drawn editor rather than requiring a precise manual entry.
    static func standardWidths(for kind: OpeningKind) -> [Float] {
        switch kind {
        case .door: return [0.711, 0.762, 0.813, 0.914] // 28/30/32/36 in
        case .window: return [0.61, 0.914, 1.219, 1.524] // 24/36/48/60 in
        case .opening: return [0.914, 1.219, 1.829]       // 36/48/72 in
        }
    }
}

/// A room's floor boundary, used to compute square footage and to place
/// the room's name label at its centroid. The polygon is a closed loop in
/// plan-space meters (do not repeat the first point as the last).
struct FloorPlanRoom: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var polygon: [SIMD2<Float>]

    init(id: UUID = UUID(), name: String, polygon: [SIMD2<Float>]) {
        self.id = id
        self.name = name
        self.polygon = polygon
    }

    /// Shoelace formula. Returns 0 for a degenerate (fewer than 3 point)
    /// polygon rather than crashing or returning garbage.
    var areaSquareMeters: Float {
        guard polygon.count >= 3 else { return 0 }
        var sum: Float = 0
        for i in 0..<polygon.count {
            let a = polygon[i]
            let b = polygon[(i + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    var centroid: SIMD2<Float> {
        guard !polygon.isEmpty else { return .zero }
        let sum = polygon.reduce(SIMD2<Float>.zero, +)
        return sum / Float(polygon.count)
    }
}

enum FloorPlanSource: Codable, Hashable {
    /// Generated from a LiDAR scan; `scanID` names the originating
    /// `ScanProject` so the two stay linked in the UI.
    case lidarScan(scanID: UUID)
    /// Drawn entirely by hand (finger or Apple Pencil) with no LiDAR
    /// involved — e.g. documenting an older structure, or sketching a
    /// renovation concept before ever scanning the real space.
    case handDrawn
}

/// A photo and/or note pinned to a specific point on the plan — the
/// "take photos and type or dictate notes onto them, and see them
/// automatically positioned on the plan" survey/inventory workflow.
/// `photoFilename`, when present, names a JPEG stored alongside this
/// floor plan's own files (see `ScanStore.photoURL(for:in:)`); the
/// annotation itself stores only the filename, never the image data, so
/// the `FloorPlan` JSON stays small.
struct PlanAnnotation: Identifiable, Codable, Hashable {
    let id: UUID
    var position: SIMD2<Float>
    var note: String
    var photoFilename: String?
    let createdAt: Date

    init(id: UUID = UUID(), position: SIMD2<Float>, note: String = "", photoFilename: String? = nil) {
        self.id = id
        self.position = position
        self.note = note
        self.photoFilename = photoFilename
        self.createdAt = Date()
    }
}

/// A complete floor plan: one level's worth of walls, openings, and room
/// boundaries, at a known real-world scale. This is the thing contractor-
/// grade blueprints are rendered from (see `BlueprintView` /
/// `BlueprintPDFRenderer`), whether it came from a LiDAR scan or was drawn
/// by hand.
struct FloorPlan: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var source: FloorPlanSource
    var walls: [FloorPlanWall]
    var openings: [FloorPlanOpening]
    var rooms: [FloorPlanRoom]
    var annotations: [PlanAnnotation]
    /// Free-form notes shown on the blueprint's title block / cover sheet.
    var notes: String

    init(id: UUID = UUID(), name: String, source: FloorPlanSource,
         walls: [FloorPlanWall] = [], openings: [FloorPlanOpening] = [],
         rooms: [FloorPlanRoom] = [], annotations: [PlanAnnotation] = [], notes: String = "") {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.source = source
        self.walls = walls
        self.openings = openings
        self.rooms = rooms
        self.annotations = annotations
        self.notes = notes
    }

    var scanID: UUID? {
        if case .lidarScan(let scanID) = source { return scanID }
        return nil
    }

    var totalAreaSquareMeters: Float {
        rooms.reduce(0) { $0 + $1.areaSquareMeters }
    }

    func openings(on wallID: UUID) -> [FloorPlanOpening] {
        openings.filter { $0.wallID == wallID }
    }

    mutating func touch() { updatedAt = Date() }
}
