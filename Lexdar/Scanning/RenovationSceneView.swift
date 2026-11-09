import SwiftUI
import SceneKit

#if canImport(RoomPlan)
import RoomPlan

/// Editing modes for the 3D renovation view's single tap gesture. The
/// toolbar above the scene (in `RenovationEditorView`) switches this.
enum RenovationTool: String, CaseIterable, Identifiable {
    case inspect        // orbit camera, tap to select a placed item
    case removeWalls    // tap a wall to toggle it removed/restored
    case paintFloor     // tap a floor to apply the selected flooring swatch
    case paintWall      // tap a wall to apply the selected wall-finish swatch
    case place          // tap anywhere on a floor to drop the selected catalog item

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inspect: return "Select"
        case .removeWalls: return "Remove Walls"
        case .paintFloor: return "Floor Material"
        case .paintWall: return "Wall Finish"
        case .place: return "Place Item"
        }
    }

    var symbolName: String {
        switch self {
        case .inspect: return "hand.point.up.left.fill"
        case .removeWalls: return "hammer.fill"
        case .paintFloor: return "square.grid.3x3.fill"
        case .paintWall: return "paintbrush.fill"
        case .place: return "plus.circle.fill"
        }
    }
}

/// Interactive 3D view of a scan + renovation plan: orbit/zoom by default
/// (SceneKit's built-in camera control), plus task-specific single-tap
/// behaviors driven by `tool`, and drag/pinch/rotate manipulation of the
/// currently selected placed item.
struct RenovationSceneView: UIViewRepresentable {
    let room: CapturedRoom
    @Binding var plan: RenovationPlan
    @Binding var tool: RenovationTool
    /// Catalog item id used by `.paintFloor` / `.paintWall` / `.place`.
    @Binding var activeCatalogItemID: String?
    @Binding var selectedPlacedItemID: UUID?

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .systemBackground
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = false

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(4, 4, 4)
        camera.look(at: SCNVector3(0, 0, 0))
        view.pointOfView = camera

        context.coordinator.view = view
        context.coordinator.rebuildScene(room: room, plan: plan)

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
        context.coordinator.parent = self
        if context.coordinator.lastPlanUpdatedAt != plan.updatedAt {
            context.coordinator.rebuildScene(room: room, plan: plan)
        }
        uiView.allowsCameraControl = (selectedPlacedItemID == nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: RenovationSceneView
        weak var view: SCNView?
        var lastPlanUpdatedAt: Date = .distantPast
        private var dragStartPosition: SCNVector3?
        private var dragStartTouch: CGPoint = .zero
        private var pinchStartScale: Float = 1
        private var rotateStartAngle: Float = 0

        init(parent: RenovationSceneView) {
            self.parent = parent
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        func rebuildScene(room: CapturedRoom, plan: RenovationPlan) {
            guard let view else { return }
            let pov = view.pointOfView
            view.scene = RoomSceneBuilder.build(room: room, plan: plan)
            view.pointOfView = pov
            lastPlanUpdatedAt = plan.updatedAt
        }

        private func selectedNode() -> SCNNode? {
            guard let id = parent.selectedPlacedItemID, let view else { return nil }
            return view.scene?.rootNode.childNode(withName: "placed:\(id.uuidString)", recursively: true)
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
                if let hit = hits.first(where: { $0.node.name?.hasPrefix("wall:") == true }) {
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
                if let hit = hits.first(where: { $0.node.name?.hasPrefix("wall:") == true }) {
                    let idString = String(hit.node.name!.dropFirst("wall:".count))
                    if let id = UUID(uuidString: idString) {
                        parent.plan.setMaterial(surfaceID: id, catalogItemID: itemID)
                    }
                }

            case .place:
                guard let itemID = parent.activeCatalogItemID else { return }
                if let hit = hits.first(where: { $0.node.name?.hasPrefix("floor:") == true }) {
                    let world = hit.worldCoordinates
                    let placed = parent.plan.addItem(itemID, at: SIMD3<Float>(world.x, world.y + 0.01, world.z))
                    parent.selectedPlacedItemID = placed.id
                    parent.tool = .inspect
                }
            }
        }

        // MARK: - Drag selected item across the floor plane

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard parent.tool == .inspect, let node = selectedNode(), let view else { return }
            let point = gesture.location(in: view)

            switch gesture.state {
            case .began:
                dragStartPosition = node.position
                dragStartTouch = point
            case .changed:
                guard let start = dragStartPosition else { return }
                // Project screen delta onto the floor (world Y plane) using
                // the camera's unprojection at two depths — simple and good
                // enough for a top-down-ish orbit camera.
                let dx = point.x - dragStartTouch.x
                let dy = point.y - dragStartTouch.y
                let sensitivity: Float = 0.005
                node.position = SCNVector3(start.x + Float(dx) * sensitivity,
                                            start.y,
                                            start.z + Float(dy) * sensitivity)
            case .ended, .cancelled:
                if let id = parent.selectedPlacedItemID {
                    let finalPos = SIMD3<Float>(node.position.x, node.position.y, node.position.z)
                    parent.plan.updateItem(id) { $0.position = finalPos }
                }
                dragStartPosition = nil
            default: break
            }
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
