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
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss

    @State private var tool: RenovationTool = .inspect
    @State private var activeCatalogItemID: String?
    @State private var selectedPlacedItemID: UUID?
    @State private var showCatalogSheet = false
    @State private var showSummary = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                RenovationSceneView(room: room, plan: $plan, tool: $tool,
                                     activeCatalogItemID: $activeCatalogItemID,
                                     selectedPlacedItemID: $selectedPlacedItemID)
                    .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 10) {
                    if selectedPlacedItemID != nil, tool == .inspect {
                        selectedItemBar
                    }
                    toolBar
                }
                .padding(.bottom, 8)
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
            .sheet(isPresented: $showCatalogSheet) {
                catalogSheet
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

    private func selectTool(_ t: RenovationTool) {
        selectedPlacedItemID = nil
        switch t {
        case .inspect, .removeWalls:
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
            CatalogBrowserView(categories: [.wallFinish], title: "Wall Finishes") { item in
                activeCatalogItemID = item.id
            }
        case .place:
            CatalogBrowserView(categories: [.kitchenFixture, .bathroomFixture, .appliance, .furniture, .lighting, .outdoor],
                                title: "Furnish the Room") { item in
                activeCatalogItemID = item.id
            }
        case .inspect, .removeWalls:
            EmptyView()
        }
    }
}
#endif
