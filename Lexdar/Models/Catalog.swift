import Foundation

/// Static, bundled build-out catalog used by the renovation editor. This is
/// a starter inventory, not a product database — extend it freely, or
/// replace entries' `assetName` with real USDZ models dropped into
/// Resources/Models/ once you have assets (e.g. from a 3D asset vendor you
/// have rights to use).
///
/// Dimensions are (width, height, depth) in meters.
enum Catalog {
    static let items: [CatalogItem] = flooring + wallFinishes + kitchenFixtures
        + bathroomFixtures + appliances + furniture + lighting + outdoor

    static func items(in category: CatalogCategory) -> [CatalogItem] {
        items.filter { $0.category == category }
    }

    static func item(id: String) -> CatalogItem? {
        items.first { $0.id == id }
    }

    // MARK: - Flooring (applied as a material to the room's floor surface)

    static let flooring: [CatalogItem] = [
        CatalogItem(id: "floor.oak.natural", name: "Natural Oak Hardwood", category: .flooring,
                    dimensions: SIMD3(1, 0.02, 1), primitive: .plane, colorHex: "C8A165",
                    note: "Wide-plank engineered hardwood"),
        CatalogItem(id: "floor.oak.walnut", name: "Walnut Hardwood", category: .flooring,
                    dimensions: SIMD3(1, 0.02, 1), primitive: .plane, colorHex: "5B3A29"),
        CatalogItem(id: "floor.tile.porcelain.gray", name: "Gray Porcelain Tile", category: .flooring,
                    dimensions: SIMD3(1, 0.02, 1), primitive: .plane, colorHex: "A9ADB0",
                    note: "24x24in, good for kitchens/baths"),
        CatalogItem(id: "floor.tile.marble.white", name: "White Marble-Look Tile", category: .flooring,
                    dimensions: SIMD3(1, 0.02, 1), primitive: .plane, colorHex: "EDEBE6"),
        CatalogItem(id: "floor.lvp.greige", name: "Luxury Vinyl Plank (Greige)", category: .flooring,
                    dimensions: SIMD3(1, 0.02, 1), primitive: .plane, colorHex: "B8AFA2",
                    note: "Waterproof, basement/bath friendly"),
        CatalogItem(id: "floor.carpet.neutral", name: "Neutral Plush Carpet", category: .flooring,
                    dimensions: SIMD3(1, 0.02, 1), primitive: .plane, colorHex: "D8D2C4"),
        CatalogItem(id: "floor.concrete.polished", name: "Polished Concrete", category: .flooring,
                    dimensions: SIMD3(1, 0.02, 1), primitive: .plane, colorHex: "9FA3A6"),
    ]

    // MARK: - Wall finishes (applied as a material to one or more wall surfaces)

    static let wallFinishes: [CatalogItem] = [
        CatalogItem(id: "wall.paint.white", name: "Designer White Paint", category: .wallFinish,
                    dimensions: SIMD3(1, 1, 0.01), primitive: .plane, colorHex: "F5F3EE"),
        CatalogItem(id: "wall.paint.greige", name: "Warm Greige Paint", category: .wallFinish,
                    dimensions: SIMD3(1, 1, 0.01), primitive: .plane, colorHex: "C9C1B4"),
        CatalogItem(id: "wall.paint.navy", name: "Navy Accent Paint", category: .wallFinish,
                    dimensions: SIMD3(1, 1, 0.01), primitive: .plane, colorHex: "27324A"),
        CatalogItem(id: "wall.paint.sage", name: "Sage Green Paint", category: .wallFinish,
                    dimensions: SIMD3(1, 1, 0.01), primitive: .plane, colorHex: "9CAF88"),
        CatalogItem(id: "wall.tile.subway.white", name: "White Subway Tile", category: .wallFinish,
                    dimensions: SIMD3(1, 1, 0.01), primitive: .plane, colorHex: "F0F0EC",
                    note: "Kitchen backsplash / bath surround"),
        CatalogItem(id: "wall.tile.herringbone.marble", name: "Marble Herringbone Tile", category: .wallFinish,
                    dimensions: SIMD3(1, 1, 0.01), primitive: .plane, colorHex: "E4E1D8"),
        CatalogItem(id: "wall.shiplap.white", name: "White Shiplap", category: .wallFinish,
                    dimensions: SIMD3(1, 1, 0.01), primitive: .plane, colorHex: "EFEFEA"),
    ]

    // MARK: - Kitchen fixtures

