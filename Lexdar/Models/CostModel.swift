import Foundation

// MARK: - Starter price book

enum PriceUnit: String {
    case each = "each"
    case perSqFt = "sq ft"
    case perLinFt = "lin ft"
}

/// A starter price: US-average installed cost around October 2026, how much of
/// it is materials (the rest is labor), and what it is measured in.
struct PriceSpec {
    let base: Double
    let unit: PriceUnit
    /// 0...1. Scaled by local goods prices; the rest by local labor prices.
    let materialShare: Double
}

/// Rough starter prices for planning. These are the app's own estimates of
/// typical US installed costs, not quotes and not a published price list, so
/// edit any line to match a real local quote. The first matching keyword wins,
/// so specific keywords come before general ones.
enum PriceBook {
    private struct Rule {
        let token: String
        let spec: PriceSpec
        init(_ token: String, _ price: Double, _ unit: PriceUnit = .each, _ share: Double = 0.7) {
            self.token = token
            self.spec = PriceSpec(base: price, unit: unit, materialShare: share)
        }
    }

    // Surfaces, priced per square foot of surface.
    private static let surfaceRules: [Rule] = [
        Rule("terrazzo", 22, .perSqFt, 0.45),
        Rule("herringbone", 16, .perSqFt, 0.5),
        Rule("parquet", 14, .perSqFt, 0.5),
        Rule("floor.stone", 18, .perSqFt, 0.55),
        Rule("floor.tile.mosaic", 20, .perSqFt, 0.4),
        Rule("floor.tile", 13, .perSqFt, 0.45),
        Rule("floor.brick", 14, .perSqFt, 0.5),
        Rule("floor.carpet", 5.5, .perSqFt, 0.6),
        Rule("floor.rubber", 8, .perSqFt, 0.6),
        Rule("floor.epoxy", 7, .perSqFt, 0.3),
        Rule("floor.concrete", 8, .perSqFt, 0.3),
        Rule("floor.lvp", 6.5, .perSqFt, 0.55),
        Rule("floor.laminate", 5.5, .perSqFt, 0.55),
        Rule("floor.bamboo", 8, .perSqFt, 0.55),
        Rule("floor.cork", 8, .perSqFt, 0.55),
        Rule("floor.", 11, .perSqFt, 0.55),

        Rule("wall.paint", 2.6, .perSqFt, 0.25),
        Rule("wall.wallpaper", 4.5, .perSqFt, 0.4),
        Rule("wall.tile.mosaic", 28, .perSqFt, 0.4),
        Rule("wall.tile", 20, .perSqFt, 0.4),
        Rule("wall.brick", 18, .perSqFt, 0.45),
        Rule("wall.shiplap", 9, .perSqFt, 0.5),
        Rule("wall.board", 9, .perSqFt, 0.5),
        Rule("wall.wood", 22, .perSqFt, 0.55),
        Rule("wall.stone", 28, .perSqFt, 0.5),
        Rule("wall.stucco", 10, .perSqFt, 0.3),
        Rule("wall.concrete", 14, .perSqFt, 0.4),
        Rule("wall.", 8, .perSqFt, 0.45),

        Rule("ext.siding.fibercement", 11, .perSqFt, 0.45),
        Rule("ext.siding.board", 10, .perSqFt, 0.45),
        Rule("ext.siding", 7.5, .perSqFt, 0.45),
        Rule("ext.shingle", 15, .perSqFt, 0.45),
        Rule("ext.brick", 20, .perSqFt, 0.45),
        Rule("ext.stone", 26, .perSqFt, 0.5),
        Rule("ext.stucco", 10, .perSqFt, 0.3),
        Rule("ext.metal", 11, .perSqFt, 0.5),
        Rule("ext.wood", 14, .perSqFt, 0.5),
        Rule("ext.log", 18, .perSqFt, 0.55),
        Rule("ext.", 10, .perSqFt, 0.45),
    ]

