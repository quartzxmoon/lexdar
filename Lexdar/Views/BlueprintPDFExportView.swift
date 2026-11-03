import SwiftUI
import PDFKit
import simd

/// Exports a `FloorPlan` as a true-to-scale, vector-drawn PDF blueprint:
/// the same `BlueprintLayout` the on-screen `BlueprintView` draws, rendered
/// again with raw `CGContext` calls at a real architectural scale (1/4" =
/// 1'-0" when it fits the page, falling back to the next-smaller standard
/// scale, or an explicitly-labeled "NOT TO SCALE" fit if even the smallest
/// standard scale doesn't fit).
struct BlueprintPDFExportView: View {
    let floorPlan: FloorPlan

    @State private var pdfURL: URL?
    @State private var isGenerating = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let pdfURL {
                    BlueprintPDFKitView(url: pdfURL)
                } else if isGenerating {
                    ProgressView("Drawing blueprint…")
                } else {
                    Text("Couldn't generate the blueprint.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Blueprint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if let pdfURL {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: pdfURL) { Image(systemName: "square.and.arrow.up") }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Self.airPrint(pdfURL)
                        } label: {
                            Image(systemName: "printer")
                        }
                    }
                }
            }
            .task { generate() }
        }
    }

    private static func airPrint(_ url: URL) {
        guard UIPrintInteractionController.isPrintingAvailable else { return }
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = url.deletingPathExtension().lastPathComponent
        info.orientation = .landscape
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = url
        controller.present(animated: true)
    }

    private func generate() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(floorPlan.name.replacingOccurrences(of: " ", with: "_"))_blueprint.pdf")
        let renderer = BlueprintPDFRenderer(floorPlan: floorPlan)
        pdfURL = renderer.write(to: url) ? url : nil
        isGenerating = false
    }
}

private struct BlueprintPDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

/// Letter landscape, 1in margins, a 0.75in band at the bottom reserved for
/// the title block. Picks the largest standard architectural scale that
/// fits the plan in the remaining drawing area.
struct BlueprintPDFRenderer {
    let floorPlan: FloorPlan

    private let pageSize = CGSize(width: 792, height: 612) // US Letter, landscape, 72dpi
    private let margin: CGFloat = 54
    private let titleBlockHeight: CGFloat = 54

    private static let standardScales: [(label: String, inchesPerFoot: Double)] = [
        ("1/4\" = 1'-0\"", 0.25),
        ("3/16\" = 1'-0\"", 0.1875),
        ("1/8\" = 1'-0\"", 0.125),
        ("1/16\" = 1'-0\"", 0.0625),
    ]

