import SceneKit
import UIKit

/// Builds recognizable 3D models for catalog items from simple shapes: sofas
/// with arms and cushions, beds with headboards and pillows, trees with
/// trunks and canopies, stairs with real treads, roofs, pools, garages, and so
/// on. Every model fits inside the item's catalog dimensions, centered on the
/// middle of that box, so placing and resizing behave like the plain box did.
/// Items with no model here fall back to the plain shape in `RoomSceneBuilder`.
/// The model is chosen from keywords in the item's id (see `kind(for:)`).
enum ItemModels {
    enum Kind {
        case sofa, sectional, ottoman, bed, bunk, table, roundTable, chair, stool
        case toilet, tub, tubFree, glassShower, vanity, pedestalSink, sink
        case cabinet, island, fridge, range, washer, hood, bookshelf, dresser
        case waterHeater, hvacUnit, fireplace, panel, pottedPlant
        case floorLamp, pendant, chandelier, ceilingFan, recessed
        case tree, conifer, palm, bush, hedge, flowers, boulder, fountain
        case pool, spa, umbrella, patioSet, chaise, trampoline, planter, fence, wroughtFence
        case gazebo, pergola, carport, garage, house, greenhouse
        case stairsStraight, stairsL, stairsU, stairsSpiral, stairsFloating, ramp
        case roofGable, roofHip, roofShed, chimney
        case foundationWalls, piers
        case door, doubleDoor, garageDoor, window
    }

    static func node(for item: CatalogItem) -> SCNNode? {
        guard let kind = kind(for: item) else { return nil }
        let parts = Parts(item.dimensions)
        let main = UIColor(item.color)
        build(kind, parts, main, item)
        guard !parts.root.childNodes.isEmpty else { return nil }
        return parts.root
    }

    // MARK: - Choosing a model from the item id

    static func kind(for item: CatalogItem) -> Kind? {
        let id = item.id
        func has(_ tokens: String...) -> Bool { tokens.contains { id.contains($0) } }
        switch item.category {
        case .flooring, .wallFinish, .exteriorFinish: return nil
        default: break
        }

        // Stairs and roofs first: their ids share words with furniture.
        if has("stairs.spiral") { return .stairsSpiral }
        if has("stairs.floating") { return .stairsFloating }
        if has("stairs.ramp") { return .ramp }
        if has("stairs.lshape", "stairs.winder") { return .stairsL }
        if has("stairs.ushape") { return .stairsU }
        if has("stairs.") { return .stairsStraight }
        if has("roof.chimney") { return .chimney }
        if has("roof.hip") { return .roofHip }
        if has("roof.shed") { return .roofShed }
        if has("roof.flat") { return nil }
        if has("roof.") { return .roofGable }
        if has("found.basement", "found.stemwall") { return .foundationWalls }
        if has("found.pier") { return .piers }
        if has("found.") { return nil }
        if has("struct.garage") { return .garage }
        if has("struct.carport") { return .carport }
        if has("struct.gazebo") { return .gazebo }
        if has("struct.pergola") { return .pergola }
        if has("struct.greenhouse") { return .greenhouse }
        if has("struct.") { return .house }

        if has("door.garage") { return .garageDoor }
        if has("door.interior.double", "door.exterior.french", "door.exterior.slidingglass") { return .doubleDoor }
        if has("door.") { return .door }
        if has("window.") { return .window }

        if has("land.tree") {
            if has("pine", "spruce", "cedar") { return .conifer }
            if has("palm") { return .palm }
            return .tree
        }
        if has("land.shrub") { return .bush }
        if has("land.hedge") { return .hedge }
        if has("land.flower") { return .flowers }
        if has("land.boulder") { return .boulder }
        if has("land.fountain") { return .fountain }
        if has("land.pond") { return .pool }
        if has("land.fence.wrought") { return .wroughtFence }
        if has("land.fence") { return .fence }
        if has("land.planter", "land.raised") { return .planter }
        if has("land.arbor") { return .pergola }

        if has("out.pool") { return .pool }
        if has("out.spa", "outdoor.hottub") { return .spa }
        if has("out.umbrella") { return .umbrella }
        if has("out.diningset") { return .patioSet }
        if has("out.chaise") { return .chaise }
        if has("out.trampoline") { return .trampoline }
        if has("out.sofa") { return .sectional }
        if has("outdoor.pergola") { return .pergola }
        if has("outdoor.shed") { return .house }
        if has("outdoor.plantings.hedge") { return .hedge }
        if has("outdoor.fence") { return .fence }
        if has("outdoor.pool.inground") { return nil }

        if has("sectional") { return .sectional }
        if has("furn.sofa", "loveseat", "armchair", "recliner", "futon") { return .sofa }
        if has("ottoman") { return .ottoman }
        if has("bed.bunk") { return .bunk }
        if has("bed.crib") { return .bed }
        if has("furn.bed") { return .bed }
        if has("barstool", "counterstool", "stool") { return .stool }
        if has("chair") { return .chair }
        if has("furn.diningtable.round", "coffeetable.round") { return .roundTable }
        if has("table", "desk", "bench", "workbench", "console.table") { return .table }
        if has("bookshelf") { return .bookshelf }
        if has("dresser", "tvstand", "credenza", "sideboard", "nightstand") { return .dresser }
        if has("wardrobe", "closet", "lockers", "cabinet", "pantry", "linencloset") { return .cabinet }

        if has("kitchen.island", "kitchen.peninsula") { return .island }
        if has("kitchen.hood") { return .hood }
        if has("kitchen.sink") { return .sink }
        if has("kitchen.counter", "kitchen.backsplash", "kitchen.faucet") { return nil }
        if has("kitchen.nook", "kitchen.bar.cart") { return .table }

        if has("bath.vanity") { return .vanity }
        if has("bath.sink.pedestal") { return .pedestalSink }
        if has("bath.toilet", "bath.bidet") { return .toilet }
        if has("bath.tub.freestanding") { return .tubFree }
        if has("bath.tub") { return .tub }
        if has("bath.shower.glass", "bath.shower.walkin") { return .glassShower }
        if has("bath.mirror", "bath.towel") { return .panel }

        if has("appliance.fridge", "appliance.freezer") { return .fridge }
        if has("appliance.range.cooktop") { return nil }
        if has("appliance.range") { return .range }
        if has("appliance.washer", "appliance.dryer", "appliance.dishwasher") { return .washer }
        if has("appliance.waterheater.tank") && !has("tankless") { return .waterHeater }
        if has("appliance.heatpump") { return .hvacUnit }
        if has("appliance.fireplace", "appliance.woodstove") { return .fireplace }

        if has("light.pendant", "light.chandelier") { return has("chandelier") ? .chandelier : .pendant }
        if has("light.ceilingfan") { return .ceilingFan }
        if has("light.recessed") { return .recessed }
        if has("light.floorlamp", "light.lamp") { return .floorLamp }

        if has("decor.plant") { return .pottedPlant }
        if has("decor.tv", "decor.art", "decor.mirror", "decor.clock") { return .panel }
        return nil
    }

    // MARK: - Building