    // Placed items: each unless noted. Furniture and decor are all goods;
    // fixtures and buildings include installation.
    private static let itemRulesA: [Rule] = [
        // Stairs
        Rule("stairs.floating", 12000, .each, 0.55), Rule("stairs.spiral", 6500, .each, 0.55),
        Rule("stairs.ushape", 9000, .each, 0.5), Rule("stairs.lshape", 8000, .each, 0.5),
        Rule("stairs.winder", 7500, .each, 0.5), Rule("stairs.straight.wide", 5500, .each, 0.5),
        Rule("stairs.straight.basement", 2500, .each, 0.5), Rule("stairs.straight", 4500, .each, 0.5),
        Rule("stairs.ramp", 3500, .each, 0.5), Rule("stairs.deck", 1500, .each, 0.5),
        Rule("stairs.porch", 1800, .each, 0.5), Rule("stairs.", 4500, .each, 0.5),

        // Roofs (per square foot of footprint, with a 25% allowance for pitch)
        Rule("roof.gable.slate", 20, .perSqFt, 0.55), Rule("roof.gable.clay", 14, .perSqFt, 0.55),
        Rule("roof.hip.clay", 14, .perSqFt, 0.55), Rule("roof.gable.cedar", 12, .perSqFt, 0.5),
        Rule("roof.gable.metal", 11, .perSqFt, 0.55), Rule("roof.hip.metal", 11, .perSqFt, 0.55),
        Rule("roof.shed.metal", 11, .perSqFt, 0.55), Rule("roof.shed.membrane", 8, .perSqFt, 0.5),
        Rule("roof.flat", 8, .perSqFt, 0.5), Rule("roof.dormer", 4500, .each, 0.5),
        Rule("roof.porch", 3500, .each, 0.5), Rule("roof.chimney", 5000, .each, 0.5),
        Rule("roof.", 5.5, .perSqFt, 0.5),

        // Foundations
        Rule("found.slab.floor.upper", 9, .perSqFt, 0.5), Rule("found.slab", 7, .perSqFt, 0.4),
        Rule("found.footing", 60, .perLinFt, 0.4), Rule("found.stemwall", 150, .perLinFt, 0.4),
        Rule("found.basement", 45, .perSqFt, 0.35), Rule("found.pier", 14, .perSqFt, 0.4),

        // Structures
        Rule("struct.garage.double", 42000, .each, 0.5), Rule("struct.garage", 24000, .each, 0.5),
        Rule("struct.carport", 9000, .each, 0.55), Rule("struct.shed", 6500, .each, 0.6),
        Rule("struct.barn", 60000, .each, 0.5), Rule("struct.adu", 150000, .each, 0.45),
        Rule("struct.poolhouse", 110000, .each, 0.45), Rule("struct.gazebo", 12000, .each, 0.55),
        Rule("struct.pergola", 8000, .each, 0.55), Rule("struct.greenhouse", 15000, .each, 0.6),

        // Doors and windows (installed)
        Rule("door.garage.double", 2200, .each, 0.7), Rule("door.garage", 1300, .each, 0.7),
        Rule("door.exterior.slidingglass.wide", 2600, .each, 0.7), Rule("door.exterior.slidingglass", 1800, .each, 0.7),
        Rule("door.exterior.french", 2200, .each, 0.65), Rule("door.exterior", 1800, .each, 0.65),
        Rule("door.barn", 650, .each, 0.7), Rule("door.pocket", 600, .each, 0.5),
        Rule("door.interior.double", 700, .each, 0.6), Rule("door.", 350, .each, 0.6),
        Rule("window.bay", 2500, .each, 0.65), Rule("window.picture", 900, .each, 0.7),
        Rule("window.black", 950, .each, 0.7), Rule("window.casement", 700, .each, 0.7),
        Rule("window.transom", 450, .each, 0.7), Rule("window.", 600, .each, 0.7),

    ]

