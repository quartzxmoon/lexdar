import Foundation

/// Spreadsheet-friendly room / wall / opening schedule plus the raw plan as
/// JSON, for estimators and for keying measurements into other software.
enum PlanScheduleExport {
    private static func cell(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func row(_ values: [String]) -> String {
        values.map(cell).joined(separator: ",") + "\n"
    }

    private static func num(_ v: Float, _ digits: Int = 2) -> String {
        String(format: "%.\(digits)f", v)
    }

    static func csv(for plan: FloorPlan) -> String {
        let feetPerMeter: Float = 3.28084
        var out = row(["Plan", plan.name])
        out += row(["Property", plan.propertyName ?? ""])
        out += row(["Floor", plan.floorLevel.map { FloorLevelName.label($0) } ?? ""])
        out += row(["Units", "meters and feet; areas in m2 and sq ft"])

        out += "\n" + row(["ROOMS"])
        out += row(["Name", "Area (m2)", "Area (sq ft)"])
        for room in plan.rooms {
            out += row([room.name, num(room.areaSquareMeters), num(room.areaSquareMeters * AreaFormat.sqFtPerSqM, 1)])
        }
        out += row(["Total", num(plan.totalAreaSquareMeters), num(plan.totalAreaSquareMeters * AreaFormat.sqFtPerSqM, 1)])

        out += "\n" + row(["WALLS"])
        out += row(["#", "Length (m)", "Length (ft)", "Height (m)", "Thickness (m)", "Wall area (m2)"])
        for (index, wall) in plan.walls.enumerated() {
            out += row(["\(index + 1)", num(wall.lengthMeters), num(wall.lengthMeters * feetPerMeter),
                        num(wall.height), num(wall.thickness, 3), num(wall.lengthMeters * wall.height)])
        }

        out += "\n" + row(["OPENINGS"])
        out += row(["Type", "Style", "Width (m)", "Width (ft)", "On wall #"])
        for opening in plan.openings {
            let wallNumber = plan.walls.firstIndex(where: { $0.id == opening.wallID }).map { "\($0 + 1)" } ?? ""
            out += row([opening.kind.displayName, opening.style?.displayName ?? "",
                        num(opening.width), num(opening.width * feetPerMeter), wallNumber])
        }

        out += "\n" + row(["STAIRS"])
        out += row(["Steps", "Run length (m)", "Width (m)"])
        for stair in plan.stairList {
            out += row(["\(stair.stepCount)", num(stair.length), num(stair.width)])
        }
        return out
    }

    static func json(for plan: FloorPlan) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(plan), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