    static let kitchenFixtures: [CatalogItem] = [
        CatalogItem(id: "kitchen.island.std", name: "Kitchen Island (6ft)", category: .kitchenFixture,
                    dimensions: SIMD3(1.83, 0.9, 0.9), primitive: .roundedBox, colorHex: "E8E4DC"),
        CatalogItem(id: "kitchen.cabinets.base.run", name: "Base Cabinet Run (8ft)", category: .kitchenFixture,
                    dimensions: SIMD3(2.44, 0.9, 0.6), primitive: .box, colorHex: "D9CBB5"),
        CatalogItem(id: "kitchen.cabinets.upper.run", name: "Upper Cabinet Run (8ft)", category: .kitchenFixture,
                    dimensions: SIMD3(2.44, 0.75, 0.32), primitive: .box, colorHex: "D9CBB5"),
        CatalogItem(id: "kitchen.sink.farmhouse", name: "Farmhouse Sink", category: .kitchenFixture,
                    dimensions: SIMD3(0.86, 0.25, 0.46), primitive: .roundedBox, colorHex: "FFFFFF"),
        CatalogItem(id: "kitchen.sink.undermount", name: "Undermount Double Sink", category: .kitchenFixture,
                    dimensions: SIMD3(0.81, 0.2, 0.46), primitive: .roundedBox, colorHex: "C7CBCD"),
        CatalogItem(id: "kitchen.faucet.gooseneck", name: "Gooseneck Faucet", category: .kitchenFixture,
                    dimensions: SIMD3(0.1, 0.35, 0.2), primitive: .cylinder, colorHex: "6B6E70"),
        CatalogItem(id: "kitchen.counter.quartz.white", name: "White Quartz Countertop", category: .kitchenFixture,
                    dimensions: SIMD3(2.44, 0.04, 0.65), primitive: .box, colorHex: "F2F0EC"),
        CatalogItem(id: "kitchen.counter.granite.black", name: "Black Granite Countertop", category: .kitchenFixture,
                    dimensions: SIMD3(2.44, 0.04, 0.65), primitive: .box, colorHex: "2A2A2A"),
        CatalogItem(id: "kitchen.backsplash.subway", name: "Subway Tile Backsplash", category: .kitchenFixture,
                    dimensions: SIMD3(2.44, 0.5, 0.02), primitive: .plane, colorHex: "F0F0EC"),
        CatalogItem(id: "kitchen.hood.chimney", name: "Chimney Range Hood (36in)", category: .kitchenFixture,
                    dimensions: SIMD3(0.91, 0.6, 0.5), primitive: .box, colorHex: "C0C0C0"),
        CatalogItem(id: "kitchen.pantry.cabinet", name: "Floor-to-Ceiling Pantry", category: .kitchenFixture,
                    dimensions: SIMD3(0.9, 2.4, 0.65), primitive: .box, colorHex: "D9CBB5"),
    ]

    // MARK: - Bathroom fixtures

    static let bathroomFixtures: [CatalogItem] = [
        CatalogItem(id: "bath.vanity.single", name: "Single Vanity (36in)", category: .bathroomFixture,
                    dimensions: SIMD3(0.91, 0.85, 0.55), primitive: .box, colorHex: "E6E1D6"),
        CatalogItem(id: "bath.vanity.double", name: "Double Vanity (60in)", category: .bathroomFixture,
                    dimensions: SIMD3(1.52, 0.85, 0.55), primitive: .box, colorHex: "E6E1D6"),
        CatalogItem(id: "bath.toilet.std", name: "Standard Toilet", category: .bathroomFixture,
                    dimensions: SIMD3(0.38, 0.75, 0.68), primitive: .roundedBox, colorHex: "FFFFFF"),
        CatalogItem(id: "bath.tub.alcove", name: "Alcove Soaking Tub (60in)", category: .bathroomFixture,
                    dimensions: SIMD3(1.52, 0.55, 0.76), primitive: .roundedBox, colorHex: "FFFFFF"),
        CatalogItem(id: "bath.tub.freestanding", name: "Freestanding Soaking Tub", category: .bathroomFixture,
                    dimensions: SIMD3(1.68, 0.6, 0.76), primitive: .roundedBox, colorHex: "F7F7F4"),
        CatalogItem(id: "bath.shower.walkin", name: "Walk-In Shower Enclosure (36x48in)", category: .bathroomFixture,
                    dimensions: SIMD3(0.91, 2.0, 1.22), primitive: .box, colorHex: "D7E6EC",
                    note: "Frameless glass placeholder"),
        CatalogItem(id: "bath.showerpan", name: "Shower Pan / Base", category: .bathroomFixture,
                    dimensions: SIMD3(0.91, 0.1, 1.22), primitive: .box, colorHex: "E9E9E6"),
        CatalogItem(id: "bath.mirror.vanity", name: "Vanity Mirror", category: .bathroomFixture,
                    dimensions: SIMD3(0.9, 0.9, 0.02), primitive: .plane, colorHex: "AEE1F5"),
        CatalogItem(id: "bath.linencloset", name: "Linen Closet", category: .bathroomFixture,
                    dimensions: SIMD3(0.6, 2.1, 0.45), primitive: .box, colorHex: "E6E1D6"),
    ]

