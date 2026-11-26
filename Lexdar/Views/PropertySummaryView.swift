import SwiftUI

enum AreaFormat {
    static let sqFtPerSqM: Float = 10.7639

    static func text(_ squareMeters: Float) -> String {
        String(format: "%.1f m² (%.0f sq ft)", squareMeters, squareMeters * sqFtPerSqM)
    }
}

enum FloorLevelName {
    static func label(_ level: Int) -> String {
        switch level {
        case ..<0: return level == -1 ? "Basement" : "Basement \(-level)"
        case 0: return "Ground Floor"
        case 1: return "1st Floor"
        case 2: return "2nd Floor"
        case 3: return "3rd Floor"
        default: return "\(level)th Floor"
        }
    }
}

/// Whole-property roll-up: plans grouped by property, then by floor, with a
/// per-room area list and per-floor / per-property totals.
struct PropertySummaryView: View {
    @EnvironmentObject private var store: ScanStore

    private var properties: [(name: String, plans: [FloorPlan])] {
        let grouped = Dictionary(grouping: store.floorPlans) { $0.propertyName ?? "Unassigned" }
        return grouped.keys.sorted().map { (name: $0, plans: grouped[$0] ?? []) }
    }

    var body: some View {
        List {
            if store.floorPlans.isEmpty {
                Text("No floor plans yet.").foregroundStyle(.secondary)
            }
            ForEach(properties, id: \.name) { property in
                let total = property.plans.reduce(0) { $0 + $1.totalAreaSquareMeters }
                Section {
                    ForEach(floors(of: property.plans), id: \.level) { floor in
                        floorHeader(level: floor.level, plans: floor.plans)
                        ForEach(floor.plans) { plan in
                            ForEach(plan.rooms) { room in
                                HStack {
                                    Text(room.name.isEmpty ? "Room" : room.name)
                                    Spacer()
                                    Text(AreaFormat.text(room.areaSquareMeters))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                } header: {
                    Text("\(property.name) - \(AreaFormat.text(total))")
                }
            }
        }
        .navigationTitle("Property Summary")
    }

    private func floors(of plans: [FloorPlan]) -> [(level: Int, plans: [FloorPlan])] {
        let grouped = Dictionary(grouping: plans) { $0.floorLevel ?? 0 }
        return grouped.keys.sorted(by: >).map { (level: $0, plans: grouped[$0] ?? []) }
    }

    private func floorHeader(level: Int, plans: [FloorPlan]) -> some View {
        let total = plans.reduce(0) { $0 + $1.totalAreaSquareMeters }
        return Text("\(FloorLevelName.label(level)) (\(AreaFormat.text(total)))")
            .font(.headline)
    }
}

/// Assigns a plan to a property and a floor level so it shows up grouped in
/// `PropertySummaryView`.
struct PlanPlacementSheet: View {
    let floorPlan: FloorPlan
    let onSave: (FloorPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var propertyName: String
    @State private var floorLevel: Int
    @State private var ceilingHeight: Float

    init(floorPlan: FloorPlan, onSave: @escaping (FloorPlan) -> Void) {
        self.floorPlan = floorPlan
        self.onSave = onSave
        _propertyName = State(initialValue: floorPlan.propertyName ?? "")
        _floorLevel = State(initialValue: floorPlan.floorLevel ?? 0)
        _ceilingHeight = State(initialValue: floorPlan.walls.first?.height ?? 2.4384)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Property") {
                    TextField("Property name (e.g. 12 Oak Street)", text: $propertyName)
                }
                Section("Floor") {
                    Stepper(value: $floorLevel, in: -3...20) {
                        Text(FloorLevelName.label(floorLevel))
                    }
                }
                Section("Ceiling height") {
                    Stepper(value: $ceilingHeight, in: 2.0...6.0, step: 0.05) {
                        let totalInches = ceilingHeight * 39.3701
                        Text(String(format: "%.2f m (%ld ft %.0f in)", ceilingHeight, Int(totalInches / 12), totalInches.truncatingRemainder(dividingBy: 12)))
                    }
                    Text("Applies to every wall in this plan. Used by the 3D view, AR, IFC, and mesh exports.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Property & Floor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = floorPlan
                        let trimmed = propertyName.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.propertyName = trimmed.isEmpty ? nil : trimmed
                        updated.floorLevel = floorLevel
                        for i in updated.walls.indices { updated.walls[i].height = ceilingHeight }
                        updated.touch()
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}