    private static let itemRulesB: [Rule] = [
        // Landscaping
        Rule("land.tree.palm", 900), Rule("land.tree.oak", 900), Rule("land.tree.maple.red", 450),
        Rule("land.tree.maple", 700), Rule("land.tree.birch", 400), Rule("land.tree.cherry", 450),
        Rule("land.tree.dogwood", 350), Rule("land.tree.apple", 300), Rule("land.tree.pine", 350),
        Rule("land.tree.spruce", 400), Rule("land.tree.cedar", 120), Rule("land.tree", 500),
        Rule("land.shrub", 110), Rule("land.hedge", 500), Rule("land.flower", 400),
        Rule("land.grass", 1.1, .perSqFt, 0.4), Rule("land.mulch", 1.2, .perSqFt, 0.4),
        Rule("land.gravel", 2.2, .perSqFt, 0.5), Rule("land.path.flagstone", 18, .perSqFt, 0.5),
        Rule("land.path", 14, .perSqFt, 0.5), Rule("land.driveway.asphalt", 6, .perSqFt, 0.45),
        Rule("land.driveway", 8, .perSqFt, 0.4), Rule("land.sidewalk", 8, .perSqFt, 0.4),
        Rule("land.retaining", 55, .perLinFt, 0.5), Rule("land.stone.wall", 70, .perLinFt, 0.5),
        Rule("land.boulder", 600), Rule("land.raised", 450), Rule("land.fountain", 1800),
        Rule("land.pond", 3500), Rule("land.planter", 220), Rule("land.arbor", 900),
        Rule("land.fence.wrought", 350), Rule("land.fence.chainlink", 90), Rule("land.fence", 160),
        Rule("land.mailbox", 120),

        // Outdoor and pools
        Rule("out.pool.lap", 85000, .each, 0.4), Rule("out.pool.plunge", 35000, .each, 0.4),
        Rule("out.pool.freeform", 80000, .each, 0.4), Rule("out.pool", 70000, .each, 0.4),
        Rule("out.spa", 9000, .each, 0.7), Rule("out.deck", 35, .perSqFt, 0.5),
        Rule("out.patio", 8, .perSqFt, 0.4), Rule("out.diningset", 1800, .each, 1),
        Rule("out.chaise", 450, .each, 1), Rule("out.sofa", 2200, .each, 1),
        Rule("out.umbrella", 400, .each, 1), Rule("out.trampoline", 450, .each, 1),
        Rule("outdoor.deck", 38, .perSqFt, 0.5), Rule("outdoor.patio", 15, .perSqFt, 0.45),
        Rule("outdoor.pergola", 8000, .each, 0.55), Rule("outdoor.fence", 160),
        Rule("outdoor.grill", 5500, .each, 0.6), Rule("outdoor.firepit", 900, .each, 0.6),
        Rule("outdoor.shed", 6500, .each, 0.6), Rule("outdoor.pool", 55000, .each, 0.4),
        Rule("outdoor.hottub", 9000, .each, 0.7), Rule("outdoor.plantings", 500),

    ]

    private static let itemRulesC: [Rule] = [
        // Kitchen
        Rule("kitchen.island.waterfall", 6500, .each, 0.6), Rule("kitchen.island", 3500, .each, 0.6),
        Rule("kitchen.peninsula", 2800, .each, 0.6), Rule("kitchen.cabinets.tall", 1800, .each, 0.6),
        Rule("kitchen.cabinets.upper", 1800, .each, 0.6), Rule("kitchen.cabinets", 2400, .each, 0.6),
        Rule("kitchen.pantry.walkin", 1800, .each, 0.6), Rule("kitchen.pantry", 1500, .each, 0.6),
        Rule("kitchen.sink", 1100, .each, 0.6), Rule("kitchen.faucet", 250, .each, 0.7),
        Rule("kitchen.counter.marble", 100, .perSqFt, 0.6), Rule("kitchen.counter.concrete", 85, .perSqFt, 0.5),
        Rule("kitchen.counter.butcher", 45, .perSqFt, 0.6), Rule("kitchen.counter.granite", 70, .perSqFt, 0.6),
        Rule("kitchen.counter", 75, .perSqFt, 0.6), Rule("kitchen.backsplash", 18, .perSqFt, 0.45),
        Rule("kitchen.hood.island", 1800, .each, 0.7), Rule("kitchen.hood", 900, .each, 0.7),
        Rule("kitchen.bar", 250, .each, 1), Rule("kitchen.nook", 1500, .each, 0.8),

        // Bathroom
        Rule("bath.tub.freestanding.clawfoot", 2800, .each, 0.65), Rule("bath.tub.freestanding", 2800, .each, 0.65),
        Rule("bath.tub.corner", 2200, .each, 0.6), Rule("bath.tub.dropin", 2200, .each, 0.6),
        Rule("bath.tub", 1800, .each, 0.55), Rule("bath.shower.glass.large", 4500, .each, 0.55),
        Rule("bath.shower.glass.steam", 6500, .each, 0.55), Rule("bath.shower.glass", 3200, .each, 0.55),
        Rule("bath.shower.walkin", 2800, .each, 0.55), Rule("bath.showerpan", 600, .each, 0.5),
        Rule("bath.vanity.floating.double", 2200, .each, 0.6), Rule("bath.vanity.double", 1800, .each, 0.6),
        Rule("bath.vanity", 1100, .each, 0.6), Rule("bath.sink", 450, .each, 0.6),
        Rule("bath.toilet", 650, .each, 0.6), Rule("bath.bidet", 550, .each, 0.6),
        Rule("bath.mirror.led", 400, .each, 0.8), Rule("bath.mirror", 150, .each, 0.8),
        Rule("bath.towel", 350, .each, 0.7), Rule("bath.linencloset", 600, .each, 0.7),

        // Appliances
        Rule("appliance.fridge.frenchdoor", 2800, .each, 0.95), Rule("appliance.fridge.sidebyside", 2200, .each, 0.95),
        Rule("appliance.fridge.undercounter", 900, .each, 0.95), Rule("appliance.fridge", 1800, .each, 0.95),
        Rule("appliance.freezer", 600, .each, 0.95), Rule("appliance.range.36", 3500, .each, 0.9),
        Rule("appliance.range.double", 3200, .each, 0.85), Rule("appliance.range.cooktop", 900, .each, 0.85),
        Rule("appliance.range", 1500, .each, 0.9), Rule("appliance.dishwasher", 750, .each, 0.85),
        Rule("appliance.microwave", 400, .each, 0.9), Rule("appliance.washer.stacked", 1800, .each, 0.95),
        Rule("appliance.washer", 900, .each, 0.95), Rule("appliance.dryer", 850, .each, 0.95),
        Rule("appliance.winefridge", 900, .each, 0.95), Rule("appliance.hvac.furnace", 6500, .each, 0.5),
        Rule("appliance.waterheater.tankless", 3200, .each, 0.5), Rule("appliance.waterheater", 2000, .each, 0.5),
        Rule("appliance.heatpump", 6500, .each, 0.55), Rule("appliance.fireplace", 4500, .each, 0.55),
        Rule("appliance.woodstove", 3000, .each, 0.6),

    ]