    // MARK: - Appliances

    static let appliances: [CatalogItem] = [
        CatalogItem(id: "appliance.fridge.counterdepth", name: "Counter-Depth Refrigerator", category: .appliance,
                    dimensions: SIMD3(0.91, 1.78, 0.71), primitive: .box, colorHex: "D6D9DB"),
        CatalogItem(id: "appliance.range.30in", name: "30in Range / Oven", category: .appliance,
                    dimensions: SIMD3(0.76, 0.9, 0.66), primitive: .box, colorHex: "3A3A3A"),
        CatalogItem(id: "appliance.dishwasher", name: "Built-In Dishwasher", category: .appliance,
                    dimensions: SIMD3(0.6, 0.85, 0.6), primitive: .box, colorHex: "C7CBCD"),
        CatalogItem(id: "appliance.microwave.builtin", name: "Built-In Microwave", category: .appliance,
                    dimensions: SIMD3(0.76, 0.4, 0.4), primitive: .box, colorHex: "3A3A3A"),
        CatalogItem(id: "appliance.washer", name: "Front-Load Washer", category: .appliance,
                    dimensions: SIMD3(0.68, 0.95, 0.73), primitive: .box, colorHex: "EFEFEF"),
        CatalogItem(id: "appliance.dryer", name: "Front-Load Dryer", category: .appliance,
                    dimensions: SIMD3(0.68, 0.95, 0.73), primitive: .box, colorHex: "EFEFEF"),
        CatalogItem(id: "appliance.winefridge", name: "Built-In Wine Fridge", category: .appliance,
                    dimensions: SIMD3(0.38, 0.87, 0.6), primitive: .box, colorHex: "2A2A2A"),
    ]

    // MARK: - Furniture

    static let furniture: [CatalogItem] = [
        CatalogItem(id: "furn.sofa.3seat", name: "3-Seat Sofa", category: .furniture,
                    dimensions: SIMD3(2.1, 0.85, 0.95), primitive: .roundedBox, colorHex: "8C9AA6"),
        CatalogItem(id: "furn.sectional.L", name: "L-Shaped Sectional", category: .furniture,
                    dimensions: SIMD3(2.7, 0.85, 1.7), primitive: .roundedBox, colorHex: "8C9AA6"),
        CatalogItem(id: "furn.coffeetable", name: "Coffee Table", category: .furniture,
                    dimensions: SIMD3(1.1, 0.45, 0.6), primitive: .roundedBox, colorHex: "6B5847"),
        CatalogItem(id: "furn.diningtable.6", name: "Dining Table (6-seat)", category: .furniture,
                    dimensions: SIMD3(1.8, 0.76, 0.9), primitive: .box, colorHex: "6B5847"),
        CatalogItem(id: "furn.diningchair", name: "Dining Chair", category: .furniture,
                    dimensions: SIMD3(0.45, 0.9, 0.5), primitive: .roundedBox, colorHex: "4A3F35"),
        CatalogItem(id: "furn.bed.queen", name: "Queen Bed", category: .furniture,
                    dimensions: SIMD3(1.53, 0.6, 2.03), primitive: .roundedBox, colorHex: "9C8C7A"),
        CatalogItem(id: "furn.bed.king", name: "King Bed", category: .furniture,
                    dimensions: SIMD3(1.93, 0.6, 2.03), primitive: .roundedBox, colorHex: "9C8C7A"),
        CatalogItem(id: "furn.nightstand", name: "Nightstand", category: .furniture,
                    dimensions: SIMD3(0.5, 0.55, 0.42), primitive: .box, colorHex: "6B5847"),
        CatalogItem(id: "furn.dresser", name: "6-Drawer Dresser", category: .furniture,
                    dimensions: SIMD3(1.5, 0.8, 0.5), primitive: .box, colorHex: "6B5847"),
        CatalogItem(id: "furn.desk", name: "Office Desk", category: .furniture,
                    dimensions: SIMD3(1.4, 0.75, 0.7), primitive: .box, colorHex: "4A3F35"),
        CatalogItem(id: "furn.bookshelf", name: "Bookshelf (5ft)", category: .furniture,
                    dimensions: SIMD3(0.9, 1.8, 0.35), primitive: .box, colorHex: "6B5847"),
        CatalogItem(id: "furn.tvstand", name: "TV Stand", category: .furniture,
                    dimensions: SIMD3(1.6, 0.5, 0.45), primitive: .box, colorHex: "3A3A3A"),
        CatalogItem(id: "furn.rug.area", name: "Area Rug (8x10)", category: .furniture,
                    dimensions: SIMD3(2.44, 0.01, 3.05), primitive: .plane, colorHex: "C4B29A"),
    ]

