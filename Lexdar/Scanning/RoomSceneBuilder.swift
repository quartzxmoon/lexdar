import Foundation
import SceneKit
import simd

#if canImport(RoomPlan)
import RoomPlan

/// Builds an editable SceneKit scene from a RoomPlan `CapturedRoom`, applying
/// a `RenovationPlan`'s wall removals, material swaps, hidden-object list,
/// and placed catalog items. Node naming convention used for hit-testing in
/// `RenovationSceneView`:
///   "wall:<uuid>"    "newwall:<uuid>"    "floor:<uuid>"    "object:<uuid>"    "placed:<uuid>"
enum RoomSceneBuilder {
    static func build(room: CapturedRoom, plan: RenovationPlan) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        for floor in room.floors {
            root.addChildNode(floorNode(for: floor, plan: plan))
        }
        if room.floors.isEmpty {
            root.addChildNode(syntheticFloorNode(for: bounds(of: room), plan: plan))
        }
        for wall in room.walls where !plan.removedWallIDs.contains(wall.identifier) {
            root.addChildNode(wallNode(for: wall, plan: plan))
        }
        for added in plan.newWalls where added.length > 0.02 {
            root.addChildNode(addedWallNode(for: added, plan: plan))
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

    // MARK: - Room extents

    struct RoomBounds {
        var minX: Float
        var maxX: Float
        var minZ: Float
        var maxZ: Float
        var floorY: Float
        var ceilingY: Float

        var center: SIMD3<Float> { SIMD3<Float>((minX + maxX) / 2, floorY, (minZ + maxZ) / 2) }
        var extent: Float { max(maxX - minX, maxZ - minZ) }
        var wallHeight: Float {
            let h = ceilingY - floorY
            return (h > 1.8 && h < 5) ? h : 2.4384
        }
    }

    /// Fixed id for the floor slab drawn when RoomPlan returned no floor
    /// surface, so floor materials can still be applied and remembered.
    static let syntheticFloorID = UUID(uuidString: "F100F100-F100-F100-F100-F100F100F100")!

    /// Extents of the scan, from the walls' end points; falls back to a
    /// small default box when the scan has no walls.
    static func bounds(of room: CapturedRoom) -> RoomBounds {
        var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude
        var floorY = Float.greatestFiniteMagnitude, ceilingY = -Float.greatestFiniteMagnitude
        for wall in room.walls {
            let t = wall.transform
            let center = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
            let axis = SIMD3<Float>(t.columns.0.x, t.columns.0.y, t.columns.0.z)
            let half = wall.dimensions.x / 2
            for sign: Float in [-1, 1] {
                let p = center + axis * (half * sign)
                minX = min(minX, p.x)
                maxX = max(maxX, p.x)
                minZ = min(minZ, p.z)
                maxZ = max(maxZ, p.z)
            }
            floorY = min(floorY, center.y - wall.dimensions.y / 2)
            ceilingY = max(ceilingY, center.y + wall.dimensions.y / 2)
        }
        if minX > maxX {
            return RoomBounds(minX: -2, maxX: 2, minZ: -2, maxZ: 2, floorY: 0, ceilingY: 2.4384)
        }
        return RoomBounds(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, floorY: floorY, ceilingY: ceilingY)
    }

    // MARK: - Surfaces

    private static func syntheticFloorNode(for bounds: RoomBounds, plan: RenovationPlan) -> SCNNode {
        let margin: Float = 0.3
        let geometry = SCNBox(width: CGFloat(bounds.maxX - bounds.minX + margin * 2), height: 0.03,
                               length: CGFloat(bounds.maxZ - bounds.minZ + margin * 2), chamferRadius: 0)
        let material = SCNMaterial()
        if let override = plan.material(for: syntheticFloorID) {
            material.diffuse.contents = UIColor(override.color)
        } else {
            material.diffuse.contents = UIColor(white: 0.85, alpha: 1)
        }
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = "floor:\(syntheticFloorID.uuidString)"
        node.position = SCNVector3(bounds.center.x, bounds.floorY - 0.015, bounds.center.z)
        return node
    }

    private static func addedWallNode(for wall: AddedWall, plan: RenovationPlan) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(wall.length), height: CGFloat(wall.height),
                               length: CGFloat(max(wall.thickness, 0.08)), chamferRadius: 0)
        let material = SCNMaterial()
        if let override = plan.material(for: wall.id) {
            material.diffuse.contents = UIColor(override.color)
        } else {
            material.diffuse.contents = UIColor(red: 0.86, green: 0.93, blue: 1, alpha: 1)
        }
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = "newwall:\(wall.id.uuidString)"
        node.position = SCNVector3((wall.start.x + wall.end.x) / 2,
                                    wall.baseY + wall.height / 2,
                                    (wall.start.y + wall.end.y) / 2)
        let angle = atan2(wall.end.y - wall.start.y, wall.end.x - wall.start.x)
        node.eulerAngles = SCNVector3(0, -angle, 0)
        return node
    }

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
