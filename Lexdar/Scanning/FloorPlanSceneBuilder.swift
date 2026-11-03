import Foundation
import SceneKit
import UIKit
import simd

/// Builds a live 3D preview of a `FloorPlan` — walls extruded to their real
/// height/thickness, floors filled per room polygon, doors/windows shown as
/// gaps — so the hand-drawn (or LiDAR-generated) 2D plan in
/// `BlueprintEditorView` can be flipped to 3D instantly, in the same
/// screen, the way you'd expect from drawing a wall and immediately seeing
/// it standing up. Independent of `RoomSceneBuilder` (which works from a
/// RoomPlan `CapturedRoom` + `RenovationPlan` for the furnishing workflow);
/// this one only ever needs a `FloorPlan`.
enum FloorPlanSceneBuilder {
    static func build(from plan: FloorPlan) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        for room in plan.rooms where room.polygon.count >= 3 {
            root.addChildNode(floorNode(for: room))
        }
        for wall in plan.walls {
            root.addChildNode(wallNode(for: wall, openings: plan.openings(on: wall.id)))
        }

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.name = "ambientLight"
        root.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.castsShadow = true
        sun.name = "sunLight"
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        root.addChildNode(sun)

        applyDaytime(true, to: scene)
        return scene
    }

    /// Toggles the day/night lighting look in place, without rebuilding
    /// the geometry — called from the editor's day/night button.
    static func applyDaytime(_ isDay: Bool, to scene: SCNScene) {
        guard let ambient = scene.rootNode.childNode(withName: "ambientLight", recursively: false),
              let sun = scene.rootNode.childNode(withName: "sunLight", recursively: false) else { return }
        if isDay {
            ambient.light?.intensity = 500
            ambient.light?.color = UIColor.white
            sun.light?.intensity = 1000
            sun.light?.color = UIColor(white: 1.0, alpha: 1.0)
            scene.background.contents = UIColor(red: 0.75, green: 0.85, blue: 0.95, alpha: 1)
        } else {
            ambient.light?.intensity = 120
            ambient.light?.color = UIColor(red: 0.55, green: 0.6, blue: 0.85, alpha: 1)
            sun.light?.intensity = 180
            sun.light?.color = UIColor(red: 0.6, green: 0.65, blue: 0.9, alpha: 1)
            scene.background.contents = UIColor(red: 0.04, green: 0.04, blue: 0.1, alpha: 1)
        }
    }

    private static func floorNode(for room: FloorPlanRoom) -> SCNNode {
        let path = UIBezierPath()
        let first = room.polygon[0]
        path.move(to: CGPoint(x: CGFloat(first.x), y: CGFloat(-first.y)))
        for p in room.polygon.dropFirst() {
            path.addLine(to: CGPoint(x: CGFloat(p.x), y: CGFloat(-p.y)))
        }
        path.close()

        let shape = SCNShape(path: path, extrusionDepth: 0.03)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.82, alpha: 1)
        shape.materials = [material]

        let node = SCNNode(geometry: shape)
        node.name = "floor:\(room.id.uuidString)"
        // SCNShape extrudes along +Z from the 2D path's XY plane; rotate it
        // flat so it lies on the ground (world XZ), matching the walls'
        // coordinate convention (plan x,y -> world x,z).
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        return node
    }

    private static func wallNode(for wall: FloorPlanWall, openings: [FloorPlanOpening]) -> SCNNode {
        let container = SCNNode()
        container.name = "wall:\(wall.id.uuidString)"

        // Simple approach (matches RoomSceneBuilder's style): draw the wall
        // as solid segments between openings rather than a boolean cut, so
        // there's no dependency on CSG support. For N openings sorted along
        // the wall, this yields N+1 solid segments (minus zero-length ones).
        let sorted = openings.sorted { $0.distanceFromWallStart < $1.distanceFromWallStart }
        var cursor: Float = 0
        var segments: [(Float, Float)] = []
        for opening in sorted {
            let openStart = opening.distanceFromWallStart - opening.width / 2
            if openStart > cursor { segments.append((cursor, openStart)) }
            cursor = max(cursor, opening.distanceFromWallStart + opening.width / 2)
        }
        if cursor < wall.lengthMeters { segments.append((cursor, wall.lengthMeters)) }
        if segments.isEmpty { segments.append((0, wall.lengthMeters)) }

        for (segStart, segEnd) in segments where segEnd - segStart > 0.02 {
            let length = segEnd - segStart
            let midDistance = (segStart + segEnd) / 2
            let geometry = SCNBox(width: CGFloat(length), height: CGFloat(wall.height),
                                   length: CGFloat(max(wall.thickness, 0.05)), chamferRadius: 0)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor(white: 0.93, alpha: 1)
            geometry.materials = [material]

            let node = SCNNode(geometry: geometry)
            let midPoint = wall.point(atDistance: midDistance)
            node.position = SCNVector3(midPoint.x, wall.height / 2, midPoint.y)
            let angle = atan2(wall.direction.y, wall.direction.x)
            // World +Z corresponds to plan +y; a wall's local +X (box width)
            // should align with its plan-space direction, achieved by
            // rotating about world Y by -angle (SceneKit's Y-rotation
            // convention measured from +X toward -Z, opposite of plan
            // space's +X toward +Y).
            node.eulerAngles = SCNVector3(0, -angle, 0)
            container.addChildNode(node)
        }

        // Door/window tint markers so openings read clearly even without a
        // true cut-out — a thin colored box in the gap at floor-to-lintel
        // height, matching RoomSceneBuilder's opening color convention.
        for opening in sorted {
            let color: UIColor = opening.kind == .door ? .systemBlue : (opening.kind == .window ? .systemCyan : .systemOrange)
            let geometry = SCNBox(width: CGFloat(opening.width), height: CGFloat(wall.height * 0.6),
                                   length: CGFloat(max(wall.thickness, 0.05) * 1.1), chamferRadius: 0)
            let material = SCNMaterial()
            material.diffuse.contents = color.withAlphaComponent(0.4)
            material.transparency = 0.6
            geometry.materials = [material]

            let node = SCNNode(geometry: geometry)
            let point = wall.point(atDistance: opening.distanceFromWallStart)
            node.position = SCNVector3(point.x, wall.height * 0.35, point.y)
            let angle = atan2(wall.direction.y, wall.direction.x)
            node.eulerAngles = SCNVector3(0, -angle, 0)
            container.addChildNode(node)
        }

        return container
    }
}