    private static func shade(_ color: UIColor, _ factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(max(r * factor, 0), 1), green: min(max(g * factor, 0), 1),
                       blue: min(max(b * factor, 0), 1), alpha: 1)
    }

    private static let wood = UIColor(red: 0.42, green: 0.30, blue: 0.21, alpha: 1)
    private static let metal = UIColor(red: 0.72, green: 0.74, blue: 0.76, alpha: 1)
    private static let dark = UIColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1)
    private static let white = UIColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1)
    private static let glass = UIColor(red: 0.72, green: 0.88, blue: 0.94, alpha: 1)
    private static let water = UIColor(red: 0.28, green: 0.65, blue: 0.80, alpha: 1)
    private static let leaf = UIColor(red: 0.30, green: 0.50, blue: 0.24, alpha: 1)
    private static let bark = UIColor(red: 0.36, green: 0.26, blue: 0.18, alpha: 1)

    private static func build(_ kind: Kind, _ p: Parts, _ main: UIColor, _ item: CatalogItem) {
        let d = p.d
        let id = item.id
        switch kind {

        // MARK: Seating, beds, tables
        case .sofa:
            sofa(p, main)

        case .sectional:
            let armW = d.x * 0.06, backT = d.z * 0.16
            p.box(d.x, d.y * 0.32, d.z * 0.5, main, y: d.y * 0.1, z: -d.z * 0.25, chamfer: 0.03)
            p.box(d.x * 0.42, d.y * 0.32, d.z * 0.5, main, x: d.x * 0.29, y: d.y * 0.1, z: d.z * 0.25, chamfer: 0.03)
            p.box(d.x, d.y * 0.5, backT, main, y: d.y * 0.1, z: -d.z / 2 + backT / 2, chamfer: 0.03)
            p.box(armW, d.y * 0.45, d.z, main, x: -d.x / 2 + armW / 2, y: d.y * 0.1, chamfer: 0.03)
            p.box(d.x * 0.9, d.y * 0.14, d.z * 0.3, shade(main, 1.1), y: d.y * 0.42, z: -d.z * 0.2, chamfer: 0.03)
            p.box(d.x * 0.38, d.y * 0.14, d.z * 0.4, shade(main, 1.1), x: d.x * 0.29, y: d.y * 0.42, z: d.z * 0.28, chamfer: 0.03)
            for sx: Float in [-1, 1] { p.cylinder(0.03, d.y * 0.1, dark, x: sx * (d.x / 2 - 0.1), z: d.z / 2 - 0.1) }

        case .ottoman:
            p.box(d.x, d.y * 0.85, d.z, main, y: d.y * 0.15, chamfer: min(d.y, d.x) * 0.15)
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] { p.cylinder(0.025, d.y * 0.15, wood, x: sx * (d.x / 2 - 0.06), z: sz * (d.z / 2 - 0.06)) } }

        case .bed:
            let isCrib = id.contains("crib")
            p.box(d.x, d.y * 0.35, d.z, wood, y: d.y * 0.05)
            p.box(d.x * 0.96, d.y * 0.32, d.z * 0.94, white, y: d.y * 0.4, z: d.z * 0.02, chamfer: 0.03)
            p.box(d.x, d.y, 0.06, shade(wood, 1.1), z: -d.z / 2 + 0.03)
            if isCrib {
                for i in 0..<10 {
                    let x = -d.x / 2 + 0.04 + (d.x - 0.08) * Float(i) / 9
                    p.box(0.02, d.y * 0.7, 0.02, white, x: x, y: d.y * 0.3, z: d.z / 2 - 0.02)
                }
            } else {
                p.box(d.x * 0.98, 0.07, d.z * 0.58, main, y: d.y * 0.7, z: d.z * 0.18, chamfer: 0.03)
                for sx: Float in [-1, 1] {
                    p.box(d.x * 0.38, 0.12, 0.32, white, x: sx * d.x * 0.22, y: d.y * 0.72, z: -d.z / 2 + 0.3, chamfer: 0.04)
                }
            }

        case .bunk:
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                p.box(0.06, d.y, 0.06, wood, x: sx * (d.x / 2 - 0.03), z: sz * (d.z / 2 - 0.03))
            } }
            for level: Float in [0.18, 0.62] {
                p.box(d.x - 0.1, 0.1, d.z - 0.1, white, y: d.y * level, chamfer: 0.03)
                p.box(d.x - 0.06, 0.04, d.z - 0.06, wood, y: d.y * level - 0.04)
            }
            p.box(0.04, d.y * 0.25, d.z - 0.1, wood, x: d.x / 2 - 0.02, y: d.y * 0.7)

        case .table:
            let top: Float = id.contains("bench") || id.contains("nook") ? 0.05 : 0.05
            p.box(d.x, top, d.z, main, y: d.y - top, chamfer: 0.01)
            let legH = d.y - top
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                p.box(0.06, legH, 0.06, shade(main, 0.8), x: sx * (d.x / 2 - 0.07), z: sz * (d.z / 2 - 0.07))
            } }
            if id.contains("desk") || id.contains("workbench") {
                p.box(d.x * 0.3, d.y * 0.35, d.z * 0.8, shade(main, 0.9), x: d.x * 0.3, y: d.y - top - d.y * 0.35)
            }

        case .roundTable:
            let r = max(d.x, d.z) / 2
            p.cylinder(r, 0.04, main, y: d.y - 0.04)
            p.cylinder(0.06, d.y - 0.04, shade(main, 0.8))
            p.cylinder(r * 0.5, 0.03, shade(main, 0.8))

        case .chair:
            p.box(d.x, 0.05, d.z, main, y: d.y * 0.46, chamfer: 0.02)
            if !id.contains("deskchair") {
                p.box(d.x, d.y * 0.5, 0.04, main, y: d.y * 0.5, z: -d.z / 2 + 0.02, chamfer: 0.02)
                for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                    p.cylinder(0.02, d.y * 0.46, shade(main, 0.7), x: sx * (d.x / 2 - 0.04), z: sz * (d.z / 2 - 0.04))
                } }
            } else {
                p.box(d.x * 0.9, d.y * 0.45, 0.07, main, y: d.y * 0.5, z: -d.z / 2 + 0.05, chamfer: 0.03)
                p.cylinder(0.025, d.y * 0.4, dark)
                p.cylinder(d.x / 2.2, 0.03, dark)
            }

        case .stool:
            let r = max(d.x, d.z) / 2
            p.cylinder(r, 0.05, main, y: d.y - 0.05)
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                p.cylinder(0.015, d.y - 0.05, dark, x: sx * r * 0.6, z: sz * r * 0.6)
            } }

        case .bookshelf:
            p.box(d.x, d.y, 0.02, shade(main, 0.85), z: -d.z / 2 + 0.01)
            for sx: Float in [-1, 1] { p.box(0.03, d.y, d.z, main, x: sx * (d.x / 2 - 0.015)) }
            let shelves = max(3, Int(d.y / 0.36))
            for i in 0...shelves { p.box(d.x, 0.03, d.z, main, y: (d.y - 0.03) * Float(i) / Float(shelves)) }
            let colors: [UIColor] = [UIColor(red: 0.6, green: 0.2, blue: 0.2, alpha: 1), UIColor(red: 0.2, green: 0.35, blue: 0.55, alpha: 1),
                                     UIColor(red: 0.85, green: 0.75, blue: 0.5, alpha: 1), UIColor(red: 0.25, green: 0.45, blue: 0.3, alpha: 1)]
            for s in 0..<shelves {
                let y = (d.y - 0.03) * Float(s) / Float(shelves) + 0.03
                let slot = (d.y - 0.03) / Float(shelves) - 0.06
                for b in 0..<5 {
                    let x = -d.x / 2 + 0.1 + (d.x - 0.2) * Float(b) / 5
                    p.box(0.04, slot * (0.7 + 0.08 * Float(b % 3)), d.z * 0.6, colors[(s + b) % colors.count], x: x, y: y, z: 0.02)
                }
            }

        case .dresser:
            p.box(d.x, d.y, d.z, main, chamfer: 0.01)
            let rows = d.y > 1 ? 5 : (d.y > 0.5 ? 3 : 2)
            for r in 1..<rows {
                p.box(d.x * 0.94, 0.008, 0.006, dark, y: d.y * Float(r) / Float(rows), z: d.z / 2)
            }
            for r in 0..<rows {
                p.sphere(0.017, metal, x: 0, y: d.y * (Float(r) + 0.5) / Float(rows), z: d.z / 2 + 0.015)
            }

        case .cabinet:
            p.box(d.x, d.y, d.z, main, chamfer: 0.005)
            let doors = max(1, Int((d.x / 0.5).rounded()))
            for i in 1..<max(doors, 1) {
                p.box(0.008, d.y * 0.94, 0.006, dark, x: -d.x / 2 + d.x * Float(i) / Float(doors), y: d.y * 0.03, z: d.z / 2)
            }
            for i in 0..<doors {
                let x = -d.x / 2 + d.x * (Float(i) + (i % 2 == 0 ? 0.88 : 0.12)) / Float(doors)
                p.box(0.012, min(0.16, d.y * 0.2), 0.02, metal, x: x, y: d.y > 1.5 ? d.y * 0.5 : d.y * 0.7, z: d.z / 2 + 0.01)
            }
            if id.contains("cabinets.base") || id.contains("kitchen.cabinets.base") {
                p.box(d.x + 0.02, 0.035, d.z + 0.02, UIColor(red: 0.93, green: 0.92, blue: 0.9, alpha: 1), y: d.y - 0.01)
            }

        case .island:
            p.box(d.x * 0.97, d.y - 0.04, d.z * 0.8, main, z: -d.z * 0.1)
            p.box(d.x, 0.045, d.z, UIColor(red: 0.94, green: 0.93, blue: 0.9, alpha: 1), y: d.y - 0.045, chamfer: 0.005)
            if id.contains("waterfall") {
                for sx: Float in [-1, 1] { p.box(0.04, d.y - 0.04, d.z * 0.9, UIColor(red: 0.94, green: 0.93, blue: 0.9, alpha: 1), x: sx * (d.x / 2 - 0.02)) }
            }
            if id.contains("seating") || id.contains("peninsula") || id.contains("island") {
                let n = max(2, Int(d.x / 0.7))
                for i in 0..<n {
                    let x = -d.x / 2 + d.x * (Float(i) + 0.5) / Float(n)
                    p.cylinder(0.17, 0.04, dark, x: x, y: 0.62, z: d.z / 2 + 0.2)
                    p.cylinder(0.02, 0.62, metal, x: x, z: d.z / 2 + 0.2)
                }
            }

        // MARK: Bath and kitchen fixtures
        case .toilet:
            let wall = id.contains("wallhung") || id.contains("bidet")
            p.box(d.x, d.y * 0.38, d.z * 0.7, white, y: wall ? d.y * 0.2 : 0, z: d.z * 0.15, chamfer: 0.05)
            if !id.contains("bidet") {
                p.box(d.x, d.y * 0.5, d.z * 0.22, white, y: d.y * 0.4, z: -d.z / 2 + d.z * 0.11, chamfer: 0.02)
            }
            p.box(d.x * 0.88, 0.025, d.z * 0.55, shade(white, 0.96), y: (wall ? d.y * 0.2 : 0) + d.y * 0.38, z: d.z * 0.17, chamfer: 0.01)

        case .tub:
            p.box(d.x, d.y, d.z, white, chamfer: 0.04)
            p.box(d.x - 0.14, 0.012, d.z - 0.14, UIColor(red: 0.88, green: 0.93, blue: 0.95, alpha: 1), y: d.y)
            p.cylinder(0.02, 0.2, metal, x: -d.x / 2 + 0.12, y: d.y, z: 0)

        case .tubFree:
            let chamfer = min(d.y, d.z) * 0.45
            p.box(d.x, d.y * 0.9, d.z, white, y: d.y * 0.1, chamfer: chamfer)
            p.box(d.x * 0.7, 0.012, d.z * 0.5, UIColor(red: 0.88, green: 0.93, blue: 0.95, alpha: 1), y: d.y - 0.015)
            if id.contains("clawfoot") || id.contains("slipper") {
                for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                    p.sphere(0.05, UIColor(red: 0.8, green: 0.7, blue: 0.4, alpha: 1), x: sx * d.x * 0.38, y: 0, z: sz * d.z * 0.28)
                } }
            } else {
                p.box(d.x * 0.8, d.y * 0.1, d.z * 0.7, shade(white, 0.9), y: 0, chamfer: 0.02)
            }
            p.cylinder(0.015, d.y * 1.0, metal, x: d.x / 2 - 0.12, z: 0)

        case .glassShower:
            let t: Float = 0.012
            p.box(d.x, 0.07, d.z, white, chamfer: 0.01)
            let h = d.y - 0.07
            p.box(d.x, h, t, glass, y: 0.07, z: d.z / 2 - t / 2, alpha: 0.28)
            p.box(t, h, d.z, glass, x: d.x / 2 - t / 2, y: 0.07, alpha: 0.28)
            if id.contains("neoangle") || id.contains("large") || id.contains("steam") {
                p.box(t, h, d.z, glass, x: -d.x / 2 + t / 2, y: 0.07, alpha: 0.28)
            }
            p.cylinder(0.012, h * 0.55, metal, x: d.x * 0.2, y: 0.07 + h * 0.1, z: d.z / 2 - 0.03)
            p.cylinder(0.012, 0.5, metal, x: -d.x * 0.3, y: 0.07 + h * 0.4, z: -d.z / 2 + 0.04)
            p.cylinder(0.08, 0.015, metal, x: -d.x * 0.3, y: d.y - 0.2, z: -d.z / 2 + 0.2)

        case .vanity:
            let counterT: Float = 0.04
            let floating = id.contains("floating")
            let lift: Float = floating ? 0.3 : 0
            p.box(d.x, d.y - counterT - lift, d.z, main, y: lift, chamfer: 0.005)
            p.box(d.x + 0.02, counterT, d.z + 0.02, white, y: d.y - counterT)
            let basins = id.contains("double") ? 2 : 1
            for i in 0..<basins {
                let x = basins == 1 ? 0 : (i == 0 ? -d.x * 0.25 : d.x * 0.25)
                if id.contains("vessel") {
                    p.cylinder(0.2, 0.12, white, x: x, y: d.y)
                } else {
                    p.box(min(0.5, d.x * 0.4), 0.012, d.z * 0.65, UIColor(red: 0.85, green: 0.88, blue: 0.9, alpha: 1), x: x, y: d.y)
                }
                p.cylinder(0.015, 0.2, metal, x: x, y: d.y, z: -d.z / 2 + 0.08)
            }
            for i in 0..<(basins * 2) {
                let x = -d.x / 2 + d.x * (Float(i) + 0.5) / Float(basins * 2)
                p.box(d.x / Float(basins * 2) - 0.02, d.y * 0.4, 0.006, shade(main, 0.85), x: x, y: lift + 0.04, z: d.z / 2)
            }

        case .pedestalSink:
            p.cylinder(min(d.x, d.z) * 0.18, d.y * 0.7, white)
            p.box(d.x, d.y * 0.25, d.z, white, y: d.y * 0.7, chamfer: 0.04)
            p.cylinder(0.015, 0.18, metal, y: d.y * 0.95, z: -d.z / 2 + 0.07)

        case .sink:
            p.box(d.x, d.y, d.z, id.contains("stainless") || id.contains("workstation") ? metal : white, chamfer: 0.03)
            p.box(d.x * 0.88, 0.01, d.z * 0.8, shade(metal, 0.7), y: d.y)
            p.cylinder(0.015, 0.3, metal, y: d.y, z: -d.z / 2 + 0.05)

        case .hood:
            if d.y > 0.4 {
                p.box(d.x, d.y * 0.3, d.z, main, y: 0, chamfer: 0.02)
                p.box(d.x * 0.4, d.y * 0.7, d.z * 0.5, main, y: d.y * 0.3, z: id.contains("island") ? 0 : -d.z * 0.25)
            } else {
                p.box(d.x, d.y, d.z, main, chamfer: 0.02)
            }

        // MARK: Appliances
        case .fridge:
            p.box(d.x, d.y, d.z, main, chamfer: 0.02)
            if id.contains("sidebyside") || id.contains("frenchdoor") || id.contains("undercounter") == false {
                p.box(0.008, d.y * 0.62, 0.006, dark, y: d.y * 0.36, z: d.z / 2)
                p.box(d.x * 0.98, 0.008, 0.006, dark, y: d.y * 0.34, z: d.z / 2)
                p.box(0.02, d.y * 0.25, 0.03, metal, x: -d.x * 0.08, y: d.y * 0.6, z: d.z / 2 + 0.015)
                p.box(0.02, d.y * 0.25, 0.03, metal, x: d.x * 0.08, y: d.y * 0.6, z: d.z / 2 + 0.015)
            }

        case .range:
            p.box(d.x, d.y, d.z, main, chamfer: 0.01)
            p.box(d.x * 0.7, d.y * 0.3, 0.008, UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1), y: d.y * 0.25, z: d.z / 2)
            p.box(d.x * 0.6, 0.02, 0.02, metal, y: d.y * 0.62, z: d.z / 2 + 0.02)
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                p.cylinder(0.07, 0.012, dark, x: sx * d.x * 0.22, y: d.y, z: sz * d.z * 0.2)
            } }

        case .washer:
            p.box(d.x, d.y, d.z, main, chamfer: 0.02)
            if id.contains("dishwasher") {
                p.box(d.x * 0.85, 0.02, 0.02, metal, y: d.y * 0.85, z: d.z / 2 + 0.01)
            } else {
                let door = p.cylinder(min(d.x, d.y) * 0.34, 0.02, glass, y: d.y * (id.contains("stacked") ? 0.2 : 0.4), z: d.z / 2)
                door.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
                door.position.z = d.z / 2
            }

        case .waterHeater:
            p.cylinder(min(d.x, d.z) / 2, d.y, main)
            p.cylinder(0.02, 0.12, metal, x: -d.x * 0.2, y: d.y)
            p.cylinder(0.02, 0.12, metal, x: d.x * 0.2, y: d.y)

        case .hvacUnit:
            p.box(d.x, d.y, d.z, main, chamfer: 0.02)
            p.cylinder(min(d.x, d.z) * 0.38, 0.02, dark, y: d.y)
            for i in 0..<6 { p.box(d.x * 0.9, 0.012, 0.01, shade(main, 0.7), y: d.y * (0.15 + 0.12 * Float(i)), z: d.z / 2) }

        case .fireplace:
            p.box(d.x, d.y, d.z, main, chamfer: 0.01)
            p.box(d.x * 0.5, d.y * 0.45, 0.02, UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1), y: d.y * 0.15, z: d.z / 2)
            p.box(d.x * 1.06, 0.05, d.z * 1.2, wood, y: d.y * 0.78)

        // MARK: Panels (TVs, mirrors, art)
        case .panel:
            let frame: Float = 0.03
            let isTV = id.contains("tv")
            let isMirror = id.contains("mirror")
            p.box(d.x, d.y, d.z, isTV ? dark : (isMirror ? metal : wood), chamfer: 0.005)
            p.box(d.x - frame * 2, d.y - frame * 2, 0.004, isTV ? UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1) : (isMirror ? glass : main),
                  y: frame, z: d.z / 2)

        case .pottedPlant:
            let potH = d.y * 0.22
            p.cylinder(d.x * 0.3, potH, UIColor(red: 0.7, green: 0.45, blue: 0.32, alpha: 1))
            p.cylinder(d.x * 0.02, d.y * 0.4, UIColor(red: 0.3, green: 0.4, blue: 0.2, alpha: 1), y: potH)
            let offsets: [(Float, Float, Float)] = [(0, 0.78, 0), (0.18, 0.62, 0.05), (-0.18, 0.66, -0.05), (0.05, 0.5, 0.15), (-0.08, 0.9, 0.05)]
            for o in offsets { p.sphere(d.x * 0.24, main, x: o.0 * d.x, y: d.y * o.1 - d.x * 0.24, z: o.2 * d.z, squash: 0.9) }

        // MARK: Lights
        case .floorLamp:
            p.cylinder(d.x * 0.3, 0.02, dark)
            p.cylinder(0.012, d.y * 0.7, dark, y: 0.02)
            p.cone(d.x * 0.22, d.x * 0.45, d.y * 0.25, UIColor(red: 0.96, green: 0.92, blue: 0.82, alpha: 1), y: d.y * 0.75, glow: true)

        case .pendant:
            let n = id.contains("cluster") ? 3 : (id.contains("linear") ? 4 : 1)
            let span: Float = id.contains("linear") ? d.x * 0.8 : d.x * 0.5
            for i in 0..<n {
                let x = n == 1 ? 0 : -span / 2 + span * Float(i) / Float(n - 1)
                let drop: Float = id.contains("cluster") ? d.y * (0.45 + 0.2 * Float(i % 2)) : d.y * 0.5
                p.cylinder(0.004, d.y - drop, dark, x: x, y: drop)
                p.cone(min(0.08, d.x * 0.2), min(0.16, d.x * 0.4), d.y * 0.4, main, x: x, y: drop - d.y * 0.38 + (d.y * 0.38 - d.y * 0.38), glow: false)
                p.sphere(0.03, UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1), x: x, y: max(0, drop - d.y * 0.4 - 0.02), glow: true)
            }

        case .chandelier:
            let r = d.x / 2
            let ring = SCNTorus(ringRadius: CGFloat(r * 0.85), pipeRadius: 0.015)
            p.add(ring, main, x: 0, bottom: d.y * 0.2, z: 0)
            for i in 0..<6 {
                let a = Float(i) / 6 * 2 * .pi
                p.sphere(0.03, UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1), x: cos(a) * r * 0.85, y: d.y * 0.2 + 0.02, z: sin(a) * r * 0.85, glow: true)
            }
            for a: Float in [0, 2.1, 4.2] {
                p.cylinder(0.006, d.y * 0.8, dark, x: cos(a) * r * 0.3, y: d.y * 0.2, z: sin(a) * r * 0.3)
            }
            p.cylinder(0.07, 0.03, main, y: d.y - 0.03)

        case .ceilingFan:
            p.cylinder(0.08, 0.1, wood, y: d.y - 0.15)
            p.cylinder(0.012, 0.12, dark, y: d.y - 0.03)
            for i in 0..<4 {
                let a = Float(i) / 4 * 2 * .pi
                let blade = p.box(d.x * 0.45, 0.012, 0.12, main, x: cos(a) * d.x * 0.3, y: d.y - 0.12, z: -sin(a) * d.x * 0.3)
                blade.eulerAngles = SCNVector3(0, a, 0)
            }
            p.sphere(0.07, UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1), y: d.y - 0.27, glow: true)

        case .recessed:
            p.cylinder(d.x / 2, d.y * 0.4, UIColor(white: 0.9, alpha: 1), y: d.y * 0.6)
            p.cylinder(d.x * 0.33, d.y * 0.2, UIColor(red: 1, green: 0.96, blue: 0.85, alpha: 1), y: d.y * 0.58, glow: true)

        // MARK: Landscaping
        case .tree:
            let trunkH = d.y * 0.4
            p.cylinder(max(0.08, d.x * 0.035), trunkH, bark)
            let r = d.x * 0.36
            let top = trunkH * 0.85
            p.sphere(r, main, y: top, squash: 0.85)
            p.sphere(r * 0.7, shade(main, 1.1), x: r * 0.7, y: top + r * 0.35, z: r * 0.2, squash: 0.85)
            p.sphere(r * 0.7, shade(main, 0.9), x: -r * 0.65, y: top + r * 0.25, z: -r * 0.3, squash: 0.85)
            p.sphere(r * 0.65, shade(main, 1.05), x: r * 0.1, y: top + r * 0.9, z: -r * 0.5, squash: 0.85)
            p.sphere(r * 0.6, shade(main, 0.95), x: -r * 0.2, y: top + r * 0.4, z: r * 0.7, squash: 0.85)

        case .conifer:
            p.cylinder(max(0.06, d.x * 0.04), d.y * 0.15, bark)
            let tiers: [(Float, Float, Float)] = [(0.5, 0.12, 0.38), (0.4, 0.32, 0.36), (0.3, 0.5, 0.32), (0.2, 0.68, 0.32)]
            for t in tiers { p.cone(0, d.x * t.0, d.y * t.2, shade(main, 0.9 + CGFloat(t.1) * 0.2), y: d.y * t.1) }

        case .palm:
            p.cylinder(max(0.1, d.x * 0.04), d.y * 0.78, bark)
            for i in 0..<7 {
                let a = Float(i) / 7 * 2 * .pi
                let arm = SCNNode()
                arm.position = SCNVector3(0, d.y * 0.78 - d.y / 2, 0)
                arm.eulerAngles = SCNVector3(0, a, 0)
                let frond = SCNNode(geometry: SCNBox(width: CGFloat(d.x * 0.48), height: 0.03, length: 0.35, chamferRadius: 0))
                frond.geometry?.firstMaterial?.diffuse.contents = main
                frond.position = SCNVector3(d.x * 0.22, 0, 0)
                frond.eulerAngles = SCNVector3(0, 0, -0.4)
                arm.addChildNode(frond)
                p.root.addChildNode(arm)
            }

        case .bush:
            let r = d.x * 0.32
            p.sphere(r, main, y: d.y * 0.1, squash: d.y / (2 * r) * 0.95)
            p.sphere(r * 0.75, shade(main, 1.1), x: r * 0.8, y: d.y * 0.05, z: r * 0.2, squash: 0.9)
            p.sphere(r * 0.75, shade(main, 0.9), x: -r * 0.8, y: d.y * 0.05, z: -r * 0.2, squash: 0.9)
            p.sphere(r * 0.7, shade(main, 1.05), x: 0, y: d.y * 0.05, z: r * 0.85, squash: 0.9)

        case .hedge:
            p.box(d.x, d.y, d.z, main, chamfer: min(d.y, d.z) * 0.3)

        case .flowers:
            p.box(d.x, 0.1, d.z, UIColor(red: 0.28, green: 0.2, blue: 0.14, alpha: 1))
            p.box(d.x * 0.96, d.y * 0.5, d.z * 0.9, UIColor(red: 0.3, green: 0.5, blue: 0.25, alpha: 1), y: 0.1, chamfer: 0.05)
            var seed: UInt32 = 7
            func rnd() -> Float { seed = seed &* 1664525 &+ 1013904223; return Float(seed >> 8) / Float(1 << 24) }
            let palette: [UIColor] = [main, shade(main, 1.15), UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1), UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)]
            for i in 0..<34 {
                let x = (rnd() - 0.5) * d.x * 0.9
                let z = (rnd() - 0.5) * d.z * 0.8
                let h = d.y * (0.5 + rnd() * 0.45)
                p.cylinder(0.006, h - 0.1, UIColor(red: 0.25, green: 0.45, blue: 0.2, alpha: 1), x: x, y: 0.1, z: z)
                p.sphere(0.045, palette[i % palette.count], x: x, y: h - 0.04, z: z)
            }

        case .boulder:
            p.sphere(d.x * 0.5, main, y: 0, squash: d.y / d.x)
            p.sphere(d.x * 0.3, shade(main, 1.1), x: d.x * 0.35, y: 0, z: d.z * 0.2, squash: 0.8)

        case .fountain:
            p.cylinder(d.x / 2, 0.25, main)
            p.cylinder(d.x / 2 - 0.08, 0.02, water, y: 0.25)
            p.cylinder(0.1, d.y * 0.6, main, y: 0.25)
            p.cylinder(d.x * 0.28, 0.1, main, y: d.y * 0.6)
            p.cylinder(d.x * 0.24, 0.02, water, y: d.y * 0.6 + 0.1)
            p.cylinder(0.04, d.y * 0.25, main, y: d.y * 0.6 + 0.1)

        // MARK: Outdoor living
        case .pool:
            let ink = UIColor(red: 0.8, green: 0.8, blue: 0.78, alpha: 1)
            p.box(d.x, d.y * 0.4, d.z, ink, chamfer: 0.04)
            p.box(d.x - 0.7, d.y * 0.3, d.z - 0.7, water, y: d.y * 0.4, alpha: 0.85, glow: true)

        case .spa:
            let r = max(d.x, d.z) / 2
            p.cylinder(r, d.y, main)
            p.cylinder(r - 0.12, 0.02, water, y: d.y, alpha: 0.9, glow: true)

        case .umbrella:
            p.cylinder(0.03, d.y * 0.92, wood)
            p.cone(0.02, d.x / 2, d.y * 0.18, main, y: d.y * 0.82)
            p.cylinder(0.2, 0.04, dark)

        case .patioSet:
            let top = d.y * 0.82
            p.box(d.x * 0.62, 0.05, d.z * 0.55, main, y: top)
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                p.box(0.06, top, 0.06, shade(main, 0.8), x: sx * d.x * 0.27, z: sz * d.z * 0.22)
            } }
            for i in 0..<3 {
                let x = -d.x * 0.2 + d.x * 0.2 * Float(i)
                for sz: Float in [-1, 1] {
                    p.box(0.45, 0.05, 0.45, UIColor(red: 0.85, green: 0.83, blue: 0.78, alpha: 1), x: x, y: d.y * 0.5, z: sz * d.z * 0.42)
                    p.box(0.45, 0.4, 0.04, UIColor(red: 0.85, green: 0.83, blue: 0.78, alpha: 1), x: x, y: d.y * 0.5, z: sz * (d.z * 0.42 + 0.22))
                }
            }

        case .chaise:
            p.box(d.x, 0.08, d.z * 0.62, main, y: d.y * 0.4, z: d.z * 0.19, chamfer: 0.03)
            let back = p.box(d.x, 0.08, d.z * 0.4, main, y: d.y * 0.62, z: -d.z * 0.3, chamfer: 0.03)
            back.eulerAngles = SCNVector3(0.9, 0, 0)
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] { p.cylinder(0.02, d.y * 0.4, metal, x: sx * (d.x / 2 - 0.05), z: sz * d.z * 0.35) } }

        case .trampoline:
            let r = max(d.x, d.z) / 2
            p.cylinder(r * 0.92, 0.03, dark, y: d.y * 0.55)
            p.add(SCNTorus(ringRadius: CGFloat(r * 0.95), pipeRadius: 0.04), UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1), x: 0, bottom: d.y * 0.55, z: 0)
            for i in 0..<8 {
                let a = Float(i) / 8 * 2 * .pi
                p.cylinder(0.03, d.y * 0.55, metal, x: cos(a) * r * 0.95, z: sin(a) * r * 0.95)
            }

        case .planter:
            if id.contains("raised") {
                p.box(d.x, d.y, d.z, wood)
                p.box(d.x - 0.08, 0.02, d.z - 0.08, UIColor(red: 0.28, green: 0.2, blue: 0.14, alpha: 1), y: d.y * 0.85)
            } else {
                p.cylinder(d.x / 2, d.y * 0.6, main)
                p.sphere(d.x * 0.38, leaf, y: d.y * 0.55, squash: 0.9)
            }

        case .fence:
            let n = max(4, Int(d.x / 0.12))
            for i in 0..<n {
                let x = -d.x / 2 + 0.04 + (d.x - 0.08) * Float(i) / Float(n - 1)
                p.box(d.x / Float(n) * 0.75, d.y * (id.contains("chainlink") ? 1 : 0.95), d.z, main, x: x)
            }
            for y: Float in [0.2, 0.75] { p.box(d.x, 0.06, d.z * 1.3, shade(main, 0.9), y: d.y * y) }

        case .wroughtFence:
            let n = max(6, Int(d.x / 0.1))
            for i in 0..<n {
                let x = -d.x / 2 + 0.03 + (d.x - 0.06) * Float(i) / Float(n - 1)
                p.box(0.015, d.y, 0.015, main, x: x)
                p.sphere(0.02, main, x: x, y: d.y - 0.01)
            }
            for y: Float in [0.1, 0.85] { p.box(d.x, 0.03, 0.03, main, y: d.y * y) }

        // MARK: Structures
        case .gazebo:
            let r = d.x / 2
            p.cylinder(r, 0.12, UIColor(red: 0.55, green: 0.42, blue: 0.3, alpha: 1))
            for i in 0..<6 {
                let a = Float(i) / 6 * 2 * .pi
                p.box(0.12, d.y * 0.72, 0.12, main, x: cos(a) * (r - 0.15), y: 0.12, z: sin(a) * (r - 0.15))
            }
            p.cone(0.06, r * 1.15, d.y * 0.28, shade(main, 0.6), y: d.y * 0.72 + 0.12)

        case .pergola, .carport:
            let postH = d.y * (kind == .carport ? 1 : 0.92)
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                p.box(0.16, postH, 0.16, main, x: sx * (d.x / 2 - 0.1), z: sz * (d.z / 2 - 0.1))
            } }
            if kind == .carport {
                p.box(d.x, 0.1, d.z, shade(main, 0.8), y: d.y - 0.1)
            } else {
                for sz: Float in [-1, 1] { p.box(d.x, 0.14, 0.1, main, y: postH - 0.05, z: sz * (d.z / 2 - 0.1)) }
                let n = max(5, Int(d.z / 0.3))
                for i in 0..<n {
                    p.box(d.x * 0.95, 0.08, 0.07, shade(main, 1.05), y: d.y - 0.08, z: -d.z / 2 + 0.15 + (d.z - 0.3) * Float(i) / Float(n - 1))
                }
            }

        case .garage, .house, .greenhouse:
            let bodyH = d.y * (kind == .greenhouse ? 0.62 : 0.66)
            if kind == .greenhouse {
                p.box(d.x, bodyH, d.z, glass, alpha: 0.35)
                for sx: Float in [-1, 1] { for sz: Float in [-1, 1] { p.box(0.05, bodyH, 0.05, metal, x: sx * d.x / 2, z: sz * d.z / 2) } }
            } else {
                p.box(d.x, bodyH, d.z, main, chamfer: 0.01)
            }
            let roofColor: UIColor = kind == .greenhouse ? glass : (id.contains("barn") ? dark : UIColor(red: 0.3, green: 0.31, blue: 0.33, alpha: 1))
            p.gable(d.x + 0.3, d.y - bodyH, d.z + 0.3, roofColor, y: bodyH, alpha: kind == .greenhouse ? 0.4 : 1)
            if kind == .garage {
                let dw = d.x > 4.5 ? d.x * 0.78 : d.x * 0.8
                p.box(dw, bodyH * 0.8, 0.04, UIColor(red: 0.93, green: 0.91, blue: 0.86, alpha: 1), y: 0, z: d.z / 2)
                for i in 1..<4 { p.box(dw, 0.012, 0.02, UIColor(white: 0.6, alpha: 1), y: bodyH * 0.8 * Float(i) / 4, z: d.z / 2 + 0.02) }
            } else if kind == .house {
                p.box(min(0.95, d.x * 0.3), min(2.05, bodyH * 0.85), 0.04, wood, x: -d.x * 0.2, z: d.z / 2)
                p.box(min(1.1, d.x * 0.25), min(1.1, bodyH * 0.4), 0.03, glass, x: d.x * 0.22, y: bodyH * 0.4, z: d.z / 2, alpha: 0.5)
            }

        // MARK: Stairs
        case .stairsStraight:
            let n = max(4, Int((d.y / 0.18).rounded()))
            flight(p, count: n, width: d.x, run: d.z / Float(n), rise: d.y / Float(n), baseH: 0,
                   sx: 0, sz: d.z / 2, dirX: 0, dirZ: -1, color: main)
            if !id.contains("basement") && !id.contains("porch") && !id.contains("deck") {
                for sx: Float in [-1, 1] { p.box(0.04, 0.04, d.z, wood, x: sx * (d.x / 2 - 0.02), y: d.y * 0.92) }
            }

        case .stairsL:
            let n = max(6, Int((d.y / 0.18).rounded()))
            let half = n / 2
            let rise = d.y / Float(n)
            let lw = min(1.0, d.x * 0.5)
            let len1 = d.z - lw
            flight(p, count: half, width: lw, run: len1 / Float(half), rise: rise, baseH: 0,
                   sx: -d.x / 2 + lw / 2, sz: d.z / 2, dirX: 0, dirZ: -1, color: main)
            p.box(lw, rise * Float(half), lw, main, x: -d.x / 2 + lw / 2, z: -d.z / 2 + lw / 2)
            flight(p, count: n - half, width: lw, run: (d.x - lw) / Float(n - half), rise: rise, baseH: rise * Float(half),
                   sx: -d.x / 2 + lw, sz: -d.z / 2 + lw / 2, dirX: 1, dirZ: 0, color: main)

        case .stairsU:
            let n = max(6, Int((d.y / 0.18).rounded()))
            let half = n / 2
            let rise = d.y / Float(n)
            let lw = min(1.0, d.z * 0.3)
            let fw = d.x / 2 - 0.03
            flight(p, count: half, width: fw, run: (d.z - lw) / Float(half), rise: rise, baseH: 0,
                   sx: -d.x / 4, sz: d.z / 2, dirX: 0, dirZ: -1, color: main)
            p.box(d.x, rise * Float(half), lw, main, z: -d.z / 2 + lw / 2)
            flight(p, count: n - half, width: fw, run: (d.z - lw) / Float(n - half), rise: rise, baseH: rise * Float(half),
                   sx: d.x / 4, sz: -d.z / 2 + lw, dirX: 0, dirZ: 1, color: main)

        case .stairsSpiral:
            let n = max(8, Int((d.y / 0.2).rounded()))
            let rise = d.y / Float(n)
            let r = min(d.x, d.z) / 2
            p.cylinder(0.08, d.y + 0.9, id.contains("wood") ? dark : main)
            for i in 0..<n {
                let arm = SCNNode()
                arm.position = SCNVector3(0, rise * Float(i + 1) - d.y / 2 - 0.025, 0)
                arm.eulerAngles = SCNVector3(0, Float(i) * (5.8 / Float(n)), 0)
                let tread = SCNNode(geometry: SCNBox(width: CGFloat(r - 0.05), height: 0.05, length: 0.4, chamferRadius: 0.005))
                tread.geometry?.firstMaterial?.diffuse.contents = main
                tread.position = SCNVector3((r + 0.05) / 2, 0, 0)
                arm.addChildNode(tread)
                p.root.addChildNode(arm)
            }

        case .stairsFloating:
            let n = max(4, Int((d.y / 0.19).rounded()))
            let run = d.z / Float(n)
            for i in 0..<n {
                p.box(d.x, 0.05, run * 0.95, main, y: d.y / Float(n) * Float(i + 1) - 0.05, z: d.z / 2 - run * (Float(i) + 0.5))
            }
            p.box(0.05, d.y, 0.08, dark, x: -d.x / 2 + 0.025, y: 0, z: -d.z / 2 + 0.04)

        case .ramp:
            let slope = atan2(d.y, d.z)
            let length = sqrt(d.y * d.y + d.z * d.z)
            let node = p.box(d.x, 0.1, length, main, y: 0)
            node.eulerAngles = SCNVector3(-slope, 0, 0)
            node.position = SCNVector3(0, 0, 0)
            for sx: Float in [-1, 1] {
                let rail = p.box(0.04, 0.04, length, metal, x: sx * (d.x / 2 - 0.02), y: 0)
                rail.eulerAngles = SCNVector3(-slope, 0, 0)
                rail.position = SCNVector3(sx * (d.x / 2 - 0.02), 0.9, 0)
            }

        // MARK: Roofs and foundations
        case .roofGable:
            let node = p.gable(d.x, d.y, d.z, main, y: 0)
            applyRoofTexture(node, item, d)
            p.box(0.1, 0.06, d.z, shade(main, 0.7), y: d.y - 0.03)

        case .roofHip:
            let node = p.pyramid(d.x, d.y, d.z, main, y: 0)
            applyRoofTexture(node, item, d)

        case .roofShed:
            let slope = atan2(d.y, d.z)
            let length = sqrt(d.y * d.y + d.z * d.z)
            let node = p.box(d.x, 0.14, length, main, y: 0)
            node.eulerAngles = SCNVector3(-slope, 0, 0)
            node.position = SCNVector3(0, 0, 0)
            applyRoofTexture(node, item, d)
            for sx: Float in [-1, 1] { p.box(0.1, d.y * 0.7, 0.1, shade(main, 0.7), x: sx * (d.x / 2 - 0.1), z: -d.z / 2 + 0.1) }

        case .chimney:
            p.box(d.x, d.y, d.z, main)
            p.box(d.x * 1.2, 0.08, d.z * 1.2, shade(main, 0.7), y: d.y - 0.04)
            p.box(d.x * 0.55, 0.01, d.z * 0.55, UIColor(white: 0.05, alpha: 1), y: d.y + 0.04)

        case .foundationWalls:
            let t: Float = 0.22
            let slab = UIColor(red: 0.7, green: 0.7, blue: 0.68, alpha: 1)
            p.box(d.x, 0.12, d.z, slab)
            p.box(d.x, d.y, t, main, z: -d.z / 2 + t / 2)
            p.box(d.x, d.y, t, main, z: d.z / 2 - t / 2)
            p.box(t, d.y, d.z - 2 * t, main, x: -d.x / 2 + t / 2)
            p.box(t, d.y, d.z - 2 * t, main, x: d.x / 2 - t / 2)

        case .piers:
            p.box(d.x, 0.2, 0.2, UIColor(red: 0.45, green: 0.35, blue: 0.27, alpha: 1), y: d.y - 0.2, z: -d.z / 2 + 0.1)
            p.box(d.x, 0.2, 0.2, UIColor(red: 0.45, green: 0.35, blue: 0.27, alpha: 1), y: d.y - 0.2, z: d.z / 2 - 0.1)
            let nx = max(2, Int(d.x / 2.0)), nz = max(2, Int(d.z / 2.0))
            for i in 0...nx { for j in 0...nz {
                let x = -d.x / 2 + 0.15 + (d.x - 0.3) * Float(i) / Float(nx)
                let z = -d.z / 2 + 0.15 + (d.z - 0.3) * Float(j) / Float(nz)
                p.cylinder(0.12, d.y - 0.2, main, x: x, z: z)
            } }

        // MARK: Doors and windows
        case .door:
            let frame: Float = 0.05
            p.box(d.x, d.y, 0.07, white)
            let panelColor = main
            p.box(d.x - frame * 2, d.y - frame, 0.045, panelColor, y: 0, z: 0.012)
            if !id.contains("flush") && !id.contains("barn") {
                p.box((d.x - 0.3) * 0.5, d.y * 0.34, 0.01, shade(panelColor, 0.88), x: 0, y: d.y * 0.55, z: 0.04)
                p.box((d.x - 0.3) * 0.5, d.y * 0.28, 0.01, shade(panelColor, 0.88), x: 0, y: d.y * 0.12, z: 0.04)
            }
            p.sphere(0.03, UIColor(red: 0.85, green: 0.75, blue: 0.4, alpha: 1), x: d.x * 0.36, y: 0.95, z: 0.05)

        case .doubleDoor:
            let sliding = id.contains("sliding")
            p.box(d.x, d.y, 0.08, sliding ? dark : white)
            for sx: Float in [-1, 1] {
                p.box(d.x / 2 - 0.05, d.y - 0.08, 0.03, sliding ? glass : main, x: sx * (d.x / 4), y: 0.02, z: sliding ? sx * 0.01 : 0.02,
                      alpha: sliding ? 0.45 : 1)
                if !sliding {
                    p.box(d.x / 2 - 0.25, d.y * 0.4, 0.02, glass, x: sx * (d.x / 4), y: d.y * 0.5, z: 0.04, alpha: 0.5)
                }
            }
            p.box(0.02, d.y * 0.2, 0.05, metal, x: 0.05, y: d.y * 0.4, z: 0.04)

        case .garageDoor:
            p.box(d.x, d.y, 0.08, main)
            let panels = 4
            for i in 1..<panels { p.box(d.x * 0.98, 0.015, 0.02, UIColor(white: 0.55, alpha: 1), y: d.y * Float(i) / Float(panels), z: 0.045) }
            for i in 0..<(d.x > 4 ? 8 : 4) {
                let x = -d.x / 2 + d.x * (Float(i) + 0.5) / Float(d.x > 4 ? 8 : 4)
                p.box(d.x / (d.x > 4 ? 8 : 4) * 0.7, d.y * 0.1, 0.01, glass, x: x, y: d.y * 0.76, z: 0.05, alpha: 0.55)
            }

        case .window:
            let f: Float = 0.06
            let frameColor = main
            p.box(d.x, f, 0.1, frameColor, y: 0)
            p.box(d.x, f, 0.1, frameColor, y: d.y - f)
            for sx: Float in [-1, 1] { p.box(f, d.y - 2 * f, 0.1, frameColor, x: sx * (d.x / 2 - f / 2), y: f) }
            p.box(d.x - 2 * f, d.y - 2 * f, 0.01, glass, y: f, alpha: 0.4)
            if id.contains("double.hung") || id.contains("black.frame") {
                p.box(d.x - 2 * f, 0.04, 0.05, frameColor, y: d.y * 0.5 - 0.02)
            }
            if id.contains("casement") || id.contains("sliding") || id.contains("black.frame") {
                p.box(0.04, d.y - 2 * f, 0.05, frameColor, y: f)
            }
            p.box(d.x + 0.1, 0.04, 0.16, white, y: -0.02)
        }
    }

    // MARK: - Shared pieces

    private static func sofa(_ p: Parts, _ main: UIColor) {
        let d = p.d
        let armW = d.x * 0.1, backT = d.z * 0.22
        p.box(d.x, d.y * 0.34, d.z, main, y: d.y * 0.1, chamfer: 0.03)
        p.box(d.x - armW * 2, d.y * 0.16, d.z - backT, shade(main, 1.12), y: d.y * 0.44, z: backT / 2, chamfer: 0.03)
        p.box(d.x - armW * 2, d.y * 0.5, backT, main, y: d.y * 0.34, z: -d.z / 2 + backT / 2, chamfer: 0.04)
        for sx: Float in [-1, 1] {
            p.box(armW, d.y * 0.5, d.z, main, x: sx * (d.x / 2 - armW / 2), y: d.y * 0.1, chamfer: 0.04)
            p.cylinder(0.03, d.y * 0.1, UIColor(red: 0.2, green: 0.17, blue: 0.14, alpha: 1), x: sx * (d.x / 2 - 0.1), z: d.z / 2 - 0.1)
            p.cylinder(0.03, d.y * 0.1, UIColor(red: 0.2, green: 0.17, blue: 0.14, alpha: 1), x: sx * (d.x / 2 - 0.1), z: -d.z / 2 + 0.1)
        }
        if d.x > 1.6 {
            p.box(0.008, d.y * 0.16, d.z - backT, shade(main, 0.7), x: -d.x * 0.17, y: d.y * 0.44, z: backT / 2)
            p.box(0.008, d.y * 0.16, d.z - backT, shade(main, 0.7), x: d.x * 0.17, y: d.y * 0.44, z: backT / 2)
        }
    }

    /// A run of solid steps climbing along (dirX, dirZ), starting at (sx, sz).
    private static func flight(_ p: Parts, count: Int, width: Float, run: Float, rise: Float, baseH: Float,
                               sx: Float, sz: Float, dirX: Float, dirZ: Float, color: UIColor) {
        for i in 0..<count {
            let h = baseH + rise * Float(i + 1)
            let cx = sx + dirX * run * (Float(i) + 0.5)
            let cz = sz + dirZ * run * (Float(i) + 0.5)
            let w = dirX != 0 ? run : width
            let l = dirZ != 0 ? run : width
            p.box(w, h, l, i % 2 == 0 ? color : shade(color, 0.94), x: cx, z: cz)
        }
    }

    private static func applyRoofTexture(_ node: SCNNode, _ item: CatalogItem, _ d: SIMD3<Float>) {
        guard let pattern = MaterialTextures.pattern(for: item),
              let image = MaterialTextures.image(for: item),
              let material = node.geometry?.firstMaterial else { return }
        let cover = MaterialTextures.coverage(of: pattern)
        material.diffuse.contents = image
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(max(d.x, d.z) / cover / 2, max(d.x, d.z) / cover / 2, 1)
    }
}

