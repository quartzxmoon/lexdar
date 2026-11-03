import Foundation
import CoreGraphics
import simd

/// Pure geometry/dimensioning layer shared between the on-screen
/// `BlueprintView` and the PDF exporter: turns a `FloorPlan` into
/// plan-space (meters) drawing primitives with all the dimension-line and
/// door/window-symbol math already done, so neither renderer duplicates
/// it — each just draws these primitives with its own API (SwiftUI
/// `Canvas`/`GraphicsContext` on screen, raw `CGContext` in the PDF).
struct BlueprintLayout {
    struct Segment { var a: SIMD2<Float>; var b: SIMD2<Float> }

    struct DimensionLine {
        var a: SIMD2<Float>
        var b: SIMD2<Float>
        var extensionA: Segment
        var extensionB: Segment
        var label: String
        var midpoint: SIMD2<Float>
        /// Text rotation, in radians, matching the wall's direction.
        var angle: Float
    }

    struct DoorSymbol {
        var panelLine: Segment
        var arcCenter: SIMD2<Float>
        var arcRadius: Float
        var arcStartAngle: Float
        var arcEndAngle: Float
        var gapInWall: Segment
        /// False for sliding / pocket doors, which have no swing arc.
        var drawsArc: Bool = true
        /// Extra leaves, retracted panels, and polyline arcs.
        var extraLines: [Segment] = []
    }

    struct WindowSymbol {
        var gapInWall: Segment
        var sillLines: [Segment]
    }

    /// Outline, tread lines, and an up-arrow, as plain line segments so every
    /// renderer (screen, PDF, DXF) draws them with one loop.
    struct StairSymbol {
        var lines: [Segment]
    }

    struct RoomLabel {
        var name: String
        var areaLabel: String
        var position: SIMD2<Float>
    }

    var wallSegments: [(wall: FloorPlanWall, line: Segment)] = []
    var dimensions: [DimensionLine] = []
    var doors: [DoorSymbol] = []
    var windows: [WindowSymbol] = []
    var plainOpenings: [Segment] = []
    var stairs: [StairSymbol] = []
    var roomLabels: [RoomLabel] = []
    var roomPolygons: [[SIMD2<Float>]] = []
    /// Plan-space bounding box in meters, padded for dimension lines and
    /// labels drawn outside the building outline.
    var bounds: CGRect = .zero

    private static func arcPolyline(center: SIMD2<Float>, radius: Float, from a0: Float, to a1: Float) -> [Segment] {
        var delta = a1 - a0
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        let steps = 8
        var pts: [SIMD2<Float>] = []
        for i in 0...steps {
            let a = a0 + delta * Float(i) / Float(steps)
            pts.append(center + SIMD2<Float>(cos(a), sin(a)) * radius)
        }
        return (0..<steps).map { Segment(a: pts[$0], b: pts[$0 + 1]) }
    }

    private static func doorSymbol(wall: FloorPlanWall, opening: FloorPlanOpening,
                                    p1: SIMD2<Float>, p2: SIMD2<Float>, gap: Segment) -> DoorSymbol {
        let openDirection = opening.swingsTowardNormal ? wall.normal : -wall.normal
        let wallAngle = atan2(wall.direction.y, wall.direction.x)
        let openAngle = atan2(openDirection.y, openDirection.x)
        switch opening.style ?? .single {
        case .double:
            let leaf = opening.width / 2
            var symbol = DoorSymbol(
                panelLine: Segment(a: p1, b: p1 + openDirection * leaf),
                arcCenter: p1, arcRadius: leaf,
                arcStartAngle: wallAngle, arcEndAngle: openAngle, gapInWall: gap)
            symbol.extraLines = [Segment(a: p2, b: p2 + openDirection * leaf)]
                + arcPolyline(center: p2, radius: leaf, from: atan2(-wall.direction.y, -wall.direction.x), to: openAngle)
            return symbol
        case .sliding:
            let n = wall.normal * (wall.thickness / 4)
            let mid = (p1 + p2) / 2
            let overlap = wall.direction * 0.05
            var symbol = DoorSymbol(
                panelLine: Segment(a: p1 + n, b: mid + overlap + n),
                arcCenter: p1, arcRadius: 0, arcStartAngle: 0, arcEndAngle: 0, gapInWall: gap)
            symbol.drawsArc = false
            symbol.extraLines = [Segment(a: mid - overlap - n, b: p2 - n)]
            return symbol
        case .pocket:
            var symbol = DoorSymbol(
                panelLine: Segment(a: p1, b: p2),
                arcCenter: p1, arcRadius: 0, arcStartAngle: 0, arcEndAngle: 0, gapInWall: gap)
            symbol.drawsArc = false
            symbol.extraLines = [Segment(a: p2, b: p2 + wall.direction * opening.width)]
            return symbol
        default:
            return DoorSymbol(
                panelLine: Segment(a: p1, b: p1 + openDirection * opening.width),
                arcCenter: p1, arcRadius: opening.width,
                arcStartAngle: wallAngle, arcEndAngle: openAngle, gapInWall: gap)
        }
    }

