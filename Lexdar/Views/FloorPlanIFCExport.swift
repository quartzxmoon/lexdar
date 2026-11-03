import Foundation
import simd

/// Hand-written IFC4 (STEP) export: project / site / building / storey,
/// extruded walls with IfcOpeningElement voids, doors and windows filling
/// those voids, and an IfcSpace per room. Plan y maps to IFC -Y so the
/// drawing is not mirrored (plan y points down the screen, IFC Y points
/// north). Units are meters.
enum FloorPlanIFCExport {
    private static let guidChars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$")

    static func compressedGUID(_ uuid: UUID = UUID()) -> String {
        let bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
        func bit(_ j: Int) -> Int { (Int(bytes[(127 - j) / 8]) >> (j % 8)) & 1 }
        var out = ""
        for group in (0..<22).reversed() {
            var value = 0
            for i in 0..<6 {
                let j = 6 * group + i
                if j <= 127 { value |= bit(j) << i }
            }
            out.append(guidChars[value])
        }
        return out
    }

    static func escape(_ s: String) -> String {
        var out = ""
        for scalar in s.unicodeScalars {
            if scalar == "'" { out += "''" }
            else if scalar == "\\" { out += "\\\\" }
            else if scalar.value >= 32 && scalar.value < 127 { out.unicodeScalars.append(scalar) }
            else if scalar.value <= 0xFFFF && scalar.value >= 127 { out += String(format: "\\X2\\%04X\\X0\\", scalar.value) }
            else { out += "?" }
        }
        return out
    }

    private final class Writer {
        var lines: [String] = []
        @discardableResult func add(_ text: String) -> Int {
            lines.append("#\(lines.count + 1)=\(text);")
            return lines.count
        }
    }

