import SwiftUI

#if canImport(RoomPlan)
import RoomPlan

/// One scan's home base: the 3D model preview (AR Quick Look), the 2D floor
/// plan, and the list of renovation plans built from this scan.
struct ScanDetailView: View {
    let project: ScanProject
    @EnvironmentObject private var store: ScanStore

    @State private var room: CapturedRoom?
    @State private var showNewPlanPrompt = false
    @State private var newPlanName = "Renovation Idea"
    @State private var openPlan: RenovationPlan?

    var body: some View {
        Group {
            if let room {
                content(room: room)
            } else {
                ContentUnavailableFallback()
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { room = store.loadRoom(for: project) }
        .alert("Name this renovation plan", isPresented: $showNewPlanPrompt) {
            TextField("Plan name", text: $newPlanName)
            Button("Create") {
                let plan = store.createPlan(scanID: project.id, name: newPlanName)
                openPlan = plan
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $openPlan) { plan in
            if let room {
                RenovationEditorView(room: room, plan: plan)
            }
        }
    }

    @ViewBuilder
    private func content(room: CapturedRoom) -> some View {
        List {
            Section("3D Model") {
                NavigationLink {
                    USDZPreviewView(url: store.modelURL(for: project))
                        .navigationTitle("3D Model")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("View / AR Preview", systemImage: "arkit")
                }
            }

            Section("Floor Plan") {
                FloorPlanView(room: room)
                    .frame(height: 320)
                    .listRowInsets(EdgeInsets())

                let generated = store.floorPlans(for: project.id)
                if let plan = generated.first {
                    NavigationLink {
                        FloorPlanDetailView(floorPlan: plan)
                    } label: {
                        Label("Blueprint: \(plan.name)", systemImage: "pencil.and.ruler")
                    }
                } else {
                    Button {
                        _ = store.generateFloorPlan(from: project)
                    } label: {
                        Label("Generate Contractor-Grade Floor Plan", systemImage: "pencil.and.ruler")
                    }
                }
            }

            Section("Renovation Plans") {
                let plans = store.plans(for: project.id)
                if plans.isEmpty {
                    Text("No renovation plans yet. Create one to try removing walls, swapping flooring, or furnishing the space.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(plans) { plan in
                    Button {
                        openPlan = plan
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name).font(.headline).foregroundStyle(.primary)
                            Text(planSummary(plan))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indices in
                    for index in indices { store.deletePlan(plans[index]) }
                }

                Button {
                    newPlanName = "Renovation Idea \(store.plans(for: project.id).count + 1)"
                    showNewPlanPrompt = true
                } label: {
                    Label("New Renovation Plan", systemImage: "plus.circle.fill")
                }
            }
        }
    }

    private func planSummary(_ plan: RenovationPlan) -> String {
        var parts: [String] = []
        if !plan.removedWallIDs.isEmpty { parts.append("\(plan.removedWallIDs.count) wall(s) removed") }
        if !plan.placedItems.isEmpty { parts.append("\(plan.placedItems.count) item(s) placed") }
        if !plan.surfaceMaterials.isEmpty { parts.append("\(plan.surfaceMaterials.count) material swap(s)") }
        return parts.isEmpty ? "Updated \(plan.updatedAt.formatted(date: .abbreviated, time: .shortened))" : parts.joined(separator: " · ")
    }
}

private struct ContentUnavailableFallback: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Couldn't load this scan's room data.")
                .foregroundStyle(.secondary)
        }
    }
}
#endif