// MARK: - Part builder

/// Collects shapes into one node. Positions are given as `x`, `z` offsets
/// from the item's center and `y` as height above the item's bottom, so a
/// model is described in the same terms as its catalog dimensions.
private final class Parts {
    let d: SIMD3<Float>
    let root = SCNNode()

    init(_ dimensions: SIMD3<Float>) { d = dimensions }

    private func paint(_ geometry: SCNGeometry, _ color: UIColor, alpha: CGFloat, glow: Bool) {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.specular.contents = UIColor(white: 0.2, alpha: 1)
        if alpha < 1 {
            material.transparency = alpha
            material.isDoubleSided = true
        }
        if glow { material.emission.contents = color.withAlphaComponent(0.8) }
        geometry.materials = [material]
    }

    @discardableResult
    func add(_ geometry: SCNGeometry, _ color: UIColor, x: Float, bottom: Float, z: Float,
             alpha: CGFloat = 1, glow: Bool = false, squash: Float = 1) -> SCNNode {
        paint(geometry, color, alpha: alpha, glow: glow)
        let node = SCNNode(geometry: geometry)
        let (lo, hi) = node.boundingBox
        node.scale = SCNVector3(1, squash, 1)
        node.position = SCNVector3(x - (lo.x + hi.x) / 2, bottom - d.y / 2 - lo.y * squash, z - (lo.z + hi.z) / 2)
        root.addChildNode(node)
        return node
    }

