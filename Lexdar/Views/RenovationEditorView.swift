import SwiftUI

#if canImport(RoomPlan)
import RoomPlan

/// The renovation workspace: a 3D view of the scanned room with tools to
/// knock down walls, swap flooring/wall finishes, and furnish the space from
/// the catalog — this is the "see what it'd look like" / "make a renovation
/// plan" screen.
struct RenovationEditorView: View {
    let room: CapturedRoom
    @State var plan: RenovationPlan
    /// Whether to draw the furniture/fixtures detected during the scan.
    var showDetectedObjects: Bool = true
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss

    @State private var tool: RenovationTool = .inspect
    @State private var activeCatalogItemID: String?
    @State private var selectedPlacedItemID: UUID?
    @State private var pendingPlacementItemID: String?
    @State private var hudText: String?
    @State private var showCatalogSheet = false
    @State private var showSummary = false
    @State private var showCost = false
    @State private var showOriginal = false
    @State private var showDeleteConfirm = false
    /// Which story new walls and items go on (0 = the scanned floor).
    @State private var level = 0

    private static func levelName(_ level: Int) -> String {
        switch level {
        case ..<0: return "Basement"
        case 0: return "Ground Floor"
        case 1: return "2nd Floor"
        case 2: return "3rd Floor"
        default: return "Attic / Roof Level"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                RenovationSceneView(room: room, plan: $plan, tool: $tool,
                                     activeCatalogItemID: $activeCatalogItemID,
                                     selectedPlacedItemID: $selectedPlacedItemID,
                                     pendingPlacementItemID: $pendingPlacementItemID,
                                     hudText: $hudText,
                                     showDetectedObjects: showDetectedObjects,
                                     levelIndex: level,
                                     showOriginal: showOriginal)
                    .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 10) {
                    if selectedPlacedItemID != nil, tool == .inspect {
                        selectedItemBar
                    }
                    if tool == .drawWall {
                        drawWallBar
                    }
                    toolBar
                        .disabled(showOriginal)
                        .opacity(showOriginal ? 0.4 : 1)
                }
                .padding(.bottom, 8)
            }
            .overlay(alignment: .topLeading) {
                Menu {
                    ForEach([4, 3, 2, 1, 0, -1], id: \.self) { l in
                        Button {
                            level = l
                        } label: {
                            Label(Self.levelName(l), systemImage: level == l ? "checkmark" : "square.3.layers.3d")
                        }
                    }
                } label: {
                    Label(Self.levelName(level), systemImage: "square.3.layers.3d")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.leading, 12).padding(.top, 8)
            }
            .overlay(alignment: .topTrailing) {
                Picker("View", selection: $showOriginal) {
                    Text("After").tag(false)
                    Text("Before").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                .padding(.trailing, 12).padding(.top, 8)
            }
            .overlay(alignment: .top) {
                if let hudText {
                    Text(hudText)
                        .font(.headline.monospacedDigit())
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .navigationTitle(plan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        store.save(plan)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button {
                            showCost = true
                        } label: {
                            Label("Cost Estimate & Shopping List", systemImage: "dollarsign.circle")
                        }
                        Button {
                            showSummary = true
                        } label: {
                            Label("Export Summary", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Plan", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onChange(of: plan) { _, newValue in
                store.save(newValue)
            }
            .sheet(isPresented: $showCatalogSheet, onDismiss: {
                // Backing out of the furnish catalog without choosing leaves
                // nothing to do in Place mode, so return to Select.
                if tool == .place { tool = .inspect }
            }) {
                catalogSheet
            }
            .sheet(isPresented: $showCost) {
                CostEstimateView(room: room, plan: plan)
            }
            .sheet(isPresented: $showSummary) {
                RenovationSummaryView(room: room, plan: plan)
            }
            .confirmationDialog("Delete this renovation plan?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.deletePlan(plan)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        HStack(spacing: 8) {
            ForEach(RenovationTool.allCases) { t in
                Button {
                    selectTool(t)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: t.symbolName)
                        Text(t.label).font(.caption2)
                    }
                    .frame(minWidth: 64)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(tool == t ? Color.accentColor.opacity(0.25) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var selectedItemBar: some View {
        HStack {
            if let id = selectedPlacedItemID,
               let placed = plan.placedItems.first(where: { $0.id == id }),
               let catalogItem = placed.catalogItem {
                Label(catalogItem.name, systemImage: catalogItem.category.symbolName)
                    .font(.caption.weight(.medium))
            }
            Spacer()
            Text("Drag to move · pinch to resize · twist to rotate")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) {
                if let id = selectedPlacedItemID {
                    plan.removeItem(id)
                    selectedPlacedItemID = nil
                }
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var drawWallBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil.and.ruler.fill")
            Text("Drag on the floor with your finger or Pencil to build a wall. It snaps to corners, 15° angles, and a 2 in grid. Tap Select to turn the view.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Undo") { plan.removeLastAddedWall() }
                .disabled(plan.newWalls.isEmpty)
            Button("Clear", role: .destructive) { plan.clearAddedWalls() }
                .disabled(plan.newWalls.isEmpty)
        }
        .font(.caption.weight(.medium))
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func selectTool(_ t: RenovationTool) {
        selectedPlacedItemID = nil
        switch t {
        case .inspect, .removeWalls, .drawWall:
            tool = t
        case .paintFloor, .paintWall, .place:
            tool = t
            showCatalogSheet = true
        }
    }

    // MARK: - Catalog sheet, scoped to the active tool

    @ViewBuilder
    private var catalogSheet: some View {
        switch tool {
        case .paintFloor:
            CatalogBrowserView(categories: [.flooring], title: "Flooring") { item in
                activeCatalogItemID = item.id
            }
        case .paintWall:
            CatalogBrowserView(categories: [.wallFinish, .exteriorFinish], title: "Wall & Exterior Finishes") { item in
                activeCatalogItemID = item.id
            }
        case .place:
            CatalogBrowserView(categories: CatalogCategory.allCases.filter { !$0.isSurfaceMaterial },
                                title: "Furnish & Build") { item in
                activeCatalogItemID = item.id
                pendingPlacementItemID = item.id
            }
        case .inspect, .removeWalls, .drawWall:
            EmptyView()
        }
    }
}
#endif
