import SwiftUI
import SceneKit

/// Live 3D preview of a `FloorPlan`, used inline inside
/// `BlueprintEditorView`'s 2D/3D toggle — orbit with one finger (SceneKit's
/// built-in camera control), day/night lighting toggle.
struct FloorPlan3DPreviewView: UIViewRepresentable {
    let floorPlan: FloorPlan
    @Binding var isDaytime: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = .black

        let camera = SCNNode()
        camera.camera = SCNCamera()
        let bounds = boundsCenter(of: floorPlan)
        camera.position = SCNVector3(bounds.x + 6, 6, bounds.y + 6)
        camera.look(at: SCNVector3(bounds.x, 1, bounds.y))
        view.pointOfView = camera

        context.coordinator.view = view
        context.coordinator.rebuild(floorPlan: floorPlan, isDaytime: isDaytime)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if context.coordinator.lastPlanUpdatedAt != floorPlan.updatedAt {
            context.coordinator.rebuild(floorPlan: floorPlan, isDaytime: isDaytime)
        } else if context.coordinator.lastIsDaytime != isDaytime {
            context.coordinator.setDaytime(isDaytime)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func boundsCenter(of plan: FloorPlan) -> SIMD2<Float> {
        guard !plan.walls.isEmpty else { return .zero }
        var sum = SIMD2<Float>.zero
        var count: Float = 0
        for wall in plan.walls {
            sum += wall.start; count += 1
            sum += wall.end; count += 1
        }
        return count > 0 ? sum / count : .zero
    }

    final class Coordinator {
        weak var view: SCNView?
        var lastPlanUpdatedAt: Date = .distantPast
        var lastIsDaytime = true

        func rebuild(floorPlan: FloorPlan, isDaytime: Bool) {
            guard let view else { return }
            let pov = view.pointOfView
            view.scene = FloorPlanSceneBuilder.build(from: floorPlan)
            view.pointOfView = pov
            lastPlanUpdatedAt = floorPlan.updatedAt
            setDaytime(isDaytime)
        }

        func setDaytime(_ isDaytime: Bool) {
            guard let scene = view?.scene else { return }
            FloorPlanSceneBuilder.applyDaytime(isDaytime, to: scene)
            lastIsDaytime = isDaytime
        }
    }
}
