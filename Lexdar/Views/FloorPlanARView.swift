import SwiftUI
import SceneKit

/// Extrudes the 2D floor plan into a 3D model, writes it as USDZ, and opens
/// it in AR Quick Look so the plan can be placed in the real room.
struct FloorPlanARView: View {
    let floorPlan: FloorPlan

    @State private var usdzURL: URL?
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let usdzURL {
                    USDZPreviewView(url: usdzURL)
                        .ignoresSafeArea()
                } else if failed {
                    Text("Couldn't build the 3D model for AR.").foregroundStyle(.secondary)
                } else {
                    ProgressView("Building 3D model…")
                }
            }
            .navigationTitle("View in AR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { build() }
        }
    }

    @MainActor
    private func build() {
        let scene = FloorPlanSceneBuilder.build(from: floorPlan)
        let safeName = floorPlan.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).usdz")
        try? FileManager.default.removeItem(at: url)
        if scene.write(to: url, options: nil, delegate: nil, progressHandler: nil) {
            usdzURL = url
        } else {
            failed = true
        }
    }
}
