import SwiftUI
import SceneKit

#if canImport(RoomPlan)
import RoomPlan

/// Editing modes for the 3D renovation view. The toolbar above the scene
/// (in `RenovationEditorView`) switches this.
enum RenovationTool: String, CaseIterable, Identifiable {
    case inspect        // orbit camera, tap to select a placed item
    case removeWalls    // tap a wall to remove/restore it (tap a new wall to delete it)
    case drawWall       // drag on the floor with finger or Pencil to build a new wall
    case paintFloor     // tap a floor to apply the selected flooring swatch
    case paintWall      // tap a wall to apply the selected wall-finish swatch
    case place          // opens the catalog; the chosen item drops into the room

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inspect: return "Select"
        case .removeWalls: return "Remove Walls"
        case .drawWall: return "Draw Wall"
        case .paintFloor: return "Floor Material"
        case .paintWall: return "Wall Finish"
        case .place: return "Place Item"
        }
    }

    var symbolName: String {
        switch self {
        case .inspect: return "hand.point.up.left.fill"
        case .removeWalls: return "hammer.fill"
        case .drawWall: return "pencil.and.ruler.fill"
        case .paintFloor: return "square.grid.3x3.fill"
        case .paintWall: return "paintbrush.fill"
        case .place: return "plus.circle.fill"
        }
    }
}

/// Interactive 3D view of a scan + renovation plan: orbit/zoom by default
/// (SceneKit's built-in camera control), plus task-specific behaviors driven
/// by `tool`, drag/pinch/rotate manipulation of the selected placed item,
/// and a drawing mode that builds new walls on the floor.
struct RenovationSceneView: UIViewRepresentable {
    let room: CapturedRoom
    @Binding var plan: RenovationPlan
    @Binding var tool: RenovationTool
    /// Catalog item id used by `.paintFloor` / `.paintWall`.
    @Binding var activeCatalogItemID: String?
    @Binding var selectedPlacedItemID: UUID?
    /// Set by the editor when the user picks an item to furnish with; the
    /// scene drops it into the room, selects it, and clears this.
    @Binding var pendingPlacementItemID: String?
    /// Live readout (e.g. a wall's length) shown over the scene while drawing.
    @Binding var hudText: String?

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .systemBackground
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = false

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zFar = 200
        camera.camera?.zNear = 0.05
        view.pointOfView = camera

