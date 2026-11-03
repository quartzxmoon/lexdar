import SwiftUI

/// Renders the formal dimensioned blueprint to a PNG for quick sharing
/// (messages, email, mark-up apps) - the raster counterpart to the vector PDF.
struct BlueprintPNGExportView: View {
    let floorPlan: FloorPlan

    @State private var pngURL: URL?
    @State private var preview: UIImage?
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let preview, let pngURL {
                    VStack(spacing: 12) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .border(Color.secondary.opacity(0.3))
                        Text(pngURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if failed {
                    Text("Couldn't render the PNG.").foregroundStyle(.secondary)
                } else {
                    ProgressView("Rendering PNG…")
                }
            }
            .navigationTitle("PNG Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if let pngURL {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: pngURL) { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
            .task { render() }
        }
    }

    @MainActor
    private func render() {
        let content = BlueprintView(floorPlan: floorPlan)
            .frame(width: 1600, height: 1200)
            .background(Color.white)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else {
            failed = true
            return
        }
        let safeName = floorPlan.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).png")
        do {
            try data.write(to: url, options: .atomic)
            preview = image
            pngURL = url
        } catch {
            failed = true
        }
    }
}
