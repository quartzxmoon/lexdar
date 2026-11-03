import SwiftUI

/// Root list of every saved `FloorPlan` — both LiDAR-generated ones
/// (linked back to their scan) and fully hand-drawn ones that never needed
/// a scan at all. Tapping one opens the formal `BlueprintView`; the detail
/// screen offers editing (hand-drawn tools work on *any* plan, including
/// a LiDAR-generated one you want to hand-correct) and PDF export.
struct FloorPlanListView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var showNewPlanPrompt = false
    @State private var newPlanName = "New Floor Plan"
    @State private var openPlan: FloorPlan?
    @State private var showMeasure = false

    var body: some View {
        NavigationStack {
            Group {
                if store.floorPlans.isEmpty {
                    emptyState
                } else {
                    List {
                        if !linkedToScan.isEmpty {
                            Section("From Scans") {
                                ForEach(linkedToScan) { plan in
                                    row(for: plan)
                                }
                            }
                        }
                        if !handDrawn.isEmpty {
                            Section("Hand-Drawn") {
                                ForEach(handDrawn) { plan in
                                    row(for: plan)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Floor Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        NavigationLink {
                            PropertySummaryView()
                        } label: {
                            Label("Property Summary", systemImage: "list.bullet.rectangle")
                        }
                        Button { showMeasure = true } label: {
                            Label("Measure (AR tape)", systemImage: "ruler")
                        }
                        NavigationLink {
                            LANSyncView()
                        } label: {
                            Label("Sync to Desktop", systemImage: "arrow.up.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newPlanName = "New Floor Plan"
                        showNewPlanPrompt = true
                    } label: {
                        Label("New Hand-Drawn Plan", systemImage: "pencil.and.ruler")
                    }
                }
            }
            .alert("Name this floor plan", isPresented: $showNewPlanPrompt) {
                TextField("Plan name", text: $newPlanName)
                Button("Create") {
                    openPlan = store.createHandDrawnFloorPlan(name: newPlanName)
                }
                Button("Cancel", role: .cancel) {}
            }
            .navigationDestination(item: $openPlan) { plan in
                FloorPlanDetailView(floorPlan: plan)
            }
            .fullScreenCover(isPresented: $showMeasure) {
                MeasureView()
            }
        }
    }

    private var linkedToScan: [FloorPlan] { store.floorPlans.filter { $0.scanID != nil } }
    private var handDrawn: [FloorPlan] { store.floorPlans.filter { $0.scanID == nil } }

    private func row(for plan: FloorPlan) -> some View {
        Button {
            openPlan = plan
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name).font(.headline).foregroundStyle(.primary)
                Text("\(plan.walls.count) walls · \(plan.rooms.count) room\(plan.rooms.count == 1 ? "" : "s") · \(String(format: "%.0f", plan.totalAreaSquareMeters * 10.7639)) sq ft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pencil.and.ruler")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No floor plans yet")
                .font(.title3.weight(.semibold))
            Text("Generate one from a scan on its detail screen, or draw one by hand here — grid-snapped walls, doors, windows, and room boundaries, exportable as a scaled PDF blueprint.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                newPlanName = "New Floor Plan"
                showNewPlanPrompt = true
            } label: {
                Label("Draw a Floor Plan", systemImage: "pencil.and.ruler")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

/// A single floor plan's home: the formal dimensioned drawing, with
/// actions to edit (hand-drawing tools) or export as a PDF blueprint.
struct FloorPlanDetailView: View {
    let floorPlan: FloorPlan
    @EnvironmentObject private var store: ScanStore
    @State private var showEditor = false
    @State private var showExport = false
    @State private var showDXFExport = false
    @State private var showAnnotate = false
    @State private var showPNGExport = false
    @State private var showModelExport = false
    @State private var showAR = false
    @State private var showPlacement = false
    @State private var liveFloorPlan: FloorPlan

    init(floorPlan: FloorPlan) {
        self.floorPlan = floorPlan
        self._liveFloorPlan = State(initialValue: floorPlan)
    }

    var body: some View {
        BlueprintView(floorPlan: liveFloorPlan)
            .navigationTitle(liveFloorPlan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showEditor = true } label: {
                            Label("Edit Walls / Doors / Rooms", systemImage: "pencil.and.ruler")
                        }
                        Button { showExport = true } label: {
                            Label("Export Blueprint PDF", systemImage: "square.and.arrow.up")
                        }
                        Button { showDXFExport = true } label: {
                            Label("Export DXF (CAD)", systemImage: "square.and.arrow.up.on.square")
                        }
                        Button { showModelExport = true } label: {
                            Label("Export IFC / OBJ / PLY / XYZ / CSV / JSON", systemImage: "cube")
                        }
                        Button { showPNGExport = true } label: {
                            Label("Export PNG Image", systemImage: "photo")
                        }
                        Button { showAR = true } label: {
                            Label("View in 3D / AR", systemImage: "arkit")
                        }
                        Button { showPlacement = true } label: {
                            Label("Property & Floor…", systemImage: "building.2")
                        }
                        Button { showAnnotate = true } label: {
                            Label("Annotate with Pencil", systemImage: "pencil.tip.crop.circle")
                        }
                        Button(role: .destructive) {
                            store.deleteFloorPlan(liveFloorPlan)
                        } label: {
                            Label("Delete Floor Plan", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fullScreenCover(isPresented: $showEditor, onDismiss: refresh) {
                BlueprintEditorView(floorPlan: liveFloorPlan)
            }
            .sheet(isPresented: $showExport) {
                BlueprintPDFExportView(floorPlan: liveFloorPlan)
            }
            .sheet(isPresented: $showDXFExport) {
                BlueprintDXFExportView(floorPlan: liveFloorPlan)
            }
            .sheet(isPresented: $showModelExport) {
                ModelExportView(floorPlan: liveFloorPlan)
            }
            .sheet(isPresented: $showPNGExport) {
                BlueprintPNGExportView(floorPlan: liveFloorPlan)
            }
            .fullScreenCover(isPresented: $showAR) {
                FloorPlanARView(floorPlan: liveFloorPlan)
            }
            .sheet(isPresented: $showPlacement) {
                PlanPlacementSheet(floorPlan: liveFloorPlan) { updated in
                    store.save(updated)
                    liveFloorPlan = updated
                }
            }
            .fullScreenCover(isPresented: $showAnnotate, onDismiss: refresh) {
                BlueprintAnnotationView(floorPlan: liveFloorPlan)
            }
    }

    private func refresh() {
        if let updated = store.floorPlans.first(where: { $0.id == floorPlan.id }) {
            liveFloorPlan = updated
        }
    }
}
