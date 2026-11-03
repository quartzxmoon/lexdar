import SwiftUI
import simd

/// Exports a `FloorPlan` as a DXF file (AutoCAD R12 ASCII format) — the CAD
/// interchange format contractors, architects, and most professional
/// floor-plan/CAD tools actually import. Reuses `BlueprintLayout`, the same
/// geometry layer `BlueprintView` and the PDF exporter draw from, so the
/// DXF matches what's shown on screen and in the PDF.
///
/// Units are meters (1 drawing unit = 1 meter) — noted in a TEXT entity in
/// the drawing itself, since DXF R12 predates the `$INSUNITS` header
/// variable. Dimension lines are drawn as plain LINE + TEXT entities, not
/// true associative AutoCAD DIMENSION objects — readable and positioned
/// correctly in any CAD tool, but not "live" (won't recompute if you drag
/// a wall in the CAD tool itself).
enum BlueprintDXFExporter {
    static func generate(from plan: FloorPlan) -> String {
        let layout = BlueprintLayout.build(from: plan)
        var lines: [String] = []

        func emit(_ code: Int, _ value: String) {
            lines.append(String(code))
            lines.append(value)
        }
        func emitPoint(_ p: SIMD2<Float>, codeX: Int, codeY: Int) {
            emit(codeX, String(format: "%.4f", p.x))
            emit(codeY, String(format: "%.4f", p.y))
        }
        func line(_ a: SIMD2<Float>, _ b: SIMD2<Float>, layer: String) {
            emit(0, "LINE")
            emit(8, layer)
            emitPoint(a, codeX: 10, codeY: 20)
            emit(30, "0.0")
            emitPoint(b, codeX: 11, codeY: 21)
            emit(31, "0.0")
        }
        func text(_ value: String, at point: SIMD2<Float>, height: Float = 0.1,
                   rotationDegrees: Float = 0, layer: String = "TEXT") {
            emit(0, "TEXT")
            emit(8, layer)
            emitPoint(point, codeX: 10, codeY: 20)
            emit(30, "0.0")
            emit(40, String(format: "%.3f", height))
            emit(1, value)
            if rotationDegrees != 0 {
                emit(50, String(format: "%.2f", rotationDegrees))
            }
        }

        // HEADER
        emit(0, "SECTION")
        emit(2, "HEADER")
        emit(9, "$ACADVER")
        emit(1, "AC1009") // R12 -- the most broadly importable ASCII DXF version
        emit(0, "ENDSEC")

        // TABLES -- layers, so the drawing opens with walls/doors/windows/
        // rooms/dimensions already separated and independently toggleable,
        // the way a contractor would expect.
        emit(0, "SECTION")
        emit(2, "TABLES")
        emit(0, "TABLE")
        emit(2, "LAYER")
        emit(70, "7")
        let layerDefs: [(name: String, aciColor: Int)] = [
            ("WALLS", 7), ("DOORS", 5), ("WINDOWS", 4), ("OPENINGS", 30),
            ("ROOMS", 3), ("DIMENSIONS", 8), ("TEXT", 2),
        ]
        for layer in layerDefs {
            emit(0, "LAYER")
            emit(2, layer.name)
            emit(70, "0")
            emit(62, String(layer.aciColor))
            emit(6, "CONTINUOUS")
        }
        emit(0, "ENDTABLE")
        emit(0, "ENDSEC")

        // ENTITIES
        emit(0, "SECTION")
        emit(2, "ENTITIES")

        // Walls, drawn as real double lines (both faces + end caps), the
        // way architectural CAD walls are conventionally represented --
        // not a single centerline.
        for (wall, _) in layout.wallSegments {
            let halfThickness = wall.thickness / 2
            let offset = wall.normal * halfThickness
            line(wall.start + offset, wall.end + offset, layer: "WALLS")
            line(wall.start - offset, wall.end - offset, layer: "WALLS")
            line(wall.start + offset, wall.start - offset, layer: "WALLS")
            line(wall.end + offset, wall.end - offset, layer: "WALLS")
        }

        for door in layout.doors {
            line(door.panelLine.a, door.panelLine.b, layer: "DOORS")
            for extra in door.extraLines {
                line(extra.a, extra.b, layer: "DOORS")
            }
            if door.drawsArc {
                emit(0, "ARC")
                emit(8, "DOORS")
                emitPoint(door.arcCenter, codeX: 10, codeY: 20)
                emit(30, "0.0")
                emit(40, String(format: "%.4f", door.arcRadius))
                let startDeg = door.arcStartAngle * 180 / .pi
                let endDeg = door.arcEndAngle * 180 / .pi
                emit(50, String(format: "%.2f", min(startDeg, endDeg)))
                emit(51, String(format: "%.2f", max(startDeg, endDeg)))
            }
        }

        for window in layout.windows {
            for sill in window.sillLines {
                line(sill.a, sill.b, layer: "WINDOWS")
            }
        }

        for opening in layout.plainOpenings {
            line(opening.a, opening.b, layer: "OPENINGS")
        }

        for polygon in layout.roomPolygons where polygon.count >= 3 {
            for i in 0..<polygon.count {
                line(polygon[i], polygon[(i + 1) % polygon.count], layer: "ROOMS")
            }
        }
        for label in layout.roomLabels {
            text("\(label.name) - \(label.areaLabel)", at: label.position, layer: "TEXT")
        }

        for dim in layout.dimensions {
            line(dim.a, dim.b, layer: "DIMENSIONS")
            line(dim.extensionA.a, dim.extensionA.b, layer: "DIMENSIONS")
            line(dim.extensionB.a, dim.extensionB.b, layer: "DIMENSIONS")
            text(dim.label, at: dim.midpoint, height: 0.08,
                 rotationDegrees: dim.angle * 180 / .pi, layer: "DIMENSIONS")
        }

        if layout.bounds.width > 0 {
            let notePosition = SIMD2<Float>(Float(layout.bounds.minX), Float(layout.bounds.minY) - 0.3)
            text("\(plan.name) -- generated by Lexdar -- units: meters", at: notePosition, height: 0.15, layer: "TEXT")
        }

        emit(0, "ENDSEC")
        emit(0, "EOF")

        return lines.joined(separator: "\n") + "\n"
    }
}

/// Generates the DXF, previews a short summary (DXF has no convenient
/// in-app preview the way PDFKit previews a PDF), and offers it via the
/// system share sheet.
struct BlueprintDXFExportView: View {
    let floorPlan: FloorPlan

    @State private var dxfURL: URL?
    @State private var isGenerating = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let dxfURL {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("DXF file ready").font(.headline)
                        Text(dxfURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Opens in AutoCAD, SketchUp, Revit, Vectorworks, or any CAD tool that imports DXF. Units are meters; walls, doors, windows, rooms, and dimensions are on separate layers.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else if isGenerating {
                    ProgressView("Generating DXF…")
                } else {
                    Text("Couldn't generate the DXF.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("DXF Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if let dxfURL {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: dxfURL) { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
            .task { generate() }
        }
    }

    private func generate() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(floorPlan.name.replacingOccurrences(of: " ", with: "_")).dxf")
        let content = BlueprintDXFExporter.generate(from: floorPlan)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            dxfURL = url
        } catch {
            dxfURL = nil
        }
        isGenerating = false
    }
}
