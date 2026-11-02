import SwiftUI

#if canImport(RoomPlan)
import RoomPlan

/// Top-down 2D floor plan rendered from a `CapturedRoom`: walls, doors,
/// windows, openings, with wall-length dimension labels, pinch-to-zoom and
/// drag-to-pan. When a `RenovationPlan` binding is supplied, walls can be
/// tapped to toggle "removed" (open-concept preview) and the view greys out
/// removed walls instead of drawing them solid.
struct FloorPlanView: View {
    let room: CapturedRoom
    /// Optional — when present, enables tap-to-remove-wall editing.
    @Binding var plan: RenovationPlan?
    var editable: Bool = false

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var unit: LengthUnit = .feetInches

    enum LengthUnit: String, CaseIterable, Identifiable {
        case feetInches = "ft/in"
        case meters = "m"
        var id: String { rawValue }
    }

    init(room: CapturedRoom, plan: Binding<RenovationPlan?> = .constant(nil), editable: Bool = false) {
        self.room = room
        self._plan = plan
        self.editable = editable
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                Canvas { context, size in
                    draw(in: &context, size: size)
                }
                .background(Color(uiColor: .systemBackground))
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in scale = max(0.3, min(6, lastScale * value)) }
                            .onEnded { _ in lastScale = scale },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(width: lastOffset.width + value.translation.width,
                                                 height: lastOffset.height + value.translation.height)
                            }
                            .onEnded { _ in lastOffset = offset }
                    )
                )
                .onTapGesture { location in
                    guard editable, plan != nil else { return }
                    handleTap(at: location, canvasSize: geo.size)
                }
            }

            HStack {
                Picker("Units", selection: $unit) {
                    ForEach(LengthUnit.allCases) { u in Text(u.rawValue).tag(u) }
                }
                .pickerStyle(.segmented)

                if editable {
                    Text("Tap a wall to remove/restore it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    // MARK: - Geometry

    private struct Segment {
        let a: CGPoint
        let b: CGPoint
        let id: UUID
        let kind: Kind
        enum Kind { case wall, door, window, opening }
    }

    private func allSegments() -> [Segment] {
        var segs: [Segment] = []
        for wall in room.walls {
            segs.append(segment(for: wall, kind: .wall))
        }
        for door in room.doors { segs.append(segment(for: door, kind: .door)) }
        for window in room.windows { segs.append(segment(for: window, kind: .window)) }
        for opening in room.openings { segs.append(segment(for: opening, kind: .opening)) }
        return segs
    }

    private func segment(for surface: CapturedRoom.Surface, kind: Segment.Kind) -> Segment {
        let t = surface.transform
        let center = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        let xAxis = SIMD3<Float>(t.columns.0.x, t.columns.0.y, t.columns.0.z)
        let halfWidth = surface.dimensions.x / 2
        let p1 = center - xAxis * halfWidth
        let p2 = center + xAxis * halfWidth
        return Segment(a: CGPoint(x: CGFloat(p1.x), y: CGFloat(p1.z)),
                        b: CGPoint(x: CGFloat(p2.x), y: CGFloat(p2.z)),
                        id: surface.identifier,
                        kind: kind)
    }

    private func bounds(of segments: [Segment]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for s in segments {
            minX = min(minX, min(s.a.x, s.b.x)); maxX = max(maxX, max(s.a.x, s.b.x))
            minY = min(minY, min(s.a.y, s.b.y)); maxY = max(maxY, max(s.a.y, s.b.y))
        }
        guard minX.isFinite, maxX.isFinite else { return .zero }
        return CGRect(x: minX, y: minY, width: max(maxX - minX, 0.01), height: max(maxY - minY, 0.01))
    }

    private func projection(canvasSize: CGSize, bounds: CGRect) -> (CGPoint) -> CGPoint {
        let margin: CGFloat = 40
        let availableW = canvasSize.width - margin * 2
        let availableH = canvasSize.height - margin * 2
        let fitScale = max(0.001, min(availableW / bounds.width, availableH / bounds.height))
        let finalScale = fitScale * scale
        return { p in
            CGPoint(x: (p.x - bounds.minX) * finalScale + margin + offset.width,
                    y: (p.y - bounds.minY) * finalScale + margin + offset.height)
        }
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let segments = allSegments()
        let bbox = bounds(of: segments)
        guard bbox.width > 0, bbox.height > 0 else { return }
        let project = projection(canvasSize: size, bounds: bbox)

        for seg in segments {
            let removed = plan?.removedWallIDs.contains(seg.id) ?? false
            var path = Path()
            path.move(to: project(seg.a))
            path.addLine(to: project(seg.b))

            let (color, width): (Color, CGFloat) = {
                if removed { return (.gray.opacity(0.3), 3) }
                switch seg.kind {
                case .wall: return (.primary, 6)
                case .door: return (.blue, 8)
                case .window: return (.cyan, 8)
                case .opening: return (.orange, 8)
                }
            }()

            if removed {
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, dash: [6, 4]))
            } else {
                context.stroke(path, with: .color(color), lineWidth: width)
            }

            if seg.kind == .wall && !removed {
                let mid = CGPoint(x: (seg.a.x + seg.b.x) / 2, y: (seg.a.y + seg.b.y) / 2)
                let lengthMeters = hypot(seg.b.x - seg.a.x, seg.b.y - seg.a.y)
                let label = formattedLength(CGFloat(lengthMeters))
                context.draw(Text(label).font(.caption2).foregroundStyle(.secondary), at: project(mid))
            }
        }
    }

    private func handleTap(at location: CGPoint, canvasSize: CGSize) {
        let segments = allSegments().filter { $0.kind == .wall }
        let bbox = bounds(of: allSegments())
        guard bbox.width > 0 else { return }
        let project = projection(canvasSize: canvasSize, bounds: bbox)

        var closest: (id: UUID, distance: CGFloat)?
        for seg in segments {
            let p1 = project(seg.a), p2 = project(seg.b)
            let d = distance(from: location, toSegmentFrom: p1, to: p2)
            if closest == nil || d < closest!.distance {
                closest = (seg.id, d)
            }
        }
        guard let closest, closest.distance < 24 else { return }
        plan?.toggleWallRemoved(closest.id)
    }

    private func distance(from point: CGPoint, toSegmentFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: point.x - a.x, y: point.y - a.y)
        let abLenSq = ab.x * ab.x + ab.y * ab.y
        guard abLenSq > 0 else { return hypot(ap.x, ap.y) }
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / abLenSq))
        let closest = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        return hypot(point.x - closest.x, point.y - closest.y)
    }

    private func formattedLength(_ meters: CGFloat) -> String {
        switch unit {
        case .meters:
            return String(format: "%.2fm", meters)
        case .feetInches:
            let totalInches = meters * 39.3701
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
            return "\(feet)'\(inches)\""
        }
    }
}
#endif
