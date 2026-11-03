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
    }

    struct WindowSymbol {
        var gapInWall: Segment
        var sillLines: [Segment]
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
    var roomLabels: [RoomLabel] = []
    var roomPolygons: [[SIMD2<Float>]] = []
    /// Plan-space bounding box in meters, padded for dimension lines and
    /// labels drawn outside the building outline.
    var bounds: CGRect = .zero

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
                let hinge = p1
                let openDirection = opening.swingsTowardNormal ? wall.normal : -wall.normal
                let panelEnd = hinge + openDirection * opening.width
                layout.doors.append(DoorSymbol(
                    panelLine: Segment(a: hinge, b: panelEnd),
                    arcCenter: hinge, arcRadius: opening.width,
                    arcStartAngle: atan2(wall.direction.y, wall.direction.x),
                    arcEndAngle: atan2(openDirection.y, openDirection.x),
                    gapInWall: gap))
            case .window:
                let n = wall.normal * (wall.thickness / 2 + 0.03)
                layout.windows.append(WindowSymbol(gapInWall: gap, sillLines: [
                    Segment(a: p1 + n, b: p2 + n),
                    Segment(a: p1 - n, b: p2 - n),
                ]))
            case .opening:
                layout.plainOpenings.append(gap)
            }
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
