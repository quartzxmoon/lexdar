import SwiftUI
import PencilKit

/// Freehand markup layer over the *finished* blueprint — distinct from
/// `BlueprintEditorView`'s precision wall-drafting tool. This is for
/// circling a water stain, writing "replace this outlet", or sketching a
/// rough renovation idea over the printed plan: the same "annotate your
/// plans with Apple Pencil" workflow RoomScan Pro offers, built on
/// PencilKit so it works identically with a finger or Apple Pencil.
///
/// The markup is a separate `PKDrawing` layer saved alongside the floor
/// plan (`ScanStore.markupURL`), not merged into the wall/door/room
/// geometry — turning it off never affects the underlying plan.
struct BlueprintAnnotationView: View {
    let floorPlan: FloorPlan
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()

    var body: some View {
        NavigationStack {
            ZStack {
                BlueprintView(floorPlan: floorPlan)
                    .allowsHitTesting(false)
                PencilCanvasRepresentable(canvasView: $canvasView, toolPicker: toolPicker)
            }
            .navigationTitle("Annotate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        canvasView.drawing = PKDrawing()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        let url = store.markupURL(for: floorPlan)
        guard let data = try? Data(contentsOf: url), let drawing = try? PKDrawing(data: data) else { return }
        canvasView.drawing = drawing
    }

    private func save() {
        let url = store.markupURL(for: floorPlan)
        try? canvasView.drawing.dataRepresentation().write(to: url)
    }
}

private struct PencilCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let toolPicker: PKToolPicker

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        // .anyInput, not .pencilOnly -- matches the rest of the app, where
        // touch and Apple Pencil both work for every tool with no special
        // casing needed.
        canvasView.drawingPolicy = .anyInput
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
