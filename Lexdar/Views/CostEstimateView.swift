import SwiftUI

#if canImport(RoomPlan)
import RoomPlan

/// A rough cost estimate and shopping list for one renovation plan, scaled to
/// the homeowner's ZIP code. Prices start from the app's own US-average
/// estimates, are adjusted by state price levels (BEA) and by current
/// construction-materials and construction-wage trends (BLS via FRED), and can
/// be replaced line by line with real local quotes.
struct CostEstimateView: View {
    let room: CapturedRoom
    let plan: RenovationPlan

    @StateObject private var service = CostService()
    @Environment(\.dismiss) private var dismiss
    @State private var editing: CostLine?
    @State private var editText = ""

    private var summary: CostSummary {
        CostEstimator.estimate(room: room, plan: plan, pricing: service.pricing)
    }

    private struct LineGroup {
        let name: String
        let lines: [CostLine]
    }

    private var groups: [LineGroup] {
        Dictionary(grouping: summary.lines, by: { $0.group })
            .map { LineGroup(name: $0.key, lines: $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                locationSection
                totalsSection
                ForEach(groups, id: \.name) { group in
                    Section {
                        ForEach(group.lines) { line in lineRow(line) }
                    } header: {
                        HStack {
                            Text(group.name)
                            Spacer()
                            Text(money(group.lines.reduce(0) { $0 + $1.total }))
                        }
                    }
                }
                if summary.lines.isEmpty {
                    Section {
                        Text("Nothing to price yet. Place items, change floors or walls, remove walls, or draw new walls, and they will appear here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                shareSection
                notesSection
            }
            .navigationTitle("Cost Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await service.refreshIfStale() }
            .onChange(of: service.zip) { _, newValue in
                if newValue.filter(\.isNumber).count == 5 {
                    Task { await service.lookupZip() }
                }
            }
            .alert("Local price", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("Price per \(editing?.unit ?? "unit")", text: $editText)
                    .keyboardType(.decimalPad)
                Button("Save") {
                    if let id = editing?.itemID, let price = Double(editText.replacingOccurrences(of: ",", with: "")) {
                        service.setOverride(price, itemID: id)
                    }
                    editing = nil
                }
                Button("Use starter price", role: .destructive) {
                    if let id = editing?.itemID { service.setOverride(nil, itemID: id) }
                    editing = nil
                }
                Button("Cancel", role: .cancel) { editing = nil }
            } message: {
                Text("Type what you were actually quoted or saw in a store near you, per \(editing?.unit ?? "unit"). It is remembered for ZIP \(service.cleanZip.isEmpty ? "(none)" : service.cleanZip).")
            }
        }
    }

    // MARK: - Sections

    private var locationSection: some View {
        Section("Where is the project?") {
            HStack {
                TextField("ZIP code", text: $service.zip)
                    .keyboardType(.numberPad)
                Button("Look up") { Task { await service.lookupZip() } }
                    .disabled(service.cleanZip.count != 5 || service.isWorking)
            }
            Picker("State", selection: $service.stateCode) {
                Text("Not set (national average)").tag("")
                ForEach(CostData.stateNames.sorted { $0.value < $1.value }, id: \.key) { entry in
                    Text(entry.value).tag(entry.key)
                }
            }
            if let region = service.region {
                let place = service.placeName.isEmpty ? (CostData.stateNames[service.stateCode] ?? "") : "\(service.placeName), \(service.stateCode)"
                LabeledContent("Area", value: place)
                LabeledContent("Local materials prices", value: percentText(region.goods))
                LabeledContent("Local labor prices", value: percentText(region.services))
            } else {
                Text("Enter a ZIP code or pick a state to adjust prices for where you live. Until then the national average is used.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let materials = service.materialsIndex, let wages = service.wageDollars {
                LabeledContent("Materials prices since Oct 2026",
                               value: trendText(materials / CostData.baseMaterialsIndex))
                LabeledContent("Construction wages since Oct 2026",
                               value: trendText(wages / CostData.baseWageDollars))
                if let month = service.indexMonth {
                    Text("Latest government reading: \(month). Checked automatically about once a week.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                Task { await service.refreshIndexes() }
            } label: {
                Label(service.isWorking ? "Checking..." : "Update current price trends", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(service.isWorking)
            if let status = service.status {
                Text(status).font(.footnote).foregroundStyle(.orange)
            }
        }
    }

    private var totalsSection: some View {
        Section("Estimated total") {
            LabeledContent("Items and work", value: money(summary.subtotal))
            LabeledContent("Contingency (10%)", value: money(summary.contingency))
            LabeledContent("Planning estimate") {
                Text(money(summary.total)).font(.headline)
            }
            LabeledContent("Likely range", value: "\(money(summary.low)) to \(money(summary.high))")
        }
    }

    private func lineRow(_ line: CostLine) -> some View {
        Button {
            editText = String(format: "%.2f", line.unitPrice)
            editing = line
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.title).foregroundStyle(.primary)
                    Text("\(quantityText(line.quantity)) \(line.unit) at \(money(line.unitPrice, cents: line.unitPrice < 50))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if line.overridden {
                        Text("Your local price").font(.caption2).foregroundStyle(.green)
                    } else if line.generic {
                        Text("Generic price, tap to set your own").font(.caption2).foregroundStyle(.orange)
                    }
                }
                Spacer()
                Text(money(line.total)).foregroundStyle(.primary)
            }
        }
    }

    private var shareSection: some View {
        Section("Shopping list") {
            ShareLink(item: shoppingListText(), subject: Text("Shopping list: \(plan.name)")) {
                Label("Share shopping list", systemImage: "list.bullet.clipboard")
            }
            ShareLink(item: csvText(), subject: Text("Cost estimate (CSV): \(plan.name)")) {
                Label("Share as spreadsheet (CSV)", systemImage: "tablecells")
            }
        }
    }

    private var notesSection: some View {
        Section("About these numbers") {
            Text("This is a planning estimate, not a quote. Starting prices are the app's own typical US costs. They are scaled by your state's price level (U.S. Bureau of Economic Analysis, \(CostData.regionsDataYear)) and by current construction-materials and construction-wage trends (U.S. Bureau of Labor Statistics through FRED). Real prices at your local stores and contractors will differ, so tap any line and enter a real local price to improve it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Removing or moving walls can involve structural, electrical, and plumbing work that needs a licensed professional and permits. Beams, headers, rewiring, and permits are not included here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Text and formatting

    private func money(_ value: Double, cents: Bool = false) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(cents ? 2 : 0)))
    }

    private func quantityText(_ value: Double) -> String {
        value >= 100 || value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private func percentText(_ index: Double) -> String {
        let delta = index - 100
        if abs(delta) < 0.5 { return "About national average" }
        return String(format: "%.0f%% %@ national average", abs(delta), delta > 0 ? "above" : "below")
    }

    private func trendText(_ ratio: Double) -> String {
        String(format: "%+.1f%%", (ratio - 1) * 100)
    }

    private func shoppingListText() -> String {
        var out = "Shopping list: \(plan.name)\n"
        if !service.cleanZip.isEmpty { out += "ZIP \(service.cleanZip)\n" }
        out += "Planning estimate only, not a quote.\n\n"
        for group in groups {
            out += "\(group.name)\n"
            for line in group.lines {
                out += "  [ ] \(line.title): \(quantityText(line.quantity)) \(line.unit), about \(money(line.total))\n"
            }
            out += "\n"
        }
        out += "Total with 10% contingency: \(money(summary.total)) (range \(money(summary.low)) to \(money(summary.high)))\n"
        return out
    }

    private func csvText() -> String {
        func field(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var out = "Group,Item,Quantity,Unit,Unit price,Line total\n"
        for line in summary.lines {
            out += [field(line.group), field(line.title), String(format: "%.2f", line.quantity), field(line.unit),
                    String(format: "%.2f", line.unitPrice), String(format: "%.2f", line.total)].joined(separator: ",") + "\n"
        }
        out += ",,,,Total with 10% contingency,\(String(format: "%.2f", summary.total))\n"
        return out
    }
}
#endif
