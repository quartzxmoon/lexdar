import SwiftUI
import simd

/// Tools available in the hand-drawn blueprint editor. Works identically
/// with a finger or Apple Pencil — SwiftUI's gestures don't distinguish
/// the two, so no Pencil-specific code is needed for precise placement.
enum BlueprintTool: String, CaseIterable, Identifiable {
    case wall, door, window, opening, room, select

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wall: return "Wall"
        case .door: return "Door"
        case .window: return "Window"
        case .opening: return "Opening"
        case .room: return "Room"
        case .select: return "Select"
        }
    }

    var symbolName: String {
        switch self {
        case .wall: return "line.diagonal"
        case .door: return "door.left.hand.open"
        case .window: return "windshield.front.and.wiper.intermittent"
        case .opening: return "rectangle.portrait.and.arrow.right"
        case .room: return "square.dashed"
        case .select: return "hand.point.up.left.fill"
        }
    }

    var openingKind: OpeningKind? {
        switch self {
        case .door: return .door
        case .window: return .window
        case .opening: return .opening
        default: return nil
        }
    }
}

/// Precision drafting tool for building a `FloorPlan` by hand: drag to
/// place grid- and angle-snapped walls (with an editable length confirm so
/// placement is exact, not just "close enough" to where you dragged), tap
/// a wall to drop a door/window/opening at that point, trace room
/// boundaries for area labels, and drag existing wall endpoints to
/// correct them. Works with touch or Apple Pencil.
struct BlueprintEditorView: View {
    @State var floorPlan: FloorPlan
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss

    @State private var tool: BlueprintTool = .wall
    @State private var is3D = false
    @State private var isDaytime = true
    @State private var baseScale: CGFloat = 40 // points per meter at zoom 1
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    @State private var wallDragStart: SIMD2<Float>?
    @State private var wallDragCurrent: SIMD2<Float>?
    @State private var pendingWall: (start: SIMD2<Float>, end: SIMD2<Float>)?
    @State private var showWallLengthConfirm = false
    @State private var wallLengthFeet = ""
    @State private var wallLengthInches = ""

    @State private var roomPoints: [SIMD2<Float>] = []
    @State private var showRoomNamePrompt = false
    @State private var pendingRoomName = "Room"

    @State private var showOpeningSheet = false
    @State private var pendingOpeningWallID: UUID?
    @State private var pendingOpeningDistance: Float = 0

    @State private var selectedWallID: UUID?
    @State private var draggingEndpoint: (wallID: UUID, isStart: Bool)?

    @State private var undoStack: [FloorPlan] = []
    @State private var redoStack: [FloorPlan] = []

