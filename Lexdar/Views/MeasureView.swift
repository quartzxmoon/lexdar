import SwiftUI
import ARKit
import SceneKit

/// Point-to-point AR tape measure. Aim the crosshair at a surface, tap "Add
/// point", and the distance to the previous point is drawn in the room and
/// listed with a running total. On LiDAR devices the scene mesh makes the
/// raycast hit walls, floors, and furniture directly.
@MainActor
final class MeasureModel: ObservableObject {
    @Published private(set) var points: [SIMD3<Float>] = []
    @Published var message = "Move the device slowly so it can map the room."

    weak var arView: ARSCNView?
    private let overlay = SCNNode()

    var segmentLengths: [Float] {
        guard points.count > 1 else { return [] }
        return (1..<points.count).map { simd_distance(points[$0 - 1], points[$0]) }
    }

    var totalLength: Float { segmentLengths.reduce(0, +) }

    static func lengthText(_ meters: Float) -> String {
        let totalInches = Double(meters) * 39.3701
        let feet = Int(totalInches / 12)
        let inches = totalInches - Double(feet * 12)
        return String(format: "%.2f m  (%d' %.1f\")", meters, feet, inches)
    }

    func attach(_ view: ARSCNView) {
        arView = view
        overlay.removeFromParentNode()
        view.scene.rootNode.addChildNode(overlay)
    }

    func addPointAtCenter() {
        guard let view = arView else { return }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        for target in [ARRaycastQuery.Target.existingPlaneGeometry, .estimatedPlane] {
            guard let query = view.raycastQuery(from: center, allowing: target, alignment: .any),
                  let hit = view.session.raycast(query).first else { continue }
            let column = hit.worldTransform.columns.3
            points.append(SIMD3<Float>(column.x, column.y, column.z))
            message = "Tap Add point for the next corner, or Clear to start over."
            rebuildOverlay()
            return
        }
        message = "No surface found. Aim at a wall or floor and keep moving slowly."
    }

    func undo() {
        guard !points.isEmpty else { return }
        points.removeLast()
        rebuildOverlay()
    }

    func clear() {
        points.removeAll()
        rebuildOverlay()
    }

    private func rebuildOverlay() {
        overlay.childNodes.forEach { $0.removeFromParentNode() }
        for point in points {
            overlay.addChildNode(Self.dotNode(at: point))
        }
        guard points.count > 1 else { return }
        for index in 1..<points.count {
            let a = points[index - 1], b = points[index]
            overlay.addChildNode(Self.lineNode(from: a, to: b))
            overlay.addChildNode(Self.labelNode(text: Self.lengthText(simd_distance(a, b)), at: (a + b) / 2))
        }
    }

    private static func dotNode(at point: SIMD3<Float>) -> SCNNode {
        let sphere = SCNSphere(radius: 0.008)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemYellow
        sphere.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: sphere)
        node.simdPosition = point
        return node
    }

    private static func lineNode(from a: SIMD3<Float>, to b: SIMD3<Float>) -> SCNNode {
        let length = simd_distance(a, b)
        let cylinder = SCNCylinder(radius: 0.002, height: CGFloat(max(length, 0.001)))
        cylinder.firstMaterial?.diffuse.contents = UIColor.systemYellow
        cylinder.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: cylinder)
        node.simdPosition = (a + b) / 2
        let direction = simd_normalize(b - a)
        let up: SIMD3<Float> = abs(direction.y) > 0.99 ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0, 1, 0)
        node.simdLook(at: b, up: up, localFront: SIMD3<Float>(0, 1, 0))
        return node
    }

    private static func labelNode(text: String, at point: SIMD3<Float>) -> SCNNode {
        let geometry = SCNText(string: text, extrusionDepth: 0)
        geometry.font = UIFont.boldSystemFont(ofSize: 10)
        geometry.flatness = 0.1
        geometry.firstMaterial?.diffuse.contents = UIColor.white
        geometry.firstMaterial?.lightingModel = .constant
        geometry.firstMaterial?.readsFromDepthBuffer = false
        geometry.firstMaterial?.writesToDepthBuffer = false
        let node = SCNNode(geometry: geometry)
        let (minBound, maxBound) = geometry.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((maxBound.x + minBound.x) / 2, (maxBound.y + minBound.y) / 2, 0)
        node.scale = SCNVector3(0.0018, 0.0018, 0.0018)
        node.simdPosition = point + SIMD3<Float>(0, 0.02, 0)
        node.renderingOrder = 100
        node.constraints = [SCNBillboardConstraint()]
        return node
    }
}

private struct MeasureARView: UIViewRepresentable {
    let model: MeasureModel

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.automaticallyUpdatesLighting = true
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        view.session.run(configuration)
        model.attach(view)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
    }
}

struct MeasureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = MeasureModel()

    var body: some View {
        ZStack {
            if ARWorldTrackingConfiguration.isSupported {
                MeasureARView(model: model).ignoresSafeArea()
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 2)
            } else {
                Color.black.ignoresSafeArea()
                Text("AR measuring needs a device with ARKit support.")
                    .foregroundStyle(.white)
                    .padding()
            }
            VStack {
                HStack {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
                Spacer()
                readout
                controls
            }
        }
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.points.count > 1 {
                ForEach(Array(model.segmentLengths.enumerated()), id: \.offset) { index, length in
                    Text("\(index + 1).  \(MeasureModel.lengthText(length))")
                        .font(.callout.monospacedDigit())
                }
                Divider()
                Text("Total  \(MeasureModel.lengthText(model.totalLength))")
                    .font(.headline.monospacedDigit())
            } else {
                Text(model.message).font(.footnote)
            }
        }
        .padding(12)
        .frame(maxWidth: 420, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(model.points.isEmpty)
            Button { model.addPointAtCenter() } label: {
                Label("Add point", systemImage: "plus.circle.fill").font(.headline)
            }
            .buttonStyle(.borderedProminent)
            Button(role: .destructive) { model.clear() } label: { Label("Clear", systemImage: "trash") }
                .disabled(model.points.isEmpty)
        }
        .buttonStyle(.bordered)
        .padding()
    }
}