    private static let itemRulesD: [Rule] = [
        // Furniture (all goods)
        Rule("furn.sectional", 2800, .each, 1), Rule("furn.sofa", 1400, .each, 1), Rule("furn.loveseat", 1000, .each, 1),
        Rule("furn.armchair", 600, .each, 1), Rule("furn.recliner", 800, .each, 1), Rule("furn.ottoman", 300, .each, 1),
        Rule("furn.futon", 700, .each, 1), Rule("furn.coffeetable", 400, .each, 1), Rule("furn.sidetable", 200, .each, 1),
        Rule("furn.console", 500, .each, 1), Rule("furn.diningtable.8", 1500, .each, 1), Rule("furn.diningtable", 900, .each, 1),
        Rule("furn.bench", 350, .each, 1), Rule("furn.barstool", 150, .each, 1), Rule("furn.counterstool", 150, .each, 1),
        Rule("furn.deskchair", 250, .each, 1), Rule("furn.diningchair", 180, .each, 1),
        Rule("furn.bed.king", 1200, .each, 1), Rule("furn.bed.queen", 900, .each, 1), Rule("furn.bed.full", 700, .each, 1),
        Rule("furn.bed.twin", 500, .each, 1), Rule("furn.bed.bunk", 1100, .each, 1), Rule("furn.bed.crib", 350, .each, 1),
        Rule("furn.nightstand", 200, .each, 1), Rule("furn.dresser", 800, .each, 1), Rule("furn.credenza", 900, .each, 1),
        Rule("furn.sideboard", 900, .each, 1), Rule("furn.desk.standing", 600, .each, 1), Rule("furn.desk", 500, .each, 1),
        Rule("furn.bookshelf", 350, .each, 1), Rule("furn.tvstand", 450, .each, 1), Rule("furn.vanity", 400, .each, 1),
        Rule("furn.rug", 400, .each, 1),

        // Lighting
        Rule("light.chandelier.crystal", 1200, .each, 0.8), Rule("light.chandelier", 750, .each, 0.8),
        Rule("light.pendant.cluster", 450, .each, 0.8), Rule("light.pendant", 250, .each, 0.8),
        Rule("light.recessed", 150, .each, 0.5), Rule("light.sconce", 130, .each, 0.7), Rule("light.wallsconce", 130, .each, 0.7),
        Rule("light.floorlamp", 160, .each, 1), Rule("light.lamp", 90, .each, 1), Rule("light.ceilingfan", 320, .each, 0.6),
        Rule("light.track", 200, .each, 0.6), Rule("light.lantern", 120, .each, 0.8),

        // Decor and storage
        Rule("decor.plant", 100, .each, 1), Rule("decor.tv.85", 1800, .each, 1), Rule("decor.tv", 900, .each, 1),
        Rule("decor.art", 200, .each, 1), Rule("decor.mirror", 250, .each, 1), Rule("decor.curtains", 300, .each, 1),
        Rule("decor.clock", 60, .each, 1), Rule("storage.closet.reachin", 1200, .each, 0.6),
        Rule("storage.closet.walkin", 900, .each, 0.7), Rule("storage.lockers", 1100, .each, 0.7),
        Rule("storage.garage", 250, .each, 1), Rule("storage.workbench", 350, .each, 1),
        Rule("storage.shelf", 60, .each, 1), Rule("storage.", 600, .each, 0.8),
    ]