    private let gridSpacing: Float = 0.3048 // 1 ft
    private let angleSnapDegrees: Float = 15

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .topTrailing) {
                    if is3D {
                        FloorPlan3DPreviewView(floorPlan: floorPlan, isDaytime: $isDaytime)
                            .ignoresSafeArea(edges: .bottom)
                        Button {
                            isDaytime.toggle()
                        } label: {
                            Image(systemName: isDaytime ? "sun.max.fill" : "moon.stars.fill")
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding()
                    } else {
                        Canvas { context, size in
                            draw(in: &context, size: size)
                        }
                        .background(Color(uiColor: .systemBackground))
                        .contentShape(Rectangle())
                        .gesture(panAndWallGesture(canvasSize: geo.size))
                        .simultaneousGesture(tapGesture(canvasSize: geo.size))
                        .simultaneousGesture(magnificationGesture())
                    }
                }
            }
            .navigationTitle(floorPlan.name)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if !is3D { toolBar }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        persist()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        persist()
                        is3D.toggle()
                    } label: {
                        Label(is3D ? "2D" : "3D", systemImage: is3D ? "square.grid.3x3" : "view.3d")
                    }
                    if !is3D {
                        Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                            .disabled(undoStack.isEmpty)
                        Button { redo() } label: { Image(systemName: "arrow.uturn.forward") }
                            .disabled(redoStack.isEmpty)
                    }
                }
            }
            .alert("Wall length", isPresented: $showWallLengthConfirm) {
                TextField("Feet", text: $wallLengthFeet).keyboardType(.numberPad)
                TextField("Inches", text: $wallLengthInches).keyboardType(.numberPad)
                Button("Add Wall") { confirmWall() }
                Button("Cancel", role: .cancel) { pendingWall = nil }
            } message: {
                Text("Confirm the exact length, snapped from your drag.")
            }
            .alert("Name this room", isPresented: $showRoomNamePrompt) {
                TextField("Room name", text: $pendingRoomName)
                Button("Save") { confirmRoom() }
                Button("Cancel", role: .cancel) { roomPoints = [] }
            }
            .sheet(isPresented: $showOpeningSheet) { openingSheet }
        }
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        HStack(spacing: 6) {
            ForEach(BlueprintTool.allCases) { t in
                Button {
                    tool = t
                    roomPoints = []
                    selectedWallID = nil
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: t.symbolName)
                        Text(t.label).font(.caption2)
                    }
                    .frame(minWidth: 56)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(tool == t ? Color.accentColor.opacity(0.25) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if tool == .select, let id = selectedWallID {
                Button(role: .destructive) {
                    pushUndo()
                    floorPlan.walls.removeAll { $0.id == id }
                    floorPlan.openings.removeAll { $0.wallID == id }
                    selectedWallID = nil
                    persist()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    // MARK: - Coordinate transforms

    private var effectiveScale: CGFloat { baseScale * zoom }

    private func planToScreen(_ p: SIMD2<Float>, canvasSize: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(p.x) * effectiveScale + canvasSize.width / 2 + panOffset.width,
                 y: CGFloat(p.y) * effectiveScale + canvasSize.height / 2 + panOffset.height)
    }

    private func screenToPlan(_ p: CGPoint, canvasSize: CGSize) -> SIMD2<Float> {
        SIMD2<Float>(Float((p.x - canvasSize.width / 2 - panOffset.width) / effectiveScale),
                     Float((p.y - canvasSize.height / 2 - panOffset.height) / effectiveScale))
    }

    // MARK: - Snapping

    private func snappedToGrid(_ p: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2(round(p.x / gridSpacing) * gridSpacing, round(p.y / gridSpacing) * gridSpacing)
    }

    /// Snaps to an existing wall endpoint first (so corners stay connected
    /// as you draw), falling back to the grid.
    private func snapPoint(_ p: SIMD2<Float>) -> SIMD2<Float> {
        let tolerance: Float = 12 / Float(effectiveScale)
        for wall in floorPlan.walls {
            if simd_length(wall.start - p) < tolerance { return wall.start }
            if simd_length(wall.end - p) < tolerance { return wall.end }
        }
        return snappedToGrid(p)
    }

    private func angleSnapped(start: SIMD2<Float>, end: SIMD2<Float>) -> SIMD2<Float> {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.001 else { return end }
        let angle = atan2(delta.y, delta.x)
        let snapRad = angleSnapDegrees * Float.pi / 180
        let snappedAngle = (snapRad > 0) ? (angle / snapRad).rounded() * snapRad : angle
        return start + SIMD2<Float>(cos(snappedAngle), sin(snappedAngle)) * length
    }

    // MARK: - Gestures

    private func panAndWallGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                switch tool {
                case .wall:
                    let start = wallDragStart ?? snapPoint(screenToPlan(value.startLocation, canvasSize: canvasSize))
                    wallDragStart = start
                    let raw = screenToPlan(value.location, canvasSize: canvasSize)
                    let angled = angleSnapped(start: start, end: raw)
                    wallDragCurrent = snapPoint(angled)
                case .select:
                    handleSelectDrag(value, canvasSize: canvasSize)
                default:
                    panOffset = CGSize(width: lastPanOffset.width + value.translation.width,
                                        height: lastPanOffset.height + value.translation.height)
                }
            }
            .onEnded { value in
                switch tool {
                case .wall:
                    defer { wallDragStart = nil; wallDragCurrent = nil }
                    guard let start = wallDragStart, let end = wallDragCurrent,
                          simd_length(end - start) > 0.05 else { return }
                    pendingWall = (start, end)
                    let (feet, inches) = Self.feetInches(fromMeters: simd_length(end - start))
                    wallLengthFeet = "\(feet)"
                    wallLengthInches = "\(inches)"
                    showWallLengthConfirm = true
                case .select:
                    if draggingEndpoint != nil { persist() }
                    draggingEndpoint = nil
                default:
                    lastPanOffset = panOffset
                }
            }
    }

    private func tapGesture(canvasSize: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let point = screenToPlan(value.location, canvasSize: canvasSize)
                switch tool {
                case .door, .window, .opening:
                    placeOpening(at: point)
                case .room:
                    addRoomPoint(point)
                case .select:
                    selectNearestWall(at: point)
                case .wall:
                    break
                }
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in zoom = max(0.25, min(8, lastZoom * value)) }
            .onEnded { _ in lastZoom = zoom }
    }

    private func handleSelectDrag(_ value: DragGesture.Value, canvasSize: CGSize) {
        if draggingEndpoint == nil {
            let startPlan = screenToPlan(value.startLocation, canvasSize: canvasSize)
            let tolerance: Float = 16 / Float(effectiveScale)
            for wall in floorPlan.walls {
                if simd_length(wall.start - startPlan) < tolerance { draggingEndpoint = (wall.id, true); break }
                if simd_length(wall.end - startPlan) < tolerance { draggingEndpoint = (wall.id, false); break }
            }
            if draggingEndpoint != nil { pushUndo() }
        }
        guard let dragging = draggingEndpoint,
              let wall = floorPlan.walls.first(where: { $0.id == dragging.wallID }) else { return }
        let oldPoint = dragging.isStart ? wall.start : wall.end
        let newPoint = snappedToGrid(screenToPlan(value.location, canvasSize: canvasSize))
        moveCoincidentEndpoints(from: oldPoint, to: newPoint)
        selectedWallID = dragging.wallID
    }

    private func moveCoincidentEndpoints(from oldPoint: SIMD2<Float>, to newPoint: SIMD2<Float>) {
        let tolerance: Float = 0.05
        for i in floorPlan.walls.indices {
            if simd_length(floorPlan.walls[i].start - oldPoint) < tolerance { floorPlan.walls[i].start = newPoint }
            if simd_length(floorPlan.walls[i].end - oldPoint) < tolerance { floorPlan.walls[i].end = newPoint }
        }
    }

    private func selectNearestWall(at point: SIMD2<Float>) {
        let tolerance: Float = 20 / Float(effectiveScale)
        guard let nearest = floorPlan.walls.min(by: { distance(point, to: $0) < distance(point, to: $1) }),
              distance(point, to: nearest) < tolerance else {
            selectedWallID = nil
            return
        }
        selectedWallID = nearest.id
    }

    // MARK: - Wall creation

    private func confirmWall() {
        defer { pendingWall = nil }
        guard let pending = pendingWall else { return }
        let feet = Float(wallLengthFeet) ?? 0
        let inches = Float(wallLengthInches) ?? 0
        let confirmedLength = feet * 0.3048 + inches * 0.0254
        let rawLength = simd_length(pending.end - pending.start)
        let direction = rawLength > 0.0001 ? (pending.end - pending.start) / rawLength : SIMD2<Float>(1, 0)
        let finalEnd = confirmedLength > 0 ? pending.start + direction * confirmedLength : pending.end
        pushUndo()
        floorPlan.walls.append(FloorPlanWall(start: pending.start, end: finalEnd))
        persist()
    }

    // MARK: - Openings

    private func placeOpening(at point: SIMD2<Float>) {
        let tolerance: Float = 20 / Float(effectiveScale)
        guard let nearest = floorPlan.walls.min(by: { distance(point, to: $0) < distance(point, to: $1) }),
              distance(point, to: nearest) < tolerance else { return }
        let toPoint = point - nearest.start
        let proj = simd_dot(toPoint, nearest.direction)
        pendingOpeningWallID = nearest.id
        pendingOpeningDistance = max(0, min(nearest.lengthMeters, proj))
        showOpeningSheet = true
    }

    @ViewBuilder
    private var openingSheet: some View {
        NavigationStack {
            List(FloorPlanOpening.standardWidths(for: tool.openingKind ?? .opening), id: \.self) { width in
                Button {
                    confirmOpening(width: width)
                } label: {
                    Text(Self.feetInchesLabel(meters: width))
                }
            }
            .navigationTitle("\((tool.openingKind ?? .opening).displayName) Width")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showOpeningSheet = false }
                }
            }
        }
    }

    private func confirmOpening(width: Float) {
        defer { showOpeningSheet = false }
        guard let wallID = pendingOpeningWallID else { return }
        pushUndo()
        floorPlan.openings.append(FloorPlanOpening(wallID: wallID, kind: tool.openingKind ?? .opening,
                                                     distanceFromWallStart: pendingOpeningDistance, width: width))
        persist()
    }

    // MARK: - Rooms

    private func addRoomPoint(_ point: SIMD2<Float>) {
        let snapRadius: Float = 16 / Float(effectiveScale)
        if roomPoints.count >= 3, let first = roomPoints.first, simd_length(point - first) < snapRadius {
            showRoomNamePrompt = true
            return
        }
        roomPoints.append(snappedToGrid(point))
    }

    private func confirmRoom() {
        defer { roomPoints = []; pendingRoomName = "Room" }
        guard roomPoints.count >= 3 else { return }
        pushUndo()
        floorPlan.rooms.append(FloorPlanRoom(name: pendingRoomName, polygon: roomPoints))
        persist()
    }

    // MARK: - Undo / redo / persistence

    private func pushUndo() {
        undoStack.append(floorPlan)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(floorPlan)
        floorPlan = previous
        persist()
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(floorPlan)
        floorPlan = next
        persist()
    }

    private func persist() {
        store.save(floorPlan)
    }

    // MARK: - Geometry helpers

    private func distance(_ point: SIMD2<Float>, to wall: FloorPlanWall) -> Float {
        let proj = max(0, min(wall.lengthMeters, simd_dot(point - wall.start, wall.direction)))
        let closest = wall.start + wall.direction * proj
        return simd_length(point - closest)
    }

    private static func feetInches(fromMeters meters: Float) -> (feet: Int, inches: Int) {
        let totalInches = meters * 39.3701
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
        return (feet, inches)
    }

    private static func feetInchesLabel(meters: Float) -> String {
        let (f, i) = feetInches(fromMeters: meters)
        return "\(f)'\(i)\""
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        drawGrid(in: &context, size: size)

        for room in floorPlan.rooms {
            drawRoom(room, in: &context, size: size)
        }
        for wall in floorPlan.walls {
            drawWall(wall, in: &context, size: size, highlighted: wall.id == selectedWallID)
        }
        for opening in floorPlan.openings {
            if let wall = floorPlan.walls.first(where: { $0.id == opening.wallID }) {
                drawOpening(opening, on: wall, in: &context, size: size)
            }
        }
        if let start = wallDragStart, let end = wallDragCurrent {
            drawPendingWall(start: start, end: end, in: &context, size: size)
        }
        if !roomPoints.isEmpty {
            drawPendingRoom(in: &context, size: size)
        }
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        let origin = screenToPlan(.zero, canvasSize: size)
        let farCorner = screenToPlan(CGPoint(x: size.width, y: size.height), canvasSize: size)
        let minX = Int(floor(Double(min(origin.x, farCorner.x) / gridSpacing))) - 1
        let maxX = Int(ceil(Double(max(origin.x, farCorner.x) / gridSpacing))) + 1
        let minY = Int(floor(Double(min(origin.y, farCorner.y) / gridSpacing))) - 1
        let maxY = Int(ceil(Double(max(origin.y, farCorner.y) / gridSpacing))) + 1

        var path = Path()
        for xi in minX...maxX {
            let x = Float(xi) * gridSpacing
            let a = planToScreen(SIMD2(x, Float(minY) * gridSpacing), canvasSize: size)
            let b = planToScreen(SIMD2(x, Float(maxY) * gridSpacing), canvasSize: size)
            path.move(to: a); path.addLine(to: b)
        }
        for yi in minY...maxY {
            let y = Float(yi) * gridSpacing
            let a = planToScreen(SIMD2(Float(minX) * gridSpacing, y), canvasSize: size)
            let b = planToScreen(SIMD2(Float(maxX) * gridSpacing, y), canvasSize: size)
            path.move(to: a); path.addLine(to: b)
        }
        context.stroke(path, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
    }

    private func drawWall(_ wall: FloorPlanWall, in context: inout GraphicsContext, size: CGSize, highlighted: Bool) {
        var path = Path()
        path.move(to: planToScreen(wall.start, canvasSize: size))
        path.addLine(to: planToScreen(wall.end, canvasSize: size))
        let width = max(2, CGFloat(wall.thickness) * effectiveScale)
        context.stroke(path, with: .color(highlighted ? .accentColor : .primary), lineWidth: width)
    }

    private func drawOpening(_ opening: FloorPlanOpening, on wall: FloorPlanWall, in context: inout GraphicsContext, size: CGSize) {
        let center = wall.point(atDistance: opening.distanceFromWallStart)
        let halfWidth = opening.width / 2
        let p1 = center - wall.direction * halfWidth
        let p2 = center + wall.direction * halfWidth
        let color: Color = opening.kind == .door ? .blue : (opening.kind == .window ? .cyan : .orange)

        var path = Path()
        path.move(to: planToScreen(p1, canvasSize: size))
        path.addLine(to: planToScreen(p2, canvasSize: size))
        let width = max(3, CGFloat(wall.thickness) * effectiveScale * 1.4)
        context.stroke(path, with: .color(color), lineWidth: width)

        if opening.kind == .door {
            // Simple door-swing indicator: a short perpendicular stroke from
            // the hinge point, standing in for a full quarter-circle arc in
            // this lightweight editor view (the formal BlueprintView draws
            // the real swing arc for the printed/exported blueprint).
            let hinge = p1
            let swingEnd = hinge + wall.normal * opening.width
            var swing = Path()
            swing.move(to: planToScreen(hinge, canvasSize: size))
            swing.addLine(to: planToScreen(swingEnd, canvasSize: size))
            context.stroke(swing, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    private func drawRoom(_ room: FloorPlanRoom, in context: inout GraphicsContext, size: CGSize) {
        guard room.polygon.count >= 3 else { return }
        var path = Path()
        path.move(to: planToScreen(room.polygon[0], canvasSize: size))
        for p in room.polygon.dropFirst() { path.addLine(to: planToScreen(p, canvasSize: size)) }
        path.closeSubpath()
        context.fill(path, with: .color(.accentColor.opacity(0.08)))
        context.stroke(path, with: .color(.accentColor.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))

        let centroid = planToScreen(room.centroid, canvasSize: size)
        let sqft = room.areaSquareMeters * 10.7639
        context.draw(Text("\(room.name)\n\(String(format: "%.0f", sqft)) sq ft")
            .font(.caption2).multilineTextAlignment(.center), at: centroid)
    }

    private func drawPendingWall(start: SIMD2<Float>, end: SIMD2<Float>, in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: planToScreen(start, canvasSize: size))
        path.addLine(to: planToScreen(end, canvasSize: size))
        context.stroke(path, with: .color(.accentColor), style: StrokeStyle(lineWidth: 4, dash: [6, 4]))
        let mid = planToScreen((start + end) / 2, canvasSize: size)
        context.draw(Text(Self.feetInchesLabel(meters: simd_length(end - start))).font(.caption2), at: mid)
    }

    private func drawPendingRoom(in context: inout GraphicsContext, size: CGSize) {
        guard roomPoints.count >= 1 else { return }
        var path = Path()
        path.move(to: planToScreen(roomPoints[0], canvasSize: size))
        for p in roomPoints.dropFirst() { path.addLine(to: planToScreen(p, canvasSize: size)) }
        context.stroke(path, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
        for p in roomPoints {
            let screen = planToScreen(p, canvasSize: size)
            context.fill(Path(ellipseIn: CGRect(x: screen.x - 3, y: screen.y - 3, width: 6, height: 6)),
                          with: .color(.accentColor))
        }
    }
}
