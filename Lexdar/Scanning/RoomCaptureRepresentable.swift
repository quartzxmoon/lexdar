import SwiftUI
#if canImport(RoomPlan)
import RoomPlan

/// Thin SwiftUI wrapper around RoomPlan's own `RoomCaptureView`, which
/// already renders the live AR camera feed with the in-progress mesh
/// overlay — no custom ARSCNView/rendering needed for the scan itself.
struct RoomCaptureRepresentable: UIViewRepresentable {
    let coordinator: RoomCaptureCoordinator

    func makeUIView(context: Context) -> RoomCaptureView {
        coordinator.captureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
#endif