    private static let itemRules: [Rule] = [itemRulesA, itemRulesB, itemRulesC, itemRulesD].flatMap { $0 }

    /// The starter price for a catalog item, or a generic one if no keyword
    /// matches (flagged by `isGeneric`).
    static func spec(for item: CatalogItem) -> (spec: PriceSpec, isGeneric: Bool) {
        let rules = item.category.isSurfaceMaterial ? surfaceRules : itemRules
        if let rule = rules.first(where: { item.id.contains($0.token) }) { return (rule.spec, false) }
        let fallback: Double
        switch item.category {
        case .flooring: fallback = 9
        case .wallFinish, .exteriorFinish: fallback = 8
        default: fallback = 500
        }
        let unit: PriceUnit = item.category.isSurfaceMaterial ? .perSqFt : .each
        return (PriceSpec(base: fallback, unit: unit, materialShare: 0.7), true)
    }

    // Walls and demolition, per square foot of wall face.
    static let demolition = PriceSpec(base: 7.5, unit: .perSqFt, materialShare: 0.1)
    static let newPartition = PriceSpec(base: 7.0, unit: .perSqFt, materialShare: 0.4)
}

// MARK: - Pricing context

/// Everything that turns a starter price into a local, current one.
struct Pricing {
    /// BEA price level for the state: 100 is the national average.
    var goodsIndex: Double = 100
    var servicesIndex: Double = 100
    /// Current construction-materials and construction-wage readings divided by
    /// the baseline readings the starter prices were set against.
    var materialsTrend: Double = 1
    var wageTrend: Double = 1
    /// Local prices the user typed in for this ZIP (item id to price per unit).
    var overrides: [String: Double] = [:]

    func localPrice(_ spec: PriceSpec, itemID: String) -> (price: Double, overridden: Bool) {
        if let typed = overrides[itemID] { return (typed, true) }
        let material = spec.materialShare * goodsIndex / 100 * materialsTrend
        let labor = (1 - spec.materialShare) * servicesIndex / 100 * wageTrend
        return (spec.base * (material + labor), false)
    }
}

// MARK: - Lines

struct CostLine: Identifiable {
    let id: String
    let group: String
    let title: String
    let quantity: Double
    let unit: String
    let unitPrice: Double
    let overridden: Bool
    /// True when no keyword in the price book matched and a generic price was used.
    let generic: Bool
    /// The catalog item this line prices, if any (used for local price edits).
    let itemID: String?

    var total: Double { quantity * unitPrice }
}

struct CostSummary {
    let lines: [CostLine]
    var subtotal: Double { lines.reduce(0) { $0 + $1.total } }
    var contingency: Double { subtotal * 0.10 }
    var total: Double { subtotal + contingency }
    /// A planning range: finished prices vary a lot from job to job.
    var low: Double { total * 0.85 }
    var high: Double { total * 1.25 }
}

#if canImport(RoomPlan)
import RoomPlan

enum CostEstimator {
    private static let sqFtPerSqM = 10.7639
    private static let feetPerMeter = 3.28084