    @discardableResult
    func box(_ w: Float, _ h: Float, _ l: Float, _ color: UIColor, x: Float = 0, y: Float = 0, z: Float = 0,
             chamfer: Float = 0, alpha: CGFloat = 1, glow: Bool = false) -> SCNNode {
        let limit = max(0, min(w, h, l) * 0.49)
        let geometry = SCNBox(width: CGFloat(max(w, 0.001)), height: CGFloat(max(h, 0.001)), length: CGFloat(max(l, 0.001)),
                              chamferRadius: CGFloat(min(chamfer, limit)))
        return add(geometry, color, x: x, bottom: y, z: z, alpha: alpha, glow: glow)
    }

    @discardableResult
    func cylinder(_ radius: Float, _ h: Float, _ color: UIColor, x: Float = 0, y: Float = 0, z: Float = 0,
                  alpha: CGFloat = 1, glow: Bool = false) -> SCNNode {
        add(SCNCylinder(radius: CGFloat(max(radius, 0.001)), height: CGFloat(max(h, 0.001))), color,
            x: x, bottom: y, z: z, alpha: alpha, glow: glow)
    }

    @discardableResult
    func sphere(_ radius: Float, _ color: UIColor, x: Float = 0, y: Float = 0, z: Float = 0,
                squash: Float = 1, glow: Bool = false) -> SCNNode {
        add(SCNSphere(radius: CGFloat(max(radius, 0.001))), color, x: x, bottom: y, z: z, glow: glow, squash: squash)
    }