        context.coordinator.view = view
        context.coordinator.rebuildScene(room: room, plan: plan)
        context.coordinator.frameRoom()

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let rotate = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotate(_:)))
        pan.delegate = context.coordinator
        pinch.delegate = context.coordinator
        rotate.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(rotate)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.lastPlanUpdatedAt != plan.updatedAt {
            coordinator.rebuildScene(room: room, plan: plan)
        }
        uiView.allowsCameraControl = (selectedPlacedItemID == nil && tool != .drawWall)

        if tool != coordinator.lastTool {
            coordinator.lastTool = tool
            if tool == .drawWall { coordinator.setTopDownCamera() }
        }

        if let itemID = pendingPlacementItemID, !coordinator.isPlacing {
            coordinator.isPlacing = true
            Task { @MainActor in
                coordinator.placeAtViewCenter(itemID: itemID)
                coordinator.isPlacing = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: RenovationSceneView
        weak var view: SCNView?
        var lastPlanUpdatedAt: Date = .distantPast
        var lastTool: RenovationTool = .inspect
        var isPlacing = false
        let bounds: RoomSceneBuilder.RoomBounds

        private var dragStartPosition: SCNVector3?
        private var dragStartHit: SIMD3<Float>?
        private var pinchStartScale: Float = 1
        private var rotateStartAngle: Float = 0

        private var drawStart: SIMD2<Float>?
        private var drawEnd: SIMD2<Float>?
        private var previewNode: SCNNode?

        init(parent: RenovationSceneView) {
            self.parent = parent
            self.bounds = RoomSceneBuilder.bounds(of: parent.room)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        func rebuildScene(room: CapturedRoom, plan: RenovationPlan) {
            guard let view else { return }
            let pov = view.pointOfView
            let scene = RoomSceneBuilder.build(room: room, plan: plan)
            if let pov {
                pov.removeFromParentNode()
                scene.rootNode.addChildNode(pov)
            }
            view.scene = scene
            view.pointOfView = pov
            lastPlanUpdatedAt = plan.updatedAt
        }

        private func selectedNode() -> SCNNode? {
            guard let id = parent.selectedPlacedItemID, let view else { return nil }
            return view.scene?.rootNode.childNode(withName: "placed:\(id.uuidString)", recursively: true)
        }

        // MARK: - Camera

        /// Three-quarter view that frames the whole scan, whatever part of
        /// ARKit's world space it sits in.
        func frameRoom() {
            guard let camera = view?.pointOfView else { return }
            let c = bounds.center
            let d = max(bounds.extent, 3) * 0.9
            camera.position = SCNVector3(c.x + d, c.y + d, c.z + d)
            camera.look(at: SCNVector3(c.x, c.y + 0.8, c.z))
        }

        /// Straight-down view used while drawing walls, so the finger lands
        /// where the wall will.
        func setTopDownCamera() {
            guard let camera = view?.pointOfView else { return }
            let c = bounds.center
            let height = max(bounds.extent, 3) * 0.95 + 1
            camera.position = SCNVector3(c.x, bounds.floorY + height, c.z)
            camera.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        }

        // MARK: - Screen to floor

        /// Where the ray through `screenPoint` meets the horizontal plane at
        /// height `planeY`.
        func floorPoint(at screenPoint: CGPoint, planeY: Float) -> SIMD3<Float>? {
            guard let view else { return nil }
            let near = view.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 0))
            let far = view.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 1))
            let dy = far.y - near.y
            guard abs(dy) > 1e-5 else { return nil }
            let t = (planeY - near.y) / dy
            guard t > 0 else { return nil }
            return SIMD3<Float>(near.x + (far.x - near.x) * t, planeY, near.z + (far.z - near.z) * t)
        }

        // MARK: - Drop a catalog item into the room

        func placeAtViewCenter(itemID: String) {
            defer { parent.pendingPlacementItemID = nil }
            guard let view, let item = Catalog.item(id: itemID) else { return }

            let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            var spot = floorPoint(at: center, planeY: bounds.floorY) ?? bounds.center
            spot.x = min(max(spot.x, bounds.minX), bounds.maxX)
            spot.z = min(max(spot.z, bounds.minZ), bounds.maxZ)

            let d = item.dimensions
            let y: Float
            if item.primitive == .plane {
                y = bounds.floorY + 0.01
            } else if ["light.pendant", "light.chandelier", "light.recessed"].contains(where: { item.id.hasPrefix($0) }) {
                y = bounds.ceilingY - d.y / 2
            } else if item.id.hasPrefix("light.sconce") {
                y = bounds.floorY + 1.6
            } else {
                y = bounds.floorY + d.y / 2
            }

            let placed = parent.plan.addItem(item.id, at: SIMD3<Float>(spot.x, y, spot.z))
            parent.selectedPlacedItemID = placed.id
            parent.tool = .inspect
        }

        // MARK: - Tap

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view else { return }
            let point = gesture.location(in: view)
            let hits = view.hitTest(point, options: [.searchMode: NSNumber(value: 1)])

            switch parent.tool {
            case .inspect:
                if let hit = hits.first(where: { $0.node.name?.hasPrefix("placed:") == true }) {
                    let idString = String(hit.node.name!.dropFirst("placed:".count))
                    parent.selectedPlacedItemID = UUID(uuidString: idString)
                } else {
                    parent.selectedPlacedItemID = nil
                }

            case .removeWalls:
                if let hit = hits.first(where: { $0.node.name?.hasPrefix("newwall:") == true }) {
                    let idString = String(hit.node.name!.dropFirst("newwall:".count))
                    if let id = UUID(uuidString: idString) {
                        parent.plan.removeAddedWall(id)
                    }
                } else if let hit = hits.first(where: { $0.node.name?.hasPrefix("wall:") == true }) {
                    let idString = String(hit.node.name!.dropFirst("wall:".count))
                    if let id = UUID(uuidString: idString) {
                        parent.plan.toggleWallRemoved(id)
                    }
                }

            case .paintFloor:
                guard let itemID = parent.activeCatalogItemID else { return }
                if let hit = hits.first(where: { $0.node.name?.hasPrefix("floor:") == true }) {
                    let idString = String(hit.node.name!.dropFirst("floor:".count))
                    if let id = UUID(uuidString: idString) {
                        parent.plan.setMaterial(surfaceID: id, catalogItemID: itemID)
                    }
                }

            case .paintWall:
                guard let itemID = parent.activeCatalogItemID else { return }
                if let hit = hits.first(where: { $0.node.name?.hasPrefix("newwall:") == true || $0.node.name?.hasPrefix("wall:") == true }),
                   let name = hit.node.name {
                    let prefix = name.hasPrefix("newwall:") ? "newwall:" : "wall:"
                    if let id = UUID(uuidString: String(name.dropFirst(prefix.count))) {
                        parent.plan.setMaterial(surfaceID: id, catalogItemID: itemID)
                    }
                }

            case .drawWall, .place:
                break
            }
        }

        // MARK: - Pan: draw a wall, or drag the selected item

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            if parent.tool == .drawWall {
                handleDrawWall(gesture)
                return
            }
            guard parent.tool == .inspect, let node = selectedNode(), let view else { return }
            let point = gesture.location(in: view)

            switch gesture.state {
            case .began:
                dragStartPosition = node.position
                dragStartHit = floorPoint(at: point, planeY: node.position.y)
            case .changed:
                guard let start = dragStartPosition,
                      let firstHit = dragStartHit,
                      let hit = floorPoint(at: point, planeY: start.y) else { return }
                // The item follows the finger: move by how far the touch has
                // travelled across the floor, not by a fixed screen ratio.
                node.position = SCNVector3(start.x + (hit.x - firstHit.x),
                                            start.y,
                                            start.z + (hit.z - firstHit.z))
            case .ended, .cancelled:
                if let id = parent.selectedPlacedItemID {
                    let finalPos = SIMD3<Float>(node.position.x, node.position.y, node.position.z)
                    parent.plan.updateItem(id) { $0.position = finalPos }
                }
                dragStartPosition = nil
                dragStartHit = nil
            default: break
            }
        }

        // MARK: - Draw walls

        private func snapTargets() -> [SIMD2<Float>] {
            var points: [SIMD2<Float>] = []
            for wall in parent.room.walls where !parent.plan.removedWallIDs.contains(wall.identifier) {
                let t = wall.transform
                let c = SIMD2<Float>(t.columns.3.x, t.columns.3.z)
                let a = SIMD2<Float>(t.columns.0.x, t.columns.0.z)
                let half = wall.dimensions.x / 2
                points.append(c + a * half)
                points.append(c - a * half)
            }
            for wall in parent.plan.newWalls {
                points.append(wall.start)
                points.append(wall.end)
            }
            return points
        }

        /// Snaps to an existing wall end within 20 cm; otherwise to 15
        /// degree angles (when close) and a 5 cm grid.
        private func snapPoint(_ raw: SIMD2<Float>, from start: SIMD2<Float>?) -> SIMD2<Float> {
            var nearest: SIMD2<Float>?
            var nearestDistance: Float = 0.2
            for target in snapTargets() {
                let distance = simd_length(target - raw)
                if distance < nearestDistance {
                    nearest = target
                    nearestDistance = distance
                }
            }
            if let nearest { return nearest }

            var point = raw
            if let start {
                let delta = raw - start
                let length = simd_length(delta)
                if length > 0.001 {
                    let angle = atan2(delta.y, delta.x)
                    let step = Float.pi / 12
                    let rounded = (angle / step).rounded() * step
                    let snapped = abs(angle - rounded) < (5 * Float.pi / 180) ? rounded : angle
                    point = start + SIMD2<Float>(cos(snapped), sin(snapped)) * length
                }
            }
            let grid: Float = 0.05
            return SIMD2<Float>((point.x / grid).rounded() * grid, (point.y / grid).rounded() * grid)
        }

        private func handleDrawWall(_ gesture: UIPanGestureRecognizer) {
            guard let view else { return }
            let point = gesture.location(in: view)

            switch gesture.state {
            case .began:
                guard let hit = floorPoint(at: point, planeY: bounds.floorY) else { return }
                drawStart = snapPoint(SIMD2<Float>(hit.x, hit.z), from: nil)
                drawEnd = drawStart
            case .changed:
                guard let start = drawStart,
                      let hit = floorPoint(at: point, planeY: bounds.floorY) else { return }
                let end = snapPoint(SIMD2<Float>(hit.x, hit.z), from: start)
                drawEnd = end
                updatePreview(start: start, end: end)
                parent.hudText = Self.lengthText(simd_length(end - start))
            case .ended:
                if let start = drawStart, let end = drawEnd, simd_length(end - start) >= 0.2 {
                    parent.plan.addWall(AddedWall(start: start, end: end,
                                                  baseY: bounds.floorY, height: bounds.wallHeight))
                }
                finishDrawing()
            default:
                finishDrawing()
            }
        }

        private func updatePreview(start: SIMD2<Float>, end: SIMD2<Float>) {
            previewNode?.removeFromParentNode()
            let length = max(simd_length(end - start), 0.02)
            let geometry = SCNBox(width: CGFloat(length), height: CGFloat(bounds.wallHeight),
                                   length: 0.1143, chamferRadius: 0)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemOrange.withAlphaComponent(0.65)
            geometry.materials = [material]
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3((start.x + end.x) / 2,
                                        bounds.floorY + bounds.wallHeight / 2,
                                        (start.y + end.y) / 2)
            node.eulerAngles = SCNVector3(0, -atan2(end.y - start.y, end.x - start.x), 0)
            view?.scene?.rootNode.addChildNode(node)
            previewNode = node
        }

        private func finishDrawing() {
            previewNode?.removeFromParentNode()
            previewNode = nil
            drawStart = nil
            drawEnd = nil
            parent.hudText = nil
        }

        private static func lengthText(_ meters: Float) -> String {
            let totalInches = Double(meters) * 39.3701
            let feet = Int(totalInches / 12)
            let inches = totalInches - Double(feet * 12)
            return String(format: "%ld' %.0f\"   (%.2f m)", feet, inches, meters)
        }

        // MARK: - Pinch to scale selected item

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard parent.tool == .inspect, let node = selectedNode() else { return }
            switch gesture.state {
            case .began:
                pinchStartScale = node.scale.x
            case .changed:
                let newScale = max(0.2, min(4, pinchStartScale * Float(gesture.scale)))
                node.scale = SCNVector3(newScale, newScale, newScale)
            case .ended, .cancelled:
                if let id = parent.selectedPlacedItemID {
                    let finalScale = node.scale.x
                    parent.plan.updateItem(id) { $0.scale = finalScale }
                }
            default: break
            }
        }

        // MARK: - Rotate selected item about world Y

        @objc func handleRotate(_ gesture: UIRotationGestureRecognizer) {
            guard parent.tool == .inspect, let node = selectedNode() else { return }
            switch gesture.state {
            case .began:
                rotateStartAngle = node.eulerAngles.y
            case .changed:
                node.eulerAngles.y = rotateStartAngle + Float(gesture.rotation)
            case .ended, .cancelled:
                if let id = parent.selectedPlacedItemID {
                    let finalAngle = node.eulerAngles.y
                    parent.plan.updateItem(id) { $0.rotationY = finalAngle }
                }
            default: break
            }
        }
    }
}
#endif