    static func estimate(room: CapturedRoom, plan: RenovationPlan, pricing: Pricing) -> CostSummary {
        var lines: [CostLine] = []

        func add(group: String, title: String, quantity: Double, spec: PriceSpec, itemID: String,
                 generic: Bool = false, id: String? = nil) {
            guard quantity > 0.0001 else { return }
            let local = pricing.localPrice(spec, itemID: itemID)
            lines.append(CostLine(id: id ?? "\(group)|\(itemID)", group: group, title: title, quantity: quantity,
                                  unit: spec.unit.rawValue, unitPrice: local.price, overridden: local.overridden,
                                  generic: generic, itemID: itemID))
        }

        // Surface finishes: add up the area each material covers.
        let bounds = RoomSceneBuilder.bounds(of: room)
        var areaByItem: [String: Double] = [:]
        for override in plan.surfaceMaterials {
            guard let item = Catalog.item(id: override.catalogItemID) else { continue }
            var area: Double?
            if override.surfaceID == RoomSceneBuilder.syntheticFloorID {
                area = Double((bounds.maxX - bounds.minX) * (bounds.maxZ - bounds.minZ))
            } else if let floor = room.floors.first(where: { $0.identifier == override.surfaceID }) {
                area = Double(floor.dimensions.x * floor.dimensions.z)
            } else if let wall = room.walls.first(where: { $0.identifier == override.surfaceID }),
                      !plan.removedWallIDs.contains(wall.identifier) {
                area = Double(wall.dimensions.x * wall.dimensions.y)
            } else if let added = plan.newWalls.first(where: { $0.id == override.surfaceID }) {
                area = Double(added.length * added.height)
            }
            if let area { areaByItem[item.id, default: 0] += area * sqFtPerSqM }
        }
        for (itemID, sqft) in areaByItem {
            guard let item = Catalog.item(id: itemID) else { continue }
            let priced = PriceBook.spec(for: item)
            let group = item.category == .flooring ? "Flooring" : (item.category == .exteriorFinish ? "Exterior Finishes" : "Wall Finishes")
            add(group: group, title: item.name, quantity: sqft, spec: priced.spec, itemID: item.id, generic: priced.isGeneric)
        }

        // Removed walls.
        var removedArea = 0.0
        for wall in room.walls where plan.removedWallIDs.contains(wall.identifier) {
            removedArea += Double(wall.dimensions.x * wall.dimensions.y) * sqFtPerSqM
        }
        add(group: "Walls Removed or Added", title: "Wall removal and patching (not structural work)",
            quantity: removedArea, spec: PriceBook.demolition, itemID: "demolition")

        // New partition walls.
        var newArea = 0.0
        for wall in plan.newWalls { newArea += Double(wall.length * wall.height) * sqFtPerSqM }
        add(group: "Walls Removed or Added", title: "New partition walls (framing, drywall, paint)",
            quantity: newArea, spec: PriceBook.newPartition, itemID: "partition")

        // Placed items, totaled per catalog item.
        var count: [String: Double] = [:]
        var area: [String: Double] = [:]
        var length: [String: Double] = [:]
        for placed in plan.placedItems {
            guard let item = placed.catalogItem else { continue }
            let s = Double(placed.scale)
            count[item.id, default: 0] += 1
            switch PriceBook.spec(for: item).spec.unit {
            case .perSqFt:
                let base = Double(item.dimensions.x * item.dimensions.z) * s * s * sqFtPerSqM
                area[item.id, default: 0] += item.id.hasPrefix("roof.") ? base * 1.25 : base
            case .perLinFt:
                let run = item.id.hasPrefix("found.") ? 2 * Double(item.dimensions.x + item.dimensions.z) : Double(item.dimensions.x)
                length[item.id, default: 0] += run * s * feetPerMeter
            case .each:
                break
            }
        }
        for itemID in count.keys.sorted() {
            guard let item = Catalog.item(id: itemID) else { continue }
            let priced = PriceBook.spec(for: item)
            let quantity: Double
            switch priced.spec.unit {
            case .each: quantity = count[itemID] ?? 0
            case .perSqFt: quantity = area[itemID] ?? 0
            case .perLinFt: quantity = length[itemID] ?? 0
            }
            let title = priced.spec.unit == .each || (count[itemID] ?? 1) <= 1 ? item.name : "\(item.name) (x\(Int(count[itemID] ?? 1)))"
            add(group: item.category.displayName, title: title, quantity: quantity, spec: priced.spec,
                itemID: itemID, generic: priced.isGeneric)
        }

        return CostSummary(lines: lines)
    }
}
#endif