    @discardableResult
    func cone(_ topRadius: Float, _ bottomRadius: Float, _ h: Float, _ color: UIColor, x: Float = 0, y: Float = 0,
              z: Float = 0, glow: Bool = false) -> SCNNode {
        add(SCNCone(topRadius: CGFloat(topRadius), bottomRadius: CGFloat(max(bottomRadius, 0.001)), height: CGFloat(max(h, 0.001))),
            color, x: x, bottom: y, z: z, glow: glow)
    }

    @discardableResult
    func pyramid(_ w: Float, _ h: Float, _ l: Float, _ color: UIColor, y: Float = 0) -> SCNNode {
        add(SCNPyramid(width: CGFloat(w), height: CGFloat(h), length: CGFloat(l)), color, x: 0, bottom: y, z: 0)
    }

    /// A triangular prism (gable roof) with its ridge along z.
    @discardableResult
    func gable(_ w: Float, _ h: Float, _ l: Float, _ color: UIColor, y: Float = 0, alpha: CGFloat = 1) -> SCNNode {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: CGFloat(w), y: 0))
        path.addLine(to: CGPoint(x: CGFloat(w) / 2, y: CGFloat(h)))
        path.close()
        let shape = SCNShape(path: path, extrusionDepth: CGFloat(l))
        return add(shape, color, x: 0, bottom: y, z: 0, alpha: alpha)
    }
}