    private static func f(_ x: Float) -> String {
        if abs(x) < 1e-6 { return "0.0" }
        var t = String(format: "%.6f", x)
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t += "0" }
        return t
    }

    static func generate(from plan: FloorPlan) -> String {
        let w = Writer()
        let name = escape(plan.name)
        func pt3(_ x: Float, _ y: Float, _ z: Float) -> Int { w.add("IFCCARTESIANPOINT((\(f(x)),\(f(y)),\(f(z))))") }
        func pt2(_ x: Float, _ y: Float) -> Int { w.add("IFCCARTESIANPOINT((\(f(x)),\(f(y))))") }
        func dir(_ x: Float, _ y: Float, _ z: Float) -> Int { w.add("IFCDIRECTION((\(f(x)),\(f(y)),\(f(z))))") }

        let origin = pt3(0, 0, 0)
        let zdir = dir(0, 0, 1)
        let axis0 = w.add("IFCAXIS2PLACEMENT3D(#\(origin),$,$)")
        let ctx = w.add("IFCGEOMETRICREPRESENTATIONCONTEXT($,'Model',3,1.E-05,#\(axis0),$)")
        let body = w.add("IFCGEOMETRICREPRESENTATIONSUBCONTEXT('Body','Model',*,*,*,*,#\(ctx),$,.MODEL_VIEW.,$)")
        let units = [
            w.add("IFCSIUNIT(*,.LENGTHUNIT.,$,.METRE.)"),
            w.add("IFCSIUNIT(*,.AREAUNIT.,$,.SQUARE_METRE.)"),
            w.add("IFCSIUNIT(*,.VOLUMEUNIT.,$,.CUBIC_METRE.)"),
            w.add("IFCSIUNIT(*,.PLANEANGLEUNIT.,$,.RADIAN.)"),
        ]
        let ua = w.add("IFCUNITASSIGNMENT((" + units.map { "#\($0)" }.joined(separator: ",") + "))")
        let proj = w.add("IFCPROJECT('\(compressedGUID())',$,'\(name)',$,$,$,$,(#\(ctx)),#\(ua))")

        func placement(rel: Int?, loc: Int, ref: Int? = nil) -> Int {
            let a = w.add("IFCAXIS2PLACEMENT3D(#\(loc),$,\(ref.map { "#\($0)" } ?? "$"))")
            return w.add("IFCLOCALPLACEMENT(\(rel.map { "#\($0)" } ?? "$"),#\(a))")
        }
        func extrusion(profile: Int, depth: Float) -> Int {
            let pos = w.add("IFCAXIS2PLACEMENT3D(#\(origin),$,$)")
            let solid = w.add("IFCEXTRUDEDAREASOLID(#\(profile),#\(pos),#\(zdir),\(f(depth)))")
            let rep = w.add("IFCSHAPEREPRESENTATION(#\(body),'Body','SweptSolid',(#\(solid)))")
            return w.add("IFCPRODUCTDEFINITIONSHAPE($,$,(#\(rep)))")
        }
        func rect(_ xdim: Float, _ ydim: Float, centerX: Float) -> Int {
            let c = pt2(centerX, 0)
            let p2 = w.add("IFCAXIS2PLACEMENT2D(#\(c),$)")
            return w.add("IFCRECTANGLEPROFILEDEF(.AREA.,$,#\(p2),\(f(xdim)),\(f(ydim)))")
        }

        let sitePl = placement(rel: nil, loc: origin)
        let site = w.add("IFCSITE('\(compressedGUID())',$,'Site',$,$,#\(sitePl),$,$,.ELEMENT.,$,$,$,$,$)")
        let bldPl = placement(rel: sitePl, loc: origin)
        let bld = w.add("IFCBUILDING('\(compressedGUID())',$,'\(name)',$,$,#\(bldPl),$,$,.ELEMENT.,$,$,$)")
        let stPl = placement(rel: bldPl, loc: origin)
        let storeyName = escape(plan.floorLevel.map { FloorLevelName.label($0) } ?? "Level 0")
        let storey = w.add("IFCBUILDINGSTOREY('\(compressedGUID())',$,'\(storeyName)',$,$,#\(stPl),$,$,.ELEMENT.,0.)")
        w.add("IFCRELAGGREGATES('\(compressedGUID())',$,$,$,#\(proj),(#\(site)))")
        w.add("IFCRELAGGREGATES('\(compressedGUID())',$,$,$,#\(site),(#\(bld)))")
        w.add("IFCRELAGGREGATES('\(compressedGUID())',$,$,$,#\(bld),(#\(storey)))")

        var contained: [Int] = []
        var wallInfo: [UUID: (wall: Int, placement: Int, height: Float, thickness: Float)] = [:]

        for wall in plan.walls where wall.lengthMeters > 0.0001 {
            let len = wall.lengthMeters
            let d = wall.direction
            let loc = pt3(wall.start.x, -wall.start.y, 0)
            let ref = dir(d.x, -d.y, 0)
            let pl = placement(rel: stPl, loc: loc, ref: ref)
            let thickness = max(wall.thickness, 0.05)
            let shape = extrusion(profile: rect(len, thickness, centerX: len / 2), depth: wall.height)
            let id = w.add("IFCWALL('\(compressedGUID(wall.id))',$,'Wall',$,$,#\(pl),#\(shape),$,.STANDARD.)")
            contained.append(id)
            wallInfo[wall.id] = (id, pl, wall.height, thickness)
        }

        for opening in plan.openings {
            guard let info = wallInfo[opening.wallID] else { continue }
            let (sill, head) = OpeningProfile.vertical(for: opening.kind, wallHeight: info.height)
            let height = head - sill
            guard height > 0.01 else { continue }
            let x = opening.distanceFromWallStart - opening.width / 2
            let voidPl = placement(rel: info.placement, loc: pt3(x, 0, sill))
            let voidShape = extrusion(profile: rect(opening.width, info.thickness + 0.02, centerX: opening.width / 2), depth: height)
            let op = w.add("IFCOPENINGELEMENT('\(compressedGUID())',$,'Opening',$,$,#\(voidPl),#\(voidShape),$,.OPENING.)")
            w.add("IFCRELVOIDSELEMENT('\(compressedGUID())',$,$,$,#\(info.wall),#\(op))")
            guard opening.kind != .opening else { continue }
            let fillPl = placement(rel: info.placement, loc: pt3(x, 0, sill))
            let fillShape = extrusion(profile: rect(opening.width, info.thickness * 0.4, centerX: opening.width / 2), depth: height)
            let element: Int
            if opening.kind == .door {
                element = w.add("IFCDOOR('\(compressedGUID())',$,'Door',$,$,#\(fillPl),#\(fillShape),$,\(f(height)),\(f(opening.width)),.DOOR.,.NOTDEFINED.,$)")
            } else {
                element = w.add("IFCWINDOW('\(compressedGUID())',$,'Window',$,$,#\(fillPl),#\(fillShape),$,\(f(height)),\(f(opening.width)),.WINDOW.,.NOTDEFINED.,$)")
            }
            w.add("IFCRELFILLSELEMENT('\(compressedGUID())',$,$,$,#\(op),#\(element))")
            contained.append(element)
        }

        let spaceHeight = plan.walls.map(\.height).max() ?? 2.4384
        for room in plan.rooms where room.polygon.count >= 3 {
            var pts = room.polygon.map { pt2($0.x, -$0.y) }
            pts.append(pts[0])
            let line = w.add("IFCPOLYLINE((" + pts.map { "#\($0)" }.joined(separator: ",") + "))")
            let profile = w.add("IFCARBITRARYCLOSEDPROFILEDEF(.AREA.,$,#\(line))")
            let shape = extrusion(profile: profile, depth: spaceHeight)
            let pl = placement(rel: stPl, loc: origin)
            let roomName = escape(room.name.isEmpty ? "Room" : room.name)
            let space = w.add("IFCSPACE('\(compressedGUID(room.id))',$,'\(roomName)',$,$,#\(pl),#\(shape),$,.ELEMENT.,.INTERNAL.,$)")
            contained.append(space)
        }

        if !contained.isEmpty {
            w.add("IFCRELCONTAINEDINSPATIALSTRUCTURE('\(compressedGUID())',$,$,$,(" + contained.map { "#\($0)" }.joined(separator: ",") + "),#\(storey))")
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: "Z", with: "")
        let header = "ISO-10303-21;\nHEADER;\nFILE_DESCRIPTION(('ViewDefinition [CoordinationView]'),'2;1');\n"
            + "FILE_NAME('\(name).ifc','\(stamp)',(''),(''),'Lexdar','Lexdar','');\nFILE_SCHEMA(('IFC4'));\nENDSEC;\nDATA;\n"
        return header + w.lines.joined(separator: "\n") + "\nENDSEC;\nEND-ISO-10303-21;\n"
    }
}
