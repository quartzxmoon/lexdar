import SwiftUI
import simd

/// Formal, dimensioned floor-plan drawing rendered from a `FloorPlan` via
/// `BlueprintLayout` — this is the "contractor-grade" output: walls drawn
/// to their real thickness, dimension lines with extension lines, door
/// swing arcs, window break symbols, room name + square-footage labels, a
/// scale bar, and a north arrow. The same `BlueprintLayout` is drawn again
/// (with `CGContext` instead of SwiftUI's `GraphicsContext`) by
/// `BlueprintPDFRenderer` for export, so what you see here is what prints.
///
/// This reads a `FloorPlan` and performs no camera work itself — it draws
/// identically whether that plan came from a LiDAR scan (via
/// `RoomPlanImporter`) or was drawn by hand (`BlueprintEditorView`).
struct BlueprintView: View {
    let floorPlan: FloorPlan

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .background(Color.white)
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in zoom = max(0.3, min(6, lastZoom * value)) }
                        .onEnded { _ in lastZoom = zoom },
                    DragGesture()
                        .onChanged { value in
                            panOffset = CGSize(width: lastPanOffset.width + value.translation.width,
                                                height: lastPanOffset.height + value.translation.height)
                        }
                        .onEnded { _ in lastPanOffset = panOffset }
                )
            )
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let layout = BlueprintLayout.build(from: floorPlan)
        guard layout.bounds.width > 0, layout.bounds.height > 0 else {
            context.draw(Text("No walls yet").foregroundStyle(.secondary),
                          at: CGPoint(x: size.width / 2, y: size.height / 2))
            return
        }

        let margin: CGFloat = 32
        let fitScale = min((size.width - margin * 2) / layout.bounds.width,
                            (size.height - margin * 2 - 60) / layout.bounds.height) // room for title block
        let scale = fitScale * zoom

        func project(_ p: SIMD2<Float>) -> CGPoint {
            CGPoint(x: (CGFloat(p.x) - layout.bounds.minX) * scale + margin + panOffset.width,
                     y: (CGFloat(p.y) - layout.bounds.minY) * scale + margin + panOffset.height)
        }

        drawWalls(layout, project: project, scale: scale, context: &context)
        drawOpenings(layout, project: project, context: &context)
        drawRooms(layout, project: project, context: &context)
        drawDimensions(layout, project: project, context: &context)
        drawScaleBarAndNorth(scale: scale, size: size, context: &context)
        drawTitleBlock(size: size, context: &context)
    }

    private func drawWalls(_ layout: BlueprintLayout, project: (SIMD2<Float>) -> CGPoint,
                            scale: CGFloat, context: inout GraphicsContext) {
        for (wall, line) in layout.wallSegments {
            // Gaps for openings on this wall are drawn by simply layering the
            // opening symbols on top -- the wall line underneath is thin
            // enough, and the symbols wide enough, that this reads clearly
            // at typical print scales without needing path subtraction.
            var path = Path()
            path.move(to: project(line.a))
            path.addLine(to: project(line.b))
            let width = max(2, CGFloat(wall.thickness) * scale)
            context.stroke(path, with: .color(.black), lineWidth: width)
        }
    }

    private func drawOpenings(_ layout: BlueprintLayout, project: (SIMD2<Float>) -> CGPoint,
                               context: inout GraphicsContext) {
        for door in layout.doors {
            var gap = Path()
            gap.move(to: project(door.gapInWall.a))
            gap.addLine(to: project(door.gapInWall.b))
            context.stroke(gap, with: .color(.white), lineWidth: 5)

            var panel = Path()
            panel.move(to: project(door.panelLine.a))
            panel.addLine(to: project(door.panelLine.b))
            context.stroke(panel, with: .color(.black), lineWidth: 1.2)

            let center = project(door.arcCenter)
            let radius = project(door.arcCenter + SIMD2<Float>(door.arcRadius, 0)).x - center.x
            var arc = Path()
            arc.addArc(center: center, radius: abs(radius),
                       startAngle: .radians(Double(door.arcStartAngle)),
                       endAngle: .radians(Double(door.arcEndAngle)), clockwise: false)
            context.stroke(arc, with: .color(.black.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
        }

        for window in layout.windows {
            var gap = Path()
            gap.move(to: project(window.gapInWall.a))
            gap.addLine(to: project(window.gapInWall.b))
            context.stroke(gap, with: .color(.white), lineWidth: 5)
            for sill in window.sillLines {
                var path = Path()
                path.move(to: project(sill.a))
                path.addLine(to: project(sill.b))
                context.stroke(path, with: .color(.black), lineWidth: 1)
            }
        }

        for opening in layout.plainOpenings {
            var gap = Path()
            gap.move(to: project(opening.a))
            gap.addLine(to: project(opening.b))
            context.stroke(gap, with: .color(.white), lineWidth: 5)
        }
    }

    private func drawRooms(_ layout: BlueprintLayout, project: (SIMD2<Float>) -> CGPoint,
                            context: inout GraphicsContext) {
        for polygon in layout.roomPolygons where polygon.count >= 3 {
            var path = Path()
            path.move(to: project(polygon[0]))
            for p in polygon.dropFirst() { path.addLine(to: project(p)) }
            path.closeSubpath()
            context.stroke(path, with: .color(.black.opacity(0.25)), style: StrokeStyle(lineWidth: 0.6, dash: [2, 2]))
        }
        for label in layout.roomLabels {
            let point = project(label.position)
            context.draw(Text(label.name).font(.system(size: 12, weight: .semibold)), at: CGPoint(x: point.x, y: point.y - 6))
            context.draw(Text(label.areaLabel).font(.system(size: 10)).foregroundStyle(.secondary),
                         at: CGPoint(x: point.x, y: point.y + 8))
        }
    }

    private func drawDimensions(_ layout: BlueprintLayout, project: (SIMD2<Float>) -> CGPoint,
                                 context: inout GraphicsContext) {
        for dim in layout.dimensions {
            var ext1 = Path(); ext1.move(to: project(dim.extensionA.a)); ext1.addLine(to: project(dim.extensionA.b))
            var ext2 = Path(); ext2.move(to: project(dim.extensionB.a)); ext2.addLine(to: project(dim.extensionB.b))
            context.stroke(ext1, with: .color(.black.opacity(0.7)), lineWidth: 0.5)
            context.stroke(ext2, with: .color(.black.opacity(0.7)), lineWidth: 0.5)

            var dimLine = Path(); dimLine.move(to: project(dim.a)); dimLine.addLine(to: project(dim.b))
            context.stroke(dimLine, with: .color(.black.opacity(0.7)), lineWidth: 0.5)

            let mid = project(dim.midpoint)
            context.drawLayer { ctx in
                ctx.translateBy(x: mid.x, y: mid.y)
                ctx.rotate(by: .radians(Double(dim.angle)))
                ctx.draw(Text(dim.label).font(.system(size: 9)), at: .zero)
            }
        }
    }

    private func drawScaleBarAndNorth(scale: CGFloat, size: CGSize, context: inout GraphicsContext) {
        // Scale bar: a 10 ft reference segment in the bottom-left corner.
        let barLengthMeters: CGFloat = 3.048 // 10 ft
        let barLength = barLengthMeters * scale
        let origin = CGPoint(x: 16, y: size.height - 40)
        var bar = Path()
        bar.move(to: origin)
        bar.addLine(to: CGPoint(x: origin.x + barLength, y: origin.y))
        context.stroke(bar, with: .color(.black), lineWidth: 1.5)
        context.draw(Text("10'-0\"").font(.system(size: 9)), at: CGPoint(x: origin.x + barLength / 2, y: origin.y - 10))

        // Plan-north arrow (not calibrated to true/magnetic north -- see
        // README/docs; this is the conventional fallback architectural
        // drawings use when true north hasn't been established).
        let arrowOrigin = CGPoint(x: size.width - 28, y: size.height - 50)
        var arrow = Path()
        arrow.move(to: arrowOrigin)
        arrow.addLine(to: CGPoint(x: arrowOrigin.x, y: arrowOrigin.y - 24))
        arrow.move(to: CGPoint(x: arrowOrigin.x - 5, y: arrowOrigin.y - 16))
        arrow.addLine(to: CGPoint(x: arrowOrigin.x, y: arrowOrigin.y - 24))
        arrow.addLine(to: CGPoint(x: arrowOrigin.x + 5, y: arrowOrigin.y - 16))
        context.stroke(arrow, with: .color(.black), lineWidth: 1.2)
        context.draw(Text("N").font(.system(size: 10, weight: .bold)),
                     at: CGPoint(x: arrowOrigin.x, y: arrowOrigin.y + 8))
    }

    private func drawTitleBlock(size: CGSize, context: inout GraphicsContext) {
        let blockRect = CGRect(x: 0, y: size.height - 24, width: size.width, height: 24)
        context.fill(Path(blockRect), with: .color(.white.opacity(0.85)))
        context.draw(Text(floorPlan.name).font(.system(size: 10, weight: .semibold)),
                     at: CGPoint(x: size.width / 2, y: size.height - 12))
    }
}
