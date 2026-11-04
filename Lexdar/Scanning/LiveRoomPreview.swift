import SwiftUI
import SceneKit

#if canImport(RoomPlan)
import RoomPlan

/// A small slowly-spinning 3D dollhouse of the room as it is being scanned.
/// RoomPlan reports a fresh `CapturedRoom` every moment of the scan; each one
/// replaces the model, so walls, doors, windows, and objects appear in 3D as
/// they are found.
struct LiveRoomPreview: UIViewRepresentable {
    let room: CapturedRoom?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.cameraNode
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if let room { context.coordinator.update(with: room) }
    }

    @MainActor
    final class Coordinator {
        let scene = SCNScene()
        let cameraNode = SCNNode()
        private let spinner = SCNNode()
        private var content = SCNNode()

        init() {
            cameraNode.camera = SCNCamera()
            scene.rootNode.addChildNode(cameraNode)
            scene.rootNode.addChildNode(spinner)
            spinner.addChildNode(content)
            spinner.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 24)))
            cameraNode.position = SCNVector3(0, 2, 4)
            cameraNode.look(at: SCNVector3Zero)
        }

        func update(with room: CapturedRoom) {
            let built = RoomSceneBuilder.build(room: room, plan: RenovationPlan(scanID: UUID(), name: "live"))
            let newContent = SCNNode()
            for child in Array(built.rootNode.childNodes) {
                newContent.addChildNode(child)
            }
            let (minBound, maxBound) = newContent.boundingBox
            let center = SCNVector3((minBound.x + maxBound.x) / 2,
                                    (minBound.y + maxBound.y) / 2,
                                    (minBound.z + maxBound.z) / 2)
            newContent.position = SCNVector3(-center.x, -center.y, -center.z)

            content.removeFromParentNode()
            content = newContent
            spinner.addChildNode(content)

            let width = max(maxBound.x - minBound.x, maxBound.z - minBound.z)
            let radius = max(1, width / 2 + (maxBound.y - minBound.y) / 2)
            cameraNode.position = SCNVector3(0, radius * 1.1, radius * 1.9)
            cameraNode.look(at: SCNVector3Zero)
        }
    }
}
#endif