    private static func windowSymbol(wall: FloorPlanWall, opening: FloorPlanOpening,
                                      p1: SIMD2<Float>, p2: SIMD2<Float>, gap: Segment) -> WindowSymbol {
        let n = wall.normal * (wall.thickness / 2 + 0.03)
        var lines = [Segment(a: p1 + n, b: p2 + n), Segment(a: p1 - n, b: p2 - n)]
        let mid = (p1 + p2) / 2
        switch opening.style {
        case .casement:
            lines.append(Segment(a: p1, b: p2))
            lines.append(Segment(a: mid + n, b: mid - n))
        case .doubleHung:
            lines.append(Segment(a: p1 + n / 3, b: p2 + n / 3))
            lines.append(Segment(a: p1 - n / 3, b: p2 - n / 3))
        case .fixed:
            lines.append(Segment(a: p1 + n, b: p2 - n))
            lines.append(Segment(a: p1 - n, b: p2 + n))
        default:
            break
        }
        return WindowSymbol(gapInWall: gap, sillLines: lines)
    }

    private static func stairSymbol(_ stair: PlanStair) -> StairSymbol {
        let d = (stair.end - stair.start) / stair.length
        let n = SIMD2<Float>(-d.y, d.x) * (stair.width / 2)
        let a = stair.start - n, b = stair.start + n, c = stair.end + n, e = stair.end - n
        var lines = [Segment(a: a, b: b), Segment(a: b, b: c), Segment(a: c, b: e), Segment(a: e, b: a)]
        let steps = max(stair.stepCount, 2)
        for i in 1..<steps {
            let p = stair.start + d * (stair.length * Float(i) / Float(steps))
            lines.append(Segment(a: p - n, b: p + n))
        }
        let tail = stair.start + d * (stair.length * 0.1)
        let tip = stair.start + d * (stair.length * 0.9)
        let head = stair.width * 0.2
        lines.append(Segment(a: tail, b: tip))
        lines.append(Segment(a: tip, b: tip - d * head + SIMD2<Float>(-d.y, d.x) * head))
        lines.append(Segment(a: tip, b: tip - d * head - SIMD2<Float>(-d.y, d.x) * head))
        return StairSymbol(lines: lines)
    }

    static func build(from plan: FloorPlan, dimensionOffset: Float = 0.5) -> BlueprintLayout {
        var layout = BlueprintLayout()

        for wall in plan.walls {
            layout.wallSegments.append((wall, Segment(a: wall.start, b: wall.end)))

            let offset = wall.normal * dimensionOffset
            let dimA = wall.start + offset
            let dimB = wall.end + offset
            let label = feetInchesLabel(meters: wall.lengthMeters)
            let angle = atan2(wall.direction.y, wall.direction.x)
            layout.dimensions.append(DimensionLine(
                a: dimA, b: dimB,
                extensionA: Segment(a: wall.start, b: dimA),
                extensionB: Segment(a: wall.end, b: dimB),
                label: label, midpoint: (dimA + dimB) / 2, angle: angle))
        }

        for opening in plan.openings {
            guard let wall = plan.walls.first(where: { $0.id == opening.wallID }) else { continue }
            let center = wall.point(atDistance: opening.distanceFromWallStart)
            let half = opening.width / 2
            let p1 = center - wall.direction * half
            let p2 = center + wall.direction * half
            let gap = Segment(a: p1, b: p2)

            switch opening.kind {
            case .door:
                layout.doors.append(doorSymbol(wall: wall, opening: opening, p1: p1, p2: p2, gap: gap))
            case .window:
                layout.windows.append(windowSymbol(wall: wall, opening: opening, p1: p1, p2: p2, gap: gap))
            case .opening:
                layout.plainOpenings.append(gap)
            }
        }

        for stair in plan.stairList where stair.length > 0.1 {
            layout.stairs.append(stairSymbol(stair))
        }

        for room in plan.rooms where room.polygon.count >= 3 {
            layout.roomPolygons.append(room.polygon)
            let sqft = room.areaSquareMeters * 10.7639
            layout.roomLabels.append(RoomLabel(name: room.name,
                                                 areaLabel: String(format: "%.0f SF", sqft),
                                                 position: room.centroid))
        }

        layout.bounds = computeBounds(plan: plan)
        return layout
    }

    private static func computeBounds(plan: FloorPlan) -> CGRect {
        var minX = Float.greatestFiniteMagnitude, minY = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        var any = false
        for wall in plan.walls {
            for p in [wall.start, wall.end] {
                any = true
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
        }
        guard any else { return .zero }
        let pad: Float = 1.2 // meters, room for dimension lines + labels
        return CGRect(x: Double(minX - pad), y: Double(minY - pad),
                      width: Double(maxX - minX) + Double(pad * 2),
                      height: Double(maxY - minY) + Double(pad * 2))
    }

    /// Architectural feet-and-inches notation, e.g. `12'-6"`.
    static func feetInchesLabel(meters: Float) -> String {
        let totalInches = meters * 39.3701
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
        return "\(feet)'-\(inches)\""
    }
}
