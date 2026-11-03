import SwiftUI

/// 3D / BIM export formats generated from the plan geometry.
struct ModelExportView: View {
    let floorPlan: FloorPlan

    enum Format: String, CaseIterable, Identifiable {
        case ifc = "IFC (BIM)"
        case obj = "OBJ (mesh)"
        case ply = "PLY (mesh)"
        case xyz = "XYZ (vertices)"
        var id: String { rawValue }
        var ext: String {
            switch self {
            case .ifc: return "ifc"
            case .obj: return "obj"
            case .ply: return "ply"
            case .xyz: return "xyz"
            }
        }
        var detail: String {
            switch self {
            case .ifc: return "IFC4: walls with door/window voids, rooms as spaces. Opens in BIM viewers, Revit, ArchiCAD, FreeCAD."
            case .obj: return "Triangle mesh in meters, Y up. SketchUp, Blender, and most 3D tools import it."
            case .ply: return "ASCII triangle mesh, meters, Y up."
            case .xyz: return "Corner points of the modeled walls and floors. Not a sampled scan point cloud."
            }
        }
    }

    @State private var urls: [Format: URL] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Format.allCases) { format in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(format.rawValue).font(.headline)
                            Text(format.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let url = urls[format] {
                            ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                        } else {
                            ProgressView()
                        }
                    }
                }
            }
            .navigationTitle("3D / BIM Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { generate() }
        }
    }

    private func generate() {
        let base = floorPlan.name.replacingOccurrences(of: "/", with: "-")
        let mesh = FloorPlanMesh(plan: floorPlan)
        for format in Format.allCases {
            let text: String
            switch format {
            case .ifc: text = FloorPlanIFCExport.generate(from: floorPlan)
            case .obj: text = mesh.objText(name: base)
            case .ply: text = mesh.plyText()
            case .xyz: text = mesh.xyzText()
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(base).\(format.ext)")
            if (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil {
                urls[format] = url
            }
        }
    }
}
