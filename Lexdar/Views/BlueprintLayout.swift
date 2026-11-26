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

    /// A drawn electrical/plumbing/data symbol: lines only, so every renderer
    /// strokes it with one loop. `tagPosition` is where the short tag text goes.
    struct SymbolGlyph {
        var kind: SymbolKind
        var lines: [Segment]
        var tag: String
        var tagPosition: SIMD2<Float>
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
    var symbols: [SymbolGlyph] = []
    /// Cross-ticks along walls the user marked as load-bearing.
    var bearingTicks: [Segment] = []
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

    private static func circle(_ c: SIMD2<Float>, _ r: Float, steps: Int = 12) -> [Segment] {
        (0..<steps).map { i in
            let a0 = Float(i) / Float(steps) * 2 * .pi
            let a1 = Float(i + 1) / Float(steps) * 2 * .pi
            return Segment(a: c + SIMD2<Float>(cos(a0), sin(a0)) * r, b: c + SIMD2<Float>(cos(a1), sin(a1)) * r)
        }
    }

    private static func polygon(_ pts: [SIMD2<Float>]) -> [Segment] {
        (0..<pts.count).map { Segment(a: pts[$0], b: pts[($0 + 1) % pts.count]) }
    }

    /// Line-art glyph for a symbol, about 0.3 m across, centered on `c`.
    static func glyph(for kind: SymbolKind, at c: SIMD2<Float>) -> [Segment] {
        let r: Float = 0.15
        func p(_ x: Float, _ y: Float) -> SIMD2<Float> { c + SIMD2<Float>(x, y) }
        func seg(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Segment { Segment(a: a, b: b) }
        switch kind {
        case .outlet:
            return circle(c, r) + [seg(p(-r * 0.5, -r), p(-r * 0.5, r)), seg(p(r * 0.5, -r), p(r * 0.5, r))]
        case .outletGFCI:
            return circle(c, r) + [seg(p(-r * 0.5, -r), p(-r * 0.5, r)), seg(p(r * 0.5, -r), p(r * 0.5, r)),
                                   seg(p(-r, 0), p(r, 0))]
        case .outlet240:
            return circle(c, r) + [seg(p(-r * 0.6, -r * 0.5), p(r * 0.6, -r * 0.5)), seg(p(-r * 0.6, r * 0.5), p(r * 0.6, r * 0.5)),
                                   seg(p(0, -r), p(0, r))]
        case .switchSingle, .switchThreeWay, .dimmer:
            var lines = circle(c, r * 0.55) + [seg(p(r * 0.4, -r * 0.4), p(r * 1.4, -r * 1.4))]
            if kind == .switchThreeWay { lines.append(seg(p(r * 0.9, -r * 1.7), p(r * 1.9, -r * 0.7))) }
            if kind == .dimmer { lines += circle(c, r * 0.9, steps: 10) }
            return lines
        case .ceilingLight:
            return circle(c, r) + [seg(p(-r * 0.7, -r * 0.7), p(r * 0.7, r * 0.7)), seg(p(-r * 0.7, r * 0.7), p(r * 0.7, -r * 0.7))]
        case .recessedLight:
            return circle(c, r) + circle(c, r * 0.5, steps: 8)
        case .ceilingFan:
            return circle(c, r * 1.2) + [seg(p(-r * 1.2, 0), p(r * 1.2, 0)), seg(p(0, -r * 1.2), p(0, r * 1.2))]
        case .panel:
            return polygon([p(-r, -r * 1.3), p(r, -r * 1.3), p(r, r * 1.3), p(-r, r * 1.3)]) + [seg(p(-r, -r * 1.3), p(r, r * 1.3))]
        case .junction:
            return circle(c, r * 0.8) + [seg(p(-r * 0.6, -r * 0.6), p(r * 0.6, r * 0.6)), seg(p(-r * 0.6, r * 0.6), p(r * 0.6, -r * 0.6))]
        case .waterHeater:
            return circle(c, r * 1.2) + [seg(p(-r * 0.6, -r * 0.6), p(r * 0.6, r * 0.6))]
        case .hoseBib:
            return polygon([p(0, -r), p(r, r), p(-r, r)])
        case .cleanout:
            return circle(c, r) + [seg(p(-r, 0), p(r, 0))]
        case .floorDrain:
            return polygon([p(-r, -r), p(r, -r), p(r, r), p(-r, r)]) + [seg(p(-r, -r), p(r, r)), seg(p(-r, r), p(r, -r))]
        case .shutoff:
            return polygon([p(0, -r * 1.2), p(r * 1.2, 0), p(0, r * 1.2), p(-r * 1.2, 0)])
        case .gasShutoff:
            return polygon([p(0, -r * 1.2), p(r * 1.2, 0), p(0, r * 1.2), p(-r * 1.2, 0)]) + [seg(p(-r * 0.6, 0), p(r * 0.6, 0))]
        case .ethernet:
            return polygon([p(0, -r), p(r, r), p(-r, r)]) + [seg(p(0, -r * 0.1), p(0, r * 0.6))]
        case .coax:
            return polygon([p(-r, -r), p(r, -r), p(r, r), p(-r, r)]) + circle(c, r * 0.4, steps: 8)
        case .smokeAlarm:
            return circle(c, r) + circle(c, r * 0.6, steps: 10)
        case .coAlarm:
            return circle(c, r) + [seg(p(-r * 0.5, -r * 0.5), p(r * 0.5, -r * 0.5)), seg(p(-r * 0.5, r * 0.5), p(r * 0.5, r * 0.5))]
        case .thermostat:
            return polygon([p(-r, -r * 0.8), p(r, -r * 0.8), p(r, r * 0.8), p(-r, r * 0.8)]) + circle(c, r * 0.4, steps: 8)
        }
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

        for symbol in plan.symbolList {
            layout.symbols.append(SymbolGlyph(kind: symbol.kind, lines: glyph(for: symbol.kind, at: symbol.position),
                                              tag: symbol.kind.tag, tagPosition: symbol.position + SIMD2<Float>(0, 0.32)))
        }

        for wall in plan.walls where wall.structure == .loadBearing && wall.lengthMeters > 0.3 {
            let half = wall.normal * (wall.thickness / 2 + 0.03)
            let count = max(2, Int(wall.lengthMeters / 0.3))
            for i in 0...count {
                let c = wall.point(atDistance: wall.lengthMeters * Float(i) / Float(count))
                layout.bearingTicks.append(Segment(a: c - half, b: c + half))
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