    func write(to url: URL) -> Bool {
        let layout = BlueprintLayout.build(from: floorPlan)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                draw(layout: layout, in: context.cgContext)
            }
            return true
        } catch {
            return false
        }
    }

    private func draw(layout: BlueprintLayout, in ctx: CGContext) {
        let drawableWidth = pageSize.width - margin * 2
        let drawableHeight = pageSize.height - margin * 2 - titleBlockHeight

        let (scaleLabel, pointsPerMeter): (String, CGFloat)
        if layout.bounds.width > 0, layout.bounds.height > 0 {
            (scaleLabel, pointsPerMeter) = chooseScale(bounds: layout.bounds,
                                                         available: CGSize(width: drawableWidth, height: drawableHeight))
        } else {
            (scaleLabel, pointsPerMeter) = ("NOT TO SCALE", 1)
        }

        let drawingOriginX = margin + (drawableWidth - layout.bounds.width * pointsPerMeter) / 2
        let drawingOriginY = margin + (drawableHeight - layout.bounds.height * pointsPerMeter) / 2

        func project(_ p: SIMD2<Float>) -> CGPoint {
            CGPoint(x: drawingOriginX + (CGFloat(p.x) - layout.bounds.minX) * pointsPerMeter,
                     y: drawingOriginY + (CGFloat(p.y) - layout.bounds.minY) * pointsPerMeter)
        }

        ctx.setLineCap(.round)

        // Walls
        ctx.setStrokeColor(UIColor.black.cgColor)
        for (wall, line) in layout.wallSegments {
            ctx.setLineWidth(max(1.2, CGFloat(wall.thickness) * pointsPerMeter))
            ctx.move(to: project(line.a))
            ctx.addLine(to: project(line.b))
            ctx.strokePath()
        }

        drawOpenings(layout, project: project, ctx: ctx)
        drawRooms(layout, project: project, ctx: ctx)
        drawDimensions(layout, project: project, ctx: ctx)
        drawTitleBlock(scaleLabel: scaleLabel, ctx: ctx)
    }

    private func chooseScale(bounds: CGRect, available: CGSize) -> (String, CGFloat) {
        for (label, inchesPerFoot) in Self.standardScales {
            let pointsPerFoot = CGFloat(inchesPerFoot) * 72
            let pointsPerMeter = pointsPerFoot / 0.3048
            if bounds.width * pointsPerMeter <= available.width,
               bounds.height * pointsPerMeter <= available.height {
                return (label, pointsPerMeter)
            }
        }
        let fit = min(available.width / bounds.width, available.height / bounds.height)
        return ("NOT TO SCALE", max(fit, 0.01))
    }

    private func drawOpenings(_ layout: BlueprintLayout, project: (SIMD2<Float>) -> CGPoint, ctx: CGContext) {
        for door in layout.doors {
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(4)
            ctx.move(to: project(door.gapInWall.a)); ctx.addLine(to: project(door.gapInWall.b)); ctx.strokePath()

            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: project(door.panelLine.a)); ctx.addLine(to: project(door.panelLine.b)); ctx.strokePath()

            let center = project(door.arcCenter)
            let radius = project(door.arcCenter + SIMD2<Float>(door.arcRadius, 0)).x - center.x
            ctx.setLineDash(phase: 0, lengths: [2, 2])
            ctx.addArc(center: center, radius: abs(radius),
                       startAngle: CGFloat(door.arcStartAngle), endAngle: CGFloat(door.arcEndAngle), clockwise: false)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
        }

        for window in layout.windows {
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(4)
            ctx.move(to: project(window.gapInWall.a)); ctx.addLine(to: project(window.gapInWall.b)); ctx.strokePath()
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(0.8)
            for sill in window.sillLines {
                ctx.move(to: project(sill.a)); ctx.addLine(to: project(sill.b)); ctx.strokePath()
            }
        }

        for opening in layout.plainOpenings {
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(4)
            ctx.move(to: project(opening.a)); ctx.addLine(to: project(opening.b)); ctx.strokePath()
        }
    }

    private func drawRooms(_ layout: BlueprintLayout, project: (SIMD2<Float>) -> CGPoint, ctx: CGContext) {
        ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [2, 2])
        for polygon in layout.roomPolygons where polygon.count >= 3 {
            ctx.move(to: project(polygon[0]))
            for p in polygon.dropFirst() { ctx.addLine(to: project(p)) }
            ctx.closePath()
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])

        for label in layout.roomLabels {
            let point = project(label.position)
            drawCenteredText(label.name, at: CGPoint(x: point.x, y: point.y - 7), fontSize: 9, bold: true)
            drawCenteredText(label.areaLabel, at: CGPoint(x: point.x, y: point.y + 5), fontSize: 7.5, bold: false)
        }
    }

    private func drawDimensions(_ layout: BlueprintLayout, project: (SIMD2<Float>) -> CGPoint, ctx: CGContext) {
        ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(0.4)
        for dim in layout.dimensions {
            ctx.move(to: project(dim.extensionA.a)); ctx.addLine(to: project(dim.extensionA.b)); ctx.strokePath()
            ctx.move(to: project(dim.extensionB.a)); ctx.addLine(to: project(dim.extensionB.b)); ctx.strokePath()
            ctx.move(to: project(dim.a)); ctx.addLine(to: project(dim.b)); ctx.strokePath()

            let mid = project(dim.midpoint)
            ctx.saveGState()
            ctx.translateBy(x: mid.x, y: mid.y)
            ctx.rotate(by: CGFloat(dim.angle))
            drawCenteredText(dim.label, at: .zero, fontSize: 7, bold: false)
            ctx.restoreGState()
        }
    }

    private func drawTitleBlock(scaleLabel: String, ctx: CGContext) {
        let bandRect = CGRect(x: 0, y: pageSize.height - titleBlockHeight, width: pageSize.width, height: titleBlockHeight)
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(bandRect)

        let leftX = margin
        var y = bandRect.minY + 8
        drawText(floorPlan.name, at: CGPoint(x: leftX, y: y), fontSize: 14, bold: true)
        y += 18
        let sourceLabel = floorPlan.scanID != nil ? "Generated from LiDAR scan" : "Drawn by hand"
        drawText("\(sourceLabel) · \(Date().formatted(date: .abbreviated, time: .omitted))",
                  at: CGPoint(x: leftX, y: y), fontSize: 9, bold: false)

        drawText("SCALE: \(scaleLabel)", at: CGPoint(x: pageSize.width - margin - 220, y: bandRect.minY + 8),
                  fontSize: 10, bold: true)
        drawText("Preliminary planning drawing — not for construction or permitting",
                  at: CGPoint(x: pageSize.width - margin - 320, y: bandRect.minY + 24), fontSize: 8, bold: false)
        drawText("without review and dimension verification by a licensed professional.",
                  at: CGPoint(x: pageSize.width - margin - 320, y: bandRect.minY + 36), fontSize: 8, bold: false)
    }

    private func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, bold: Bool) {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        (text as NSString).draw(at: point, withAttributes: [.font: font])
    }

    private func drawCenteredText(_ text: String, at point: CGPoint, fontSize: CGFloat, bold: Bool) {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let size = (text as NSString).size(withAttributes: [.font: font])
        let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        (text as NSString).draw(in: rect, withAttributes: [.font: font])
    }
}
