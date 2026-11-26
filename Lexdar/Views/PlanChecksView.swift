import SwiftUI
import simd

/// One finding from the plan checker.
struct PlanCheck: Identifiable {
    enum Level { case warning, info }
    let id = UUID()
    let level: Level
    let title: String
    let detail: String
}

/// Simple sanity checks on a floor plan: loose wall ends, overlapping openings,
/// bedrooms without a smoke alarm or window, outlets in wet rooms that are not
/// GFCI, narrow or steep stairs. The rules reflect common US model codes (the
/// IRC and NEC) and are guidance only: the local code, the building department,
/// and a licensed professional decide what a project actually needs.
enum PlanChecker {
    static func run(_ plan: FloorPlan) -> [PlanCheck] {
        var checks: [PlanCheck] = []

        // Loose wall ends.
        var loose = 0
        for wall in plan.walls {
            for end in [wall.start, wall.end] {
                let connected = plan.walls.contains { other in
                    guard other.id != wall.id else { return false }
                    return distance(end, toSegment: other.start, other.end) < max(0.08, other.thickness)
                }
                if !connected { loose += 1 }
            }
        }
        if loose > 0 {
            checks.append(PlanCheck(level: .info, title: "\(loose) wall end(s) do not meet another wall",
                                    detail: "Open ends are fine for a half wall or a peninsula, but a loose corner can also mean a small gap in the drawing."))
        }

        // Overlapping openings on one wall.
        for wall in plan.walls {
            let list = plan.openings(on: wall.id).sorted { $0.distanceFromWallStart < $1.distanceFromWallStart }
            for (a, b) in zip(list, list.dropFirst()) {
                if a.distanceFromWallStart + a.width / 2 > b.distanceFromWallStart - b.width / 2 {
                    checks.append(PlanCheck(level: .warning, title: "Two openings overlap on one wall",
                                            detail: "A \(a.kind.displayName.lowercased()) and a \(b.kind.displayName.lowercased()) share the same stretch of wall. Move one."))
                    break
                }
            }
        }

        // Room by room.
        for room in plan.rooms where room.polygon.count >= 3 {
            let name = room.name.lowercased()
            let isBedroom = ["bed", "primary", "master", "nursery"].contains { name.contains($0) }
            let isWet = ["kitchen", "bath", "laundry", "garage", "powder", "utility"].contains { name.contains($0) }
            let inside = plan.symbolList.filter { contains($0.position, in: room.polygon) }

            if isBedroom {
                if !inside.contains(where: { $0.kind == .smokeAlarm }) {
                    checks.append(PlanCheck(level: .warning, title: "\(room.name): no smoke alarm marked",
                                            detail: "Model codes (IRC R314) call for a smoke alarm in each sleeping room, outside sleeping areas, and on every level. Add one with the Symbols tool."))
                }
                let hasWindow = plan.openings.contains { opening in
                    guard opening.kind == .window, let wall = plan.walls.first(where: { $0.id == opening.wallID }) else { return false }
                    let spot = wall.point(atDistance: opening.distanceFromWallStart)
                    return contains(spot, in: room.polygon) || distance(spot, toPolygon: room.polygon) < 0.45
                }
                if !hasWindow {
                    checks.append(PlanCheck(level: .warning, title: "\(room.name): no window on the plan",
                                            detail: "Sleeping rooms generally need an emergency escape opening, usually a window of a minimum size (IRC R310). Check your local code."))
                }
                if room.areaSquareMeters < 6.5 {
                    checks.append(PlanCheck(level: .info, title: "\(room.name) is under about 70 sq ft",
                                            detail: "Many codes set a 70 sq ft minimum for a habitable room. Confirm with your local code."))
                }
            }

            if isWet {
                let outlets = inside.filter { $0.kind == .outlet }
                if !outlets.isEmpty, !inside.contains(where: { $0.kind == .outletGFCI }) {
                    checks.append(PlanCheck(level: .warning, title: "\(room.name): outlets are not GFCI",
                                            detail: "The NEC (210.8) requires GFCI protection for outlets in kitchens, bathrooms, laundry areas, garages, and similar spaces. Use GFCI outlets here."))
                }
            }
        }

        // Stairs.
        for stair in plan.stairList {
            if stair.width < 0.914 {
                checks.append(PlanCheck(level: .warning, title: "Stairs are narrower than 36 in",
                                        detail: "The IRC (R311.7.1) sets a 36 in minimum stair width for most homes. These are \(String(format: "%.0f", stair.width * 39.37)) in."))
            }
            let tread = stair.length / Float(max(stair.stepCount, 1))
            if tread < 0.254 {
                checks.append(PlanCheck(level: .warning, title: "Stair treads are under 10 in deep",
                                        detail: "The IRC (R311.7.5.2) sets a 10 in minimum tread depth. These work out to \(String(format: "%.1f", tread * 39.37)) in. Lengthen the run or use fewer steps."))
            }
        }

        // Structure and services reminders.
        if plan.walls.contains(where: { $0.structure == .loadBearing }) {
            checks.append(PlanCheck(level: .info, title: "Load-bearing walls are marked on this plan",
                                    detail: "These are your own markings. Before changing any wall, have a structural engineer confirm what it carries and design the beam or header."))
        }
        if plan.symbolList.isEmpty {
            checks.append(PlanCheck(level: .info, title: "No electrical or plumbing symbols yet",
                                    detail: "Use the Symbols tool to mark outlets, switches, lights, panels, and shutoffs so contractors can see them."))
        }

        return checks
    }

    // MARK: - Geometry

    private static func distance(_ p: SIMD2<Float>, toSegment a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let ab = b - a
        let lengthSquared = simd_length_squared(ab)
        guard lengthSquared > 0.000001 else { return simd_length(p - a) }
        let t = max(0, min(1, simd_dot(p - a, ab) / lengthSquared))
        return simd_length(p - (a + ab * t))
    }

    private static func distance(_ p: SIMD2<Float>, toPolygon polygon: [SIMD2<Float>]) -> Float {
        var best = Float.greatestFiniteMagnitude
        for i in 0..<polygon.count {
            best = min(best, distance(p, toSegment: polygon[i], polygon[(i + 1) % polygon.count]))
        }
        return best
    }

    private static func contains(_ p: SIMD2<Float>, in polygon: [SIMD2<Float>]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let a = polygon[i], b = polygon[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}

struct PlanChecksView: View {
    let plan: FloorPlan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let checks = PlanChecker.run(plan)
        NavigationStack {
            List {
                if checks.isEmpty {
                    Section {
                        Label("These checks found nothing to flag.", systemImage: "checkmark.circle")
                        Text("That does not mean the plan meets code. Local rules, permits, and inspections still apply.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(checks) { check in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(check.title, systemImage: check.level == .warning ? "exclamationmark.triangle.fill" : "info.circle")
                            .font(.headline)
                            .foregroundStyle(check.level == .warning ? .orange : .primary)
                        Text(check.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                Section {
                    Text("General guidance from common US model codes (IRC and NEC). Your local code, building department, and a licensed contractor, engineer, or electrician decide what a project needs.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Plan Checks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
