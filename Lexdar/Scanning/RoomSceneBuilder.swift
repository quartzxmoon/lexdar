import Foundation
import SceneKit
import simd

#if canImport(RoomPlan)
import RoomPlan

/// Builds an editable SceneKit scene from a RoomPlan `CapturedRoom`, applying
/// a `RenovationPlan`'s wall removals, material swaps, hidden-object list,
/// and placed catalog items. Node naming convention used for hit-testing in
/// `RenovationSceneView`:
///   "wall:<uuid>"    "floor:<uuid>"    "object:<uuid>"    "placed:<uuid>"
enum RoomSceneBuilder {
    static func build(room: CapturedRoom, plan: RenovationPlan) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        for floor in room.floors {
            root.addChildNode(floorNode(for: floor, plan: plan))
        }
        for wall in room.walls where !plan.removedWallIDs.contains(wall.identifier) {
            root.addChildNode(wallNode(for: wall, plan: plan))
        }
        for door in room.doors {
            root.addChildNode(openingNode(for: door, color: .systemBlue, prefix: "door"))
        }
        for window in room.windows {
            root.addChildNode(openingNode(for: window, color: .systemCyan, prefix: "window"))
        }
        for object in room.objects where !plan.hiddenObjectIDs.contains(object.identifier) {
            root.addChildNode(capturedObjectNode(for: object))
        }
        for item in plan.placedItems {
            if let node = placedItemNode(for: item) {
                root.addChildNode(node)
            }
        }

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        root.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.light?.castsShadow = true
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        root.addChildNode(sun)

        return scene
    }

    // MARK: - Surfaces

    private static func floorNode(for floor: CapturedRoom.Surface, plan: RenovationPlan) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(floor.dimensions.x), height: 0.03,
                               length: CGFloat(floor.dimensions.z), chamferRadius: 0)
        let material = SCNMaterial()
        if let override = plan.material(for: floor.identifier) {
            material.diffuse.contents = UIColor(override.color)
        } else {
            material.diffuse.contents = UIColor(white: 0.85, alpha: 1)
        }
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = "floor:\(floor.identifier.uuidString)"
        node.simdTransform = floor.transform
        return node
    }

    private static func wallNode(for wall: CapturedRoom.Surface, plan: RenovationPlan) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(wall.dimensions.x), height: CGFloat(wall.dimensions.y),
                               length: CGFloat(max(wall.dimensions.z, 0.08)), chamferRadius: 0)
        let material = SCNMaterial()
        if let override = plan.material(for: wall.identifier) {
            material.diffuse.contents = UIColor(override.color)
        } else {
            material.diffuse.contents = UIColor(white: 0.93, alpha: 1)
        }
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = "wall:\(wall.identifier.uuidString)"
        node.simdTransform = wall.transform
        return node
    }

    private static func openingNode(for surface: CapturedRoom.Surface, color: UIColor, prefix: String) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(surface.dimensions.x), height: CGFloat(surface.dimensions.y),
                               length: CGFloat(max(surface.dimensions.z, 0.04)), chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = color.withAlphaComponent(0.55)
        material.transparency = 0.75
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = "\(prefix):\(surface.identifier.uuidString)"
        node.simdTransform = surface.transform
        return node
    }

    /// Furniture/objects RoomPlan detected during the scan itself — shown as
    /// translucent "ghosts" of what's currently there so the user can judge
    /// scale against the real room, without them being mistaken for the
    /// catalog items they're choosing for the renovation.
    private static func capturedObjectNode(for object: CapturedRoom.Object) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(object.dimensions.x), height: CGFloat(object.dimensions.y),
                               length: CGFloat(object.dimensions.z), chamferRadius: 0.01)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemGray.withAlphaComponent(0.35)
        material.transparency = 0.5
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = "object:\(object.identifier.uuidString)"
        node.simdTransform = object.transform
        return node
    }

    // MARK: - Placed catalog items

    static func placedItemNode(for item: PlacedItem) -> SCNNode? {
        guard let catalogItem = item.catalogItem else { return nil }
        let geometry = primitiveGeometry(for: catalogItem)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(catalogItem.color)
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.name = "placed:\(item.id.uuidString)"
        node.position = SCNVector3(item.position.x, item.position.y, item.position.z)
        node.scale = SCNVector3(item.scale, item.scale, item.scale)

        let yaw = simd_quatf(angle: item.rotationY, axis: SIMD3<Float>(0, 1, 0))
        if catalogItem.primitive == .plane {
            // SCNPlane is authored on the XY plane facing +Z by default;
            // tip it flat (-90° about X) so rugs/pool footprints/etc. lie
            // on the ground, then apply the item's facing rotation.
            let layFlat = simd_quatf(angle: -Float.pi / 2, axis: SIMD3<Float>(1, 0, 0))
            node.simdOrientation = yaw * layFlat
        } else {
            node.simdOrientation = yaw
        }
        return node
    }

    static func primitiveGeometry(for item: CatalogItem) -> SCNGeometry {
        let d = item.dimensions
        switch item.primitive {
        case .box:
            return SCNBox(width: CGFloat(d.x), height: CGFloat(d.y), length: CGFloat(d.z), chamferRadius: 0)
        case .roundedBox:
            return SCNBox(width: CGFloat(d.x), height: CGFloat(d.y), length: CGFloat(d.z),
                           chamferRadius: CGFloat(min(d.x, d.y, d.z)) * 0.08)
        case .cylinder:
            return SCNCylinder(radius: CGFloat(max(d.x, d.z)) / 2, height: CGFloat(d.y))
        case .sphere:
            return SCNSphere(radius: CGFloat(max(d.x, d.y, d.z)) / 2)
        case .plane:
            let plane = SCNPlane(width: CGFloat(d.x), height: CGFloat(d.z))
            plane.cornerRadius = 0
            // Planes are authored flat on XZ (floor/wall swatches, rugs);
            // rotate -90° about X so SceneKit's XY plane lies on the floor.
            return plane
        }
    }
}
#endif
