import SwiftUI
import PDFKit

#if canImport(RoomPlan)
import RoomPlan

/// Builds a one-page-per-section PDF summarizing a renovation plan — wall
/// removals, material swaps, and the full shopping list of placed items
/// with dimensions — then offers it via the system share sheet so it can be
/// handed to a contractor, saved to Files, printed, etc.
struct RenovationSummaryView: View {
    let room: CapturedRoom
    let plan: RenovationPlan

    @State private var pdfURL: URL?
    @State private var isGenerating = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let pdfURL {
                    PDFKitView(url: pdfURL)
                } else if isGenerating {
                    ProgressView("Building summary…")
                } else {
                    Text("Couldn't generate the summary.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Renovation Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if let pdfURL {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: pdfURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task { generate() }
        }
    }

    private func generate() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(plan.name.replacingOccurrences(of: " ", with: "_"))_summary.pdf")
        let renderer = RenovationPDFRenderer(room: room, plan: plan)
        if renderer.write(to: url) {
            pdfURL = url
        }
        isGenerating = false
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

/// Renders a simple, legible renovation summary document using Core
/// Graphics' PDF context directly (no external layout engine needed):
/// page 1 is the project overview + wall/material changes, page 2+ is the
/// itemized furnish/fixture list with running square-footage context.
private struct RenovationPDFRenderer {
    let room: CapturedRoom
    let plan: RenovationPlan

    private let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter, 72dpi
    private let margin: CGFloat = 48

    func write(to url: URL) -> Bool {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                drawOverviewPage(context: context)
                context.beginPage()
                drawItemsPage(context: context)
            }
            return true
        } catch {
            return false
        }
    }

    private func drawOverviewPage(context: UIGraphicsPDFRendererContext) {
        var y: CGFloat = margin
        y = drawTitle(plan.name, at: y)
        y = drawText("Generated \(Date().formatted(date: .long, time: .shortened))", at: y, font: .caption)
        y += 16

        y = drawHeading("Overview", at: y)
        let totalArea = room.floors.reduce(0.0) { $0 + Double($1.dimensions.x * $1.dimensions.z) }
        y = drawText("Floor area: \(String(format: "%.0f", totalArea * 10.7639)) sq ft (\(String(format: "%.1f", totalArea)) m²)", at: y)
        y = drawText("Walls in original scan: \(room.walls.count)", at: y)
        y = drawText("Walls removed in this plan: \(plan.removedWallIDs.count)", at: y)
        y = drawText("Material swaps: \(plan.surfaceMaterials.count)", at: y)
        y = drawText("Items placed: \(plan.placedItems.count)", at: y)
        y += 16

        if !plan.removedWallIDs.isEmpty {
            y = drawHeading("Walls to Remove", at: y)
            for wallID in plan.removedWallIDs {
                if let wall = room.walls.first(where: { $0.identifier == wallID }) {
                    let lengthFt = Double(wall.dimensions.x) * 3.28084
                    y = drawText(String(format: "• Wall, approx. %.1f ft long, %.1f ft tall", lengthFt, Double(wall.dimensions.y) * 3.28084), at: y)
                }
            }
            y += 16
        }

        if !plan.surfaceMaterials.isEmpty {
            y = drawHeading("Material Changes", at: y)
            for override in plan.surfaceMaterials {
                guard let catalogItem = Catalog.item(id: override.catalogItemID) else { continue }
                let isFloor = room.floors.contains { $0.identifier == override.surfaceID }
                let surfaceKind = isFloor ? "Floor" : "Wall"
                y = drawText("• \(surfaceKind) → \(catalogItem.name)", at: y)
            }
            y += 16
        }

        if !plan.notes.isEmpty {
            y = drawHeading("Notes", at: y)
            _ = drawText(plan.notes, at: y)
        }
    }

    private func drawItemsPage(context: UIGraphicsPDFRendererContext) {
        var y: CGFloat = margin
        y = drawTitle("Furnish / Fixture List", at: y)
        y += 8

        let grouped = Dictionary(grouping: plan.placedItems.compactMap { $0.catalogItem }, by: { $0.category })
        for category in CatalogCategory.allCases {
            guard let items = grouped[category], !items.isEmpty else { continue }
            y = drawHeading(category.displayName, at: y)
            for item in items {
                let widthFt = Double(item.dimensions.x) * 3.28084
                let depthFt = Double(item.dimensions.z) * 3.28084
                y = drawText(String(format: "• %@ (%.1f' × %.1f')", item.name, widthFt, depthFt), at: y)
                if y > pageRect.height - margin { break }
            }
            y += 12
        }

        if grouped.isEmpty {
            _ = drawText("No items placed in this plan yet.", at: y)
        }
    }

    private enum FontStyle { case title, heading, body, caption }

    @discardableResult
    private func drawTitle(_ text: String, at y: CGFloat) -> CGFloat {
        draw(text, at: y, font: .boldSystemFont(ofSize: 22))
    }

    @discardableResult
    private func drawHeading(_ text: String, at y: CGFloat) -> CGFloat {
        draw(text, at: y, font: .boldSystemFont(ofSize: 14))
    }

    @discardableResult
    private func drawText(_ text: String, at y: CGFloat, font style: FontStyle = .body) -> CGFloat {
        let font: UIFont = style == .caption ? .systemFont(ofSize: 10) : .systemFont(ofSize: 12)
        return draw(text, at: y, font: font)
    }

    @discardableResult
    private func draw(_ text: String, at y: CGFloat, font: UIFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let width = pageRect.width - margin * 2
        let rect = CGRect(x: margin, y: y, width: width, height: .greatestFiniteMagnitude)
        let bounding = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                          options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        (text as NSString).draw(in: rect, withAttributes: attributes)
        return y + bounding.height + 6
    }
}
#endif