    // MARK: - Lighting

    static let lighting: [CatalogItem] = [
        CatalogItem(id: "light.pendant.kitchen", name: "Kitchen Island Pendant", category: .lighting,
                    dimensions: SIMD3(0.3, 0.4, 0.3), primitive: .cylinder, colorHex: "C8A165"),
        CatalogItem(id: "light.chandelier.dining", name: "Dining Chandelier", category: .lighting,
                    dimensions: SIMD3(0.7, 0.5, 0.7), primitive: .cylinder, colorHex: "D4AF37"),
        CatalogItem(id: "light.recessed.can", name: "Recessed Can Light", category: .lighting,
                    dimensions: SIMD3(0.15, 0.08, 0.15), primitive: .cylinder, colorHex: "EDEDED"),
        CatalogItem(id: "light.sconce.vanity", name: "Vanity Wall Sconce", category: .lighting,
                    dimensions: SIMD3(0.15, 0.3, 0.1), primitive: .cylinder, colorHex: "C0C0C0"),
        CatalogItem(id: "light.floorlamp", name: "Floor Lamp", category: .lighting,
                    dimensions: SIMD3(0.4, 1.6, 0.4), primitive: .cylinder, colorHex: "3A3A3A"),
    ]

    // MARK: - Outdoor

    static let outdoor: [CatalogItem] = [
        CatalogItem(id: "outdoor.deck.composite", name: "Composite Deck Section", category: .outdoor,
                    dimensions: SIMD3(3.0, 0.15, 3.0), primitive: .box, colorHex: "7A5C44"),
        CatalogItem(id: "outdoor.patio.pavers", name: "Paver Patio Section", category: .outdoor,
                    dimensions: SIMD3(3.0, 0.05, 3.0), primitive: .plane, colorHex: "AFA79B"),
        CatalogItem(id: "outdoor.pergola", name: "Pergola (10x10)", category: .outdoor,
                    dimensions: SIMD3(3.05, 2.4, 3.05), primitive: .box, colorHex: "6B5847"),
        CatalogItem(id: "outdoor.fence.privacy", name: "Privacy Fence Section (8ft)", category: .outdoor,
                    dimensions: SIMD3(2.44, 1.83, 0.1), primitive: .box, colorHex: "8A7254"),
        CatalogItem(id: "outdoor.grill.builtin", name: "Built-In Grill Island", category: .outdoor,
                    dimensions: SIMD3(1.5, 0.95, 0.7), primitive: .box, colorHex: "4A4A4A"),
        CatalogItem(id: "outdoor.firepit", name: "Fire Pit", category: .outdoor,
                    dimensions: SIMD3(1.0, 0.4, 1.0), primitive: .cylinder, colorHex: "6B6358"),
        CatalogItem(id: "outdoor.shed", name: "Storage Shed (10x12)", category: .outdoor,
                    dimensions: SIMD3(3.66, 2.4, 3.05), primitive: .box, colorHex: "8A9A8C"),
        CatalogItem(id: "outdoor.pool.inground", name: "In-Ground Pool Footprint (16x32)", category: .outdoor,
                    dimensions: SIMD3(4.9, 0.1, 9.75), primitive: .plane, colorHex: "4FA7C9"),
        CatalogItem(id: "outdoor.hottub", name: "Hot Tub", category: .outdoor,
                    dimensions: SIMD3(2.1, 0.9, 2.1), primitive: .roundedBox, colorHex: "3A4A52"),
        CatalogItem(id: "outdoor.plantings.hedge", name: "Hedge Row Section", category: .outdoor,
                    dimensions: SIMD3(2.0, 1.2, 0.6), primitive: .box, colorHex: "4F7A4A"),
    ]
}
