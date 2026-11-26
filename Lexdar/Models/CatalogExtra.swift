import Foundation

/// The expanded library: more flooring, wall and exterior finishes, roofs,
/// stairs, doors and windows, foundations and structures, landscaping, and
/// furnishings for every room. Everything is built from shapes (see
/// `ItemModels`), so no outside assets are needed. Dimensions are meters
/// (width, height, depth). Item ids carry the keywords `ItemModels` and
/// `MaterialTextures` use to choose a shape or texture, so keep the naming
/// pattern when adding more.
private typealias Row = (id: String, name: String, w: Float, h: Float, d: Float, shape: CatalogPrimitive, hex: String)

extension Catalog {
    private static func make(_ category: CatalogCategory, _ rows: [Row]) -> [CatalogItem] {
        rows.map {
            CatalogItem(id: $0.id, name: $0.name, category: category,
                        dimensions: SIMD3<Float>($0.w, $0.h, $0.d), primitive: $0.shape, colorHex: $0.hex)
        }
    }

    // MARK: - Flooring

    static let moreFlooring: [CatalogItem] = make(.flooring, [
        ("floor.oak.white", "Whitewashed Oak", 1, 0.02, 1, .plane, "D9CDB8"),
        ("floor.oak.herringbone", "Oak Herringbone", 1, 0.02, 1, .plane, "B98F5A"),
        ("floor.hickory.rustic", "Rustic Hickory Plank", 1, 0.02, 1, .plane, "A07850"),
        ("floor.maple.light", "Light Maple", 1, 0.02, 1, .plane, "E0C79A"),
        ("floor.cherry.rich", "Cherry Hardwood", 1, 0.02, 1, .plane, "8C4B2F"),
        ("floor.ebony.stain", "Ebony Stained Plank", 1, 0.02, 1, .plane, "3B2A22"),
        ("floor.barnwood.reclaimed", "Reclaimed Barnwood", 1, 0.02, 1, .plane, "8F7B66"),
        ("floor.bamboo.natural", "Natural Bamboo", 1, 0.02, 1, .plane, "D8B87A"),
        ("floor.laminate.gray", "Gray Laminate Plank", 1, 0.02, 1, .plane, "9A9890"),
        ("floor.lvp.walnut", "Walnut-Look Vinyl Plank", 1, 0.02, 1, .plane, "7A5A43"),
        ("floor.tile.slate", "Natural Slate Tile", 1, 0.02, 1, .plane, "5E6468"),
        ("floor.tile.terracotta", "Terracotta Tile", 1, 0.02, 1, .plane, "B5643C"),
        ("floor.tile.travertine", "Travertine Tile", 1, 0.02, 1, .plane, "D8C9AC"),
        ("floor.tile.black.large", "Large Black Porcelain Tile", 1, 0.02, 1, .plane, "2B2D30"),
        ("floor.tile.white.large", "Large White Porcelain Tile", 1, 0.02, 1, .plane, "ECEBE8"),
        ("floor.tile.mosaic.blue", "Blue Mosaic Tile", 1, 0.02, 1, .plane, "5F8FA8"),
        ("floor.stone.limestone", "Limestone Flagstone", 1, 0.02, 1, .plane, "CFC6B4"),
        ("floor.stone.flagstone", "Irregular Flagstone", 1, 0.02, 1, .plane, "8E8A80"),
        ("floor.terrazzo", "Terrazzo", 1, 0.02, 1, .plane, "D9D5CC"),
        ("floor.epoxy.garage", "Gray Epoxy Garage Floor", 1, 0.02, 1, .plane, "7C8084"),
        ("floor.concrete.stained", "Stained Concrete", 1, 0.02, 1, .plane, "A38F78"),
        ("floor.carpet.gray", "Gray Cut-Pile Carpet", 1, 0.02, 1, .plane, "8E9092"),
        ("floor.carpet.berber", "Berber Carpet", 1, 0.02, 1, .plane, "C9BFAE"),
        ("floor.cork", "Cork Flooring", 1, 0.02, 1, .plane, "B88B5A"),
        ("floor.rubber.gym", "Rubber Gym Flooring", 1, 0.02, 1, .plane, "2F3033"),
        ("floor.brick.paver", "Brick Paver Floor", 1, 0.02, 1, .plane, "A4553A"),
    ])

    // MARK: - Interior wall finishes

    static let moreWallFinishes: [CatalogItem] = make(.wallFinish, [
        ("wall.paint.charcoal", "Charcoal Paint", 1, 1, 0.01, .plane, "3A3D40"),
        ("wall.paint.black", "Matte Black Paint", 1, 1, 0.01, .plane, "1E1F21"),
        ("wall.paint.terracotta", "Terracotta Paint", 1, 1, 0.01, .plane, "B9714E"),
        ("wall.paint.blush", "Blush Pink Paint", 1, 1, 0.01, .plane, "E6C7C0"),
        ("wall.paint.mustard", "Mustard Paint", 1, 1, 0.01, .plane, "D2A53C"),
        ("wall.paint.teal", "Deep Teal Paint", 1, 1, 0.01, .plane, "2F6B70"),
        ("wall.paint.lavender", "Soft Lavender Paint", 1, 1, 0.01, .plane, "BDB2D4"),
        ("wall.paint.mint", "Mint Paint", 1, 1, 0.01, .plane, "BFE0CF"),
        ("wall.paint.cream", "Warm Cream Paint", 1, 1, 0.01, .plane, "F1E6CE"),
        ("wall.paint.lightgray", "Light Gray Paint", 1, 1, 0.01, .plane, "D5D6D6"),
        ("wall.paint.olive", "Olive Paint", 1, 1, 0.01, .plane, "7C8050"),
        ("wall.paint.skyblue", "Sky Blue Paint", 1, 1, 0.01, .plane, "A9C9E0"),
        ("wall.paint.slate", "Slate Blue Paint", 1, 1, 0.01, .plane, "5C6F80"),
        ("wall.tile.subway.gray", "Gray Subway Tile", 1, 1, 0.01, .plane, "A7ABAE"),
        ("wall.tile.subway.green", "Green Subway Tile", 1, 1, 0.01, .plane, "6E9A82"),
        ("wall.tile.subway.black", "Black Subway Tile", 1, 1, 0.01, .plane, "2B2C2E"),
        ("wall.tile.zellige.white", "White Zellige Tile", 1, 1, 0.01, .plane, "EDEAE2"),
        ("wall.tile.large.marble", "Large-Format Marble Tile", 1, 1, 0.01, .plane, "E3E1DC"),
        ("wall.tile.mosaic.glass", "Glass Mosaic Tile", 1, 1, 0.01, .plane, "7FB1BE"),
        ("wall.brick.exposed", "Exposed Brick", 1, 1, 0.01, .plane, "A4553A"),
        ("wall.brick.white", "Whitewashed Brick", 1, 1, 0.01, .plane, "E5E0D8"),
        ("wall.board.batten", "Board and Batten", 1, 1, 0.01, .plane, "EFEFEA"),
        ("wall.shiplap.gray", "Gray Shiplap", 1, 1, 0.01, .plane, "A9ADB0"),
        ("wall.shiplap.navy", "Navy Shiplap", 1, 1, 0.01, .plane, "2F3B55"),
        ("wall.wood.slat.walnut", "Walnut Slat Wall", 1, 1, 0.01, .plane, "6B4A34"),
        ("wall.stone.stacked", "Stacked Stone Veneer", 1, 1, 0.01, .plane, "8E8A80"),
        ("wall.concrete.board", "Board-Formed Concrete", 1, 1, 0.01, .plane, "A3A6A8"),
        ("wall.stucco.venetian", "Venetian Plaster", 1, 1, 0.01, .plane, "D9CDB5"),
        ("wall.wallpaper.stripe", "Striped Wallpaper", 1, 1, 0.01, .plane, "C7D1DC"),
        ("wall.wallpaper.floral", "Floral Wallpaper", 1, 1, 0.01, .plane, "D9B9B4"),
    ])

    // MARK: - Exterior finishes (applied to walls, like interior finishes)

    static let exteriorFinishes: [CatalogItem] = make(.exteriorFinish, [
        ("ext.siding.vinyl.white", "White Lap Siding", 1, 1, 0.01, .plane, "F0EEE8"),
        ("ext.siding.vinyl.gray", "Gray Lap Siding", 1, 1, 0.01, .plane, "9EA3A6"),
        ("ext.siding.vinyl.blue", "Blue Lap Siding", 1, 1, 0.01, .plane, "6F8FA8"),
        ("ext.siding.vinyl.sage", "Sage Lap Siding", 1, 1, 0.01, .plane, "98AA92"),
        ("ext.siding.vinyl.tan", "Tan Lap Siding", 1, 1, 0.01, .plane, "CDB894"),
        ("ext.siding.vinyl.red", "Barn Red Lap Siding", 1, 1, 0.01, .plane, "8E3B32"),
        ("ext.siding.fibercement.charcoal", "Charcoal Fiber-Cement Siding", 1, 1, 0.01, .plane, "45494D"),
        ("ext.siding.board.batten.white", "White Board and Batten", 1, 1, 0.01, .plane, "EEEDE7"),
        ("ext.siding.board.batten.black", "Black Board and Batten", 1, 1, 0.01, .plane, "26272A"),
        ("ext.shingle.cedar.shake", "Cedar Shake Siding", 1, 1, 0.01, .plane, "9C7A57"),
        ("ext.brick.red", "Red Brick", 1, 1, 0.01, .plane, "9E4A36"),
        ("ext.brick.painted.white", "Painted White Brick", 1, 1, 0.01, .plane, "ECE9E2"),
        ("ext.brick.gray", "Gray Brick", 1, 1, 0.01, .plane, "7E8083"),
        ("ext.stone.veneer.gray", "Gray Stone Veneer", 1, 1, 0.01, .plane, "8D8E8E"),
        ("ext.stone.veneer.tan", "Tan Stone Veneer", 1, 1, 0.01, .plane, "B8A88C"),
        ("ext.stucco.cream", "Cream Stucco", 1, 1, 0.01, .plane, "E6DAC0"),
        ("ext.stucco.terracotta", "Terracotta Stucco", 1, 1, 0.01, .plane, "C27A55"),
        ("ext.stucco.white", "White Stucco", 1, 1, 0.01, .plane, "F1EFEA"),
        ("ext.metal.corrugated", "Corrugated Metal Siding", 1, 1, 0.01, .plane, "A9AEB2"),
        ("ext.metal.standingseam.black", "Black Standing-Seam Metal", 1, 1, 0.01, .plane, "2A2B2D"),
        ("ext.wood.cedar.natural", "Natural Cedar Cladding", 1, 1, 0.01, .plane, "B07F52"),
        ("ext.wood.charred", "Charred Wood (Shou Sugi Ban)", 1, 1, 0.01, .plane, "262321"),
        ("ext.log.round", "Round Log Siding", 1, 1, 0.01, .plane, "8A5F3C"),
    ])

    // MARK: - Roofs (placed over the building; pinch to resize)

    static let roofs: [CatalogItem] = make(.roofing, [
        ("roof.gable.asphalt.charcoal", "Gable Roof, Charcoal Shingle (10x8 m)", 10, 2.6, 8, .box, "4A4D50"),
        ("roof.gable.asphalt.brown", "Gable Roof, Brown Shingle", 10, 2.6, 8, .box, "6A4F3E"),
        ("roof.gable.asphalt.gray", "Gable Roof, Weathered Gray Shingle", 10, 2.6, 8, .box, "7B7E80"),
        ("roof.gable.metal.black", "Gable Roof, Black Standing-Seam Metal", 10, 2.6, 8, .box, "2B2C2E"),
        ("roof.gable.metal.red", "Gable Roof, Red Metal", 10, 2.6, 8, .box, "8E3B32"),
        ("roof.gable.metal.green", "Gable Roof, Green Metal", 10, 2.6, 8, .box, "3F5F4A"),
        ("roof.gable.slate", "Gable Roof, Slate", 10, 2.6, 8, .box, "56606A"),
        ("roof.gable.clay.tile", "Gable Roof, Clay Tile", 10, 2.6, 8, .box, "B5643C"),
        ("roof.gable.cedar.shake", "Gable Roof, Cedar Shake", 10, 2.6, 8, .box, "8A6A4A"),
        ("roof.hip.asphalt.charcoal", "Hip Roof, Charcoal Shingle", 10, 2.4, 8, .box, "4A4D50"),
        ("roof.hip.metal.gray", "Hip Roof, Gray Metal", 10, 2.4, 8, .box, "8E9396"),
        ("roof.hip.clay.tile", "Hip Roof, Clay Tile", 10, 2.4, 8, .box, "B5643C"),
        ("roof.shed.metal", "Shed Roof, Metal (6x4 m)", 6, 1.4, 4, .box, "6E7377"),
        ("roof.shed.membrane", "Shed Roof, Membrane", 6, 1.2, 4, .box, "55585B"),
        ("roof.flat.membrane", "Flat Roof, Membrane (10x8 m)", 10, 0.3, 8, .box, "4B4E51"),
        ("roof.dormer.gable", "Gable Dormer", 2.2, 1.4, 2.4, .box, "4A4D50"),
        ("roof.porch.gable", "Covered Porch Gable (4x3 m)", 4, 1.4, 3, .box, "4A4D50"),
        ("roof.chimney.brick", "Brick Chimney", 0.7, 2.2, 0.7, .box, "9E4A36"),
    ])

    // MARK: - Stairs

    static let stairs: [CatalogItem] = make(.stairs, [
        ("stairs.straight.std", "Straight Stairs (3 ft wide)", 0.92, 2.7, 3.6, .box, "A07850"),
        ("stairs.straight.wide", "Wide Straight Stairs (4 ft)", 1.22, 2.7, 3.6, .box, "A07850"),
        ("stairs.straight.painted", "Straight Stairs, Painted White", 0.92, 2.7, 3.6, .box, "ECEAE4"),
        ("stairs.straight.basement", "Basement Stairs", 0.92, 2.6, 3.4, .box, "9A8B78"),
        ("stairs.lshape.landing", "L-Shaped Stairs with Landing", 2.2, 2.7, 3.4, .box, "A07850"),
        ("stairs.winder", "Winder Stairs", 2.0, 2.7, 3.0, .box, "A07850"),
        ("stairs.ushape.landing", "U-Shaped Stairs", 2.3, 2.7, 3.2, .box, "A07850"),
        ("stairs.spiral.metal", "Spiral Stairs (5 ft)", 1.5, 2.7, 1.5, .cylinder, "3C3F42"),
        ("stairs.spiral.wood", "Spiral Stairs, Wood Treads", 1.7, 2.7, 1.7, .cylinder, "8C6A4A"),
        ("stairs.floating.open", "Floating Open-Riser Stairs", 1.0, 2.7, 3.6, .box, "6B4A34"),
        ("stairs.ramp.accessible", "Accessible Ramp (1:12)", 1.2, 0.6, 7.3, .box, "9FA3A6"),
        ("stairs.deck.exterior", "Exterior Deck Stairs", 1.2, 1.0, 2.0, .box, "7A5C44"),
        ("stairs.porch.front", "Front Porch Steps", 1.8, 0.7, 1.2, .box, "A9A59B"),
    ])

    // MARK: - Doors and windows

    static let doorsAndWindows: [CatalogItem] = make(.doorWindow, [
        ("door.interior.panel", "Interior Panel Door (32in)", 0.81, 2.03, 0.1, .box, "E8E2D6"),
        ("door.interior.flush", "Interior Flush Door, Walnut", 0.81, 2.03, 0.1, .box, "6B4A34"),
        ("door.interior.double", "Double Interior Doors", 1.5, 2.03, 0.1, .box, "E8E2D6"),
        ("door.pocket", "Pocket Door", 0.81, 2.03, 0.1, .box, "E8E2D6"),
        ("door.barn.sliding", "Sliding Barn Door", 0.95, 2.1, 0.1, .box, "6B4A34"),
        ("door.exterior.front", "Front Entry Door", 0.91, 2.1, 0.1, .box, "2F4A63"),
        ("door.exterior.front.red", "Front Entry Door, Red", 0.91, 2.1, 0.1, .box, "8E3B32"),
        ("door.exterior.french", "French Doors (5 ft)", 1.5, 2.1, 0.1, .box, "ECEAE4"),
        ("door.exterior.slidingglass", "Sliding Glass Door (6 ft)", 1.8, 2.1, 0.1, .box, "3C3F42"),
        ("door.exterior.slidingglass.wide", "Sliding Glass Door (8 ft)", 2.4, 2.1, 0.1, .box, "3C3F42"),
        ("door.garage.single", "Garage Door, Single (9 ft)", 2.74, 2.13, 0.1, .box, "E8E4DA"),
        ("door.garage.double", "Garage Door, Double (16 ft)", 4.88, 2.13, 0.1, .box, "E8E4DA"),
        ("window.double.hung", "Double-Hung Window (3x4 ft)", 0.91, 1.22, 0.1, .box, "ECEAE4"),
        ("window.casement", "Casement Window", 0.76, 1.22, 0.1, .box, "ECEAE4"),
        ("window.picture", "Picture Window (6x4 ft)", 1.83, 1.22, 0.1, .box, "ECEAE4"),
        ("window.sliding", "Sliding Window (5x3 ft)", 1.52, 0.91, 0.1, .box, "ECEAE4"),
        ("window.black.frame", "Black-Frame Window (3x5 ft)", 0.91, 1.52, 0.1, .box, "2A2B2D"),
        ("window.transom", "Transom Window", 1.2, 0.4, 0.1, .box, "ECEAE4"),
        ("window.bay", "Bay Window", 2.0, 1.4, 0.7, .box, "ECEAE4"),
    ])

    // MARK: - Foundations and structures

    static let structures: [CatalogItem] = make(.structure, [
        ("found.slab.ongrade", "Concrete Slab-on-Grade (10x8 m)", 10, 0.15, 8, .box, "A3A6A8"),
        ("found.slab.floor.upper", "Upper Floor Deck (10x8 m)", 10, 0.25, 8, .box, "B79F7E"),
        ("found.footing.strip", "Strip Footing (10x8 m)", 10, 0.25, 8, .box, "8E9194"),
        ("found.stemwall.crawl", "Crawlspace Stem Wall (10x8 m)", 10, 0.9, 8, .box, "9A9C9E"),
        ("found.basement.full", "Full Basement Walls (10x8 m)", 10, 2.4, 8, .box, "9A9C9E"),
        ("found.pier.beam", "Pier and Beam Foundation (10x8 m)", 10, 0.8, 8, .box, "8E9194"),
        ("struct.garage.single", "Single Garage (3.6x6 m)", 3.6, 3.2, 6, .box, "D9D4C7"),
        ("struct.garage.double", "Double Garage (6.4x6.4 m)", 6.4, 3.4, 6.4, .box, "D9D4C7"),
        ("struct.carport", "Carport (3.6x6 m)", 3.6, 2.8, 6, .box, "8E9396"),
        ("struct.shed.gable", "Garden Shed (3x3 m)", 3, 2.9, 3, .box, "8A9A8C"),
        ("struct.barn.small", "Small Barn (6x9 m)", 6, 5, 9, .box, "8E3B32"),
        ("struct.adu.cottage", "Backyard Cottage / ADU (5x7 m)", 5, 4, 7, .box, "E6DAC0"),
        ("struct.poolhouse", "Pool House (4x5 m)", 4, 3.4, 5, .box, "E6DAC0"),
        ("struct.gazebo.hex", "Gazebo (3.6 m)", 3.6, 3.2, 3.6, .box, "E8E4DA"),
        ("struct.pergola.attached", "Pergola (4x4 m)", 4, 2.6, 4, .box, "8A6A4A"),
        ("struct.greenhouse", "Greenhouse (3x4 m)", 3, 2.8, 4, .box, "9FC5CC"),
    ])

    // MARK: - Landscaping

    static let landscaping: [CatalogItem] = make(.landscaping, [
        ("land.tree.oak", "Oak Tree", 7, 9, 7, .box, "4F7A3A"),
        ("land.tree.maple", "Maple Tree", 6, 8, 6, .box, "5E8A3A"),
        ("land.tree.maple.red", "Japanese Maple", 3.5, 4, 3.5, .box, "9C3A3A"),
        ("land.tree.birch", "Birch Tree", 4, 8, 4, .box, "7FA054"),
        ("land.tree.cherry", "Flowering Cherry", 5, 5, 5, .box, "E6A9C1"),
        ("land.tree.dogwood", "Dogwood", 4, 4, 4, .box, "EFE3E3"),
        ("land.tree.apple", "Apple Tree", 4.5, 4.5, 4.5, .box, "5E8A3A"),
        ("land.tree.pine", "White Pine", 4.5, 12, 4.5, .box, "2F5A3A"),
        ("land.tree.spruce", "Blue Spruce", 3.5, 9, 3.5, .box, "476F7C"),
        ("land.tree.cedar", "Arborvitae", 1.5, 5, 1.5, .box, "2F5A3A"),
        ("land.tree.palm", "Palm Tree", 3.5, 7, 3.5, .box, "4E8A3A"),
        ("land.shrub.boxwood", "Boxwood Shrub", 1, 1, 1, .box, "3F6B3A"),
        ("land.shrub.hydrangea", "Hydrangea", 1.4, 1.2, 1.4, .box, "9DB4D8"),
        ("land.shrub.rhododendron", "Rhododendron", 1.6, 1.4, 1.6, .box, "C46AA0"),
        ("land.shrub.juniper", "Juniper", 1.5, 0.8, 1.5, .box, "4A7A5A"),
        ("land.shrub.lilac", "Lilac Bush", 2, 2, 2, .box, "A58FC2"),
        ("land.hedge.row", "Hedge Row (4 m)", 4, 1.4, 0.7, .box, "3F6B3A"),
        ("land.flower.bed.mixed", "Mixed Flower Bed (2x1 m)", 2, 0.5, 1, .box, "D96C8A"),
        ("land.flower.bed.roses", "Rose Garden Bed", 2, 0.9, 1, .box, "C03A4A"),
        ("land.flower.bed.lavender", "Lavender Row", 2, 0.6, 0.6, .box, "8F7BC0"),
        ("land.flower.bed.sunflowers", "Sunflowers", 2, 1.6, 0.8, .box, "E2B72E"),
        ("land.flower.bed.tulips", "Tulip Bed", 2, 0.4, 1, .box, "E26A5A"),
        ("land.grass.lawn", "Lawn Patch (6x6 m)", 6, 0.02, 6, .plane, "5E8F3F"),
        ("land.mulch.bed", "Mulch Bed (3x1.5 m)", 3, 0.02, 1.5, .plane, "5B4332"),
        ("land.gravel.patch", "Gravel Area (4x4 m)", 4, 0.02, 4, .plane, "B3AEA3"),
        ("land.path.flagstone", "Flagstone Path (1x4 m)", 1, 0.02, 4, .plane, "8E8A80"),
        ("land.path.paver", "Paver Walkway (1.2x5 m)", 1.2, 0.02, 5, .plane, "A4553A"),
        ("land.driveway.asphalt", "Asphalt Driveway (3.5x10 m)", 3.5, 0.02, 10, .plane, "4B4D50"),
        ("land.driveway.concrete", "Concrete Driveway (3.5x10 m)", 3.5, 0.02, 10, .plane, "AEB0B1"),
        ("land.sidewalk.concrete", "Concrete Sidewalk (1.2x6 m)", 1.2, 0.02, 6, .plane, "B6B8B9"),
        ("land.retaining.wall", "Block Retaining Wall (4 m)", 4, 0.9, 0.4, .box, "9A9C9E"),
        ("land.stone.wall.low", "Low Stone Wall (4 m)", 4, 0.7, 0.45, .box, "8E8A80"),
        ("land.boulder.large", "Boulder", 1.4, 0.9, 1.2, .sphere, "8A8A86"),
        ("land.raised.bed.garden", "Raised Garden Bed (1.2x2.4 m)", 1.2, 0.4, 2.4, .box, "7A5C44"),
        ("land.fountain.tiered", "Tiered Fountain", 1.4, 1.6, 1.4, .cylinder, "B5B5AF"),
        ("land.pond.garden", "Garden Pond (3x2 m)", 3, 0.2, 2, .box, "4A8FA8"),
        ("land.planter.large", "Large Planter", 0.7, 1.1, 0.7, .cylinder, "7C7F82"),
        ("land.arbor.rose", "Garden Arbor", 1.4, 2.4, 0.8, .box, "ECEAE4"),
        ("land.fence.picket", "Picket Fence (2.4 m)", 2.4, 1.1, 0.06, .box, "F0EEE8"),
        ("land.fence.wrought", "Wrought-Iron Fence (2.4 m)", 2.4, 1.4, 0.05, .box, "2A2B2D"),
        ("land.fence.chainlink", "Chain-Link Fence (2.4 m)", 2.4, 1.2, 0.04, .box, "A9AEB2"),
        ("land.mailbox", "Mailbox", 0.25, 1.2, 0.5, .box, "2A2B2D"),
    ])

    // MARK: - More kitchen

    static let moreKitchen: [CatalogItem] = make(.kitchenFixture, [
        ("kitchen.island.waterfall", "Waterfall Island (8 ft)", 2.44, 0.92, 1.1, .box, "E8E4DC"),
        ("kitchen.island.seating", "Island with Seating (7 ft)", 2.13, 0.92, 1.3, .box, "D9CBB5"),
        ("kitchen.peninsula", "Peninsula Counter (6 ft)", 1.83, 0.92, 0.95, .box, "E8E4DC"),
        ("kitchen.cabinets.base.modern", "Modern Slab Base Cabinets (8 ft)", 2.44, 0.9, 0.6, .box, "2F3033"),
        ("kitchen.cabinets.base.shaker", "Shaker Base Cabinets (8 ft)", 2.44, 0.9, 0.6, .box, "E6E1D6"),
        ("kitchen.cabinets.upper.modern", "Modern Upper Cabinets (8 ft)", 2.44, 0.75, 0.32, .box, "2F3033"),
        ("kitchen.cabinets.upper.shaker", "Shaker Upper Cabinets (8 ft)", 2.44, 0.75, 0.32, .box, "E6E1D6"),
        ("kitchen.cabinets.base.navy", "Navy Base Cabinets (8 ft)", 2.44, 0.9, 0.6, .box, "2F3B55"),
        ("kitchen.cabinets.base.sage", "Sage Base Cabinets (8 ft)", 2.44, 0.9, 0.6, .box, "8FA38A"),
        ("kitchen.cabinets.tall.oven", "Tall Oven Cabinet", 0.76, 2.2, 0.62, .box, "D9CBB5"),
        ("kitchen.sink.apron.stainless", "Stainless Apron Sink", 0.86, 0.25, 0.5, .box, "C7CBCD"),
        ("kitchen.sink.workstation", "Workstation Sink (33 in)", 0.84, 0.25, 0.46, .box, "C7CBCD"),
        ("kitchen.hood.island", "Island Range Hood", 0.9, 0.9, 0.6, .box, "C0C0C0"),
        ("kitchen.hood.undercabinet", "Under-Cabinet Hood", 0.76, 0.15, 0.5, .box, "C0C0C0"),
        ("kitchen.counter.butcherblock", "Butcher-Block Countertop", 2.44, 0.05, 0.65, .box, "B88B5A"),
        ("kitchen.counter.marble", "Marble Countertop", 2.44, 0.04, 0.65, .box, "EDEBE6"),
        ("kitchen.counter.concrete", "Concrete Countertop", 2.44, 0.05, 0.65, .box, "9FA3A6"),
        ("kitchen.bar.cart", "Bar Cart", 0.8, 0.9, 0.45, .box, "3C3F42"),
        ("kitchen.nook.breakfast", "Breakfast Nook Booth", 1.8, 0.9, 1.6, .box, "9C8C7A"),
        ("kitchen.pantry.walkin", "Walk-In Pantry Shelving", 1.8, 2.1, 0.5, .box, "E6E1D6"),
    ])

    // MARK: - More bathroom (free-standing tubs, glass showers, vanities)

    static let moreBathroom: [CatalogItem] = make(.bathroomFixture, [
        ("bath.tub.freestanding.oval", "Freestanding Oval Tub (67 in)", 1.7, 0.6, 0.8, .roundedBox, "F7F7F4"),
        ("bath.tub.freestanding.clawfoot", "Clawfoot Tub", 1.7, 0.75, 0.75, .roundedBox, "F7F7F4"),
        ("bath.tub.freestanding.modern", "Modern Freestanding Tub", 1.65, 0.58, 0.75, .roundedBox, "FFFFFF"),
        ("bath.tub.freestanding.slipper", "Slipper Tub", 1.6, 0.7, 0.75, .roundedBox, "F7F7F4"),
        ("bath.tub.corner", "Corner Soaking Tub", 1.5, 0.55, 1.5, .roundedBox, "FFFFFF"),
        ("bath.tub.dropin", "Drop-In Tub with Deck", 1.8, 0.6, 0.9, .roundedBox, "F7F7F4"),
        ("bath.shower.glass.walkin", "Glass Walk-In Shower (4x3 ft)", 1.22, 2.1, 0.91, .box, "D7E6EC"),
        ("bath.shower.glass.corner", "Glass Corner Shower (3x3 ft)", 0.91, 2.1, 0.91, .box, "D7E6EC"),
        ("bath.shower.glass.neoangle", "Glass Neo-Angle Shower", 1.0, 2.1, 1.0, .box, "D7E6EC"),
        ("bath.shower.glass.large", "Large Glass Shower (6x4 ft)", 1.83, 2.1, 1.22, .box, "D7E6EC"),
        ("bath.shower.glass.steam", "Glass Steam Shower", 1.4, 2.3, 1.2, .box, "D7E6EC"),
        ("bath.vanity.floating", "Floating Vanity (48 in)", 1.22, 0.55, 0.5, .box, "6B4A34"),
        ("bath.vanity.floating.double", "Floating Double Vanity (72 in)", 1.83, 0.55, 0.5, .box, "6B4A34"),
        ("bath.vanity.vessel", "Vanity with Vessel Sink", 0.91, 0.95, 0.5, .box, "E6E1D6"),
        ("bath.vanity.furniture", "Furniture-Style Vanity (60 in)", 1.52, 0.9, 0.55, .box, "3C3F42"),
        ("bath.sink.pedestal", "Pedestal Sink", 0.55, 0.85, 0.45, .box, "FFFFFF"),
        ("bath.toilet.wallhung", "Wall-Hung Toilet", 0.36, 0.4, 0.55, .box, "FFFFFF"),
        ("bath.toilet.onepiece", "One-Piece Toilet", 0.38, 0.75, 0.7, .box, "FFFFFF"),
        ("bath.bidet", "Bidet", 0.38, 0.4, 0.6, .box, "FFFFFF"),
        ("bath.mirror.round", "Round Mirror", 0.8, 0.8, 0.03, .box, "AEE1F5"),
        ("bath.mirror.led", "Backlit LED Mirror", 0.9, 0.7, 0.04, .box, "AEE1F5"),
        ("bath.towel.warmer", "Towel Warmer", 0.5, 1.0, 0.1, .box, "C0C0C0"),
    ])

    // MARK: - More appliances and mechanical

    static let moreAppliances: [CatalogItem] = make(.appliance, [
        ("appliance.fridge.sidebyside", "Side-by-Side Refrigerator", 0.92, 1.78, 0.76, .box, "D6D9DB"),
        ("appliance.fridge.frenchdoor", "French-Door Refrigerator", 0.91, 1.78, 0.74, .box, "D6D9DB"),
        ("appliance.fridge.undercounter", "Undercounter Fridge", 0.6, 0.85, 0.6, .box, "D6D9DB"),
        ("appliance.freezer.chest", "Chest Freezer", 1.0, 0.85, 0.6, .box, "EFEFEF"),
        ("appliance.range.36in", "36in Gas Range", 0.91, 0.92, 0.7, .box, "C0C0C0"),
        ("appliance.range.double", "Double Wall Oven", 0.76, 1.3, 0.6, .box, "3A3A3A"),
        ("appliance.range.cooktop", "Gas Cooktop (30 in)", 0.76, 0.1, 0.52, .box, "3A3A3A"),
        ("appliance.dishwasher.drawer", "Dishwasher Drawers", 0.6, 0.85, 0.6, .box, "C7CBCD"),
        ("appliance.washer.top", "Top-Load Washer", 0.69, 1.0, 0.7, .box, "EFEFEF"),
        ("appliance.washer.stacked", "Stacked Washer/Dryer", 0.69, 1.9, 0.7, .box, "EFEFEF"),
        ("appliance.hvac.furnace", "Gas Furnace", 0.55, 1.1, 0.6, .box, "9FA3A6"),
        ("appliance.waterheater.tank", "Water Heater (50 gal)", 0.6, 1.5, 0.6, .cylinder, "EFEFEF"),
        ("appliance.waterheater.tankless", "Tankless Water Heater", 0.4, 0.6, 0.2, .box, "EFEFEF"),
        ("appliance.heatpump.outdoor", "Outdoor Heat Pump Unit", 0.9, 0.8, 0.9, .box, "C0C0C0"),
        ("appliance.fireplace.gas", "Gas Fireplace with Mantel", 1.5, 1.2, 0.4, .box, "3A3A3A"),
        ("appliance.woodstove", "Wood Stove", 0.7, 0.9, 0.6, .box, "2A2B2D"),
    ])

    // MARK: - More furniture (every room)

    static let moreFurniture: [CatalogItem] = make(.furniture, [
        ("furn.loveseat", "Loveseat", 1.5, 0.85, 0.9, .roundedBox, "8C9AA6"),
        ("furn.armchair.accent", "Accent Armchair", 0.8, 0.85, 0.85, .roundedBox, "B07F52"),
        ("furn.recliner", "Recliner", 0.9, 1.05, 0.95, .roundedBox, "5E5148"),
        ("furn.ottoman", "Ottoman", 0.8, 0.42, 0.8, .roundedBox, "9C8C7A"),
        ("furn.futon", "Futon Sofa Bed", 1.9, 0.8, 0.95, .roundedBox, "6B7A86"),
        ("furn.coffeetable.round", "Round Coffee Table", 0.9, 0.42, 0.9, .cylinder, "6B5847"),
        ("furn.sidetable", "Side Table", 0.5, 0.55, 0.5, .box, "6B5847"),
        ("furn.console.table", "Console Table", 1.3, 0.8, 0.35, .box, "4A3F35"),
        ("furn.diningtable.round", "Round Dining Table (4-seat)", 1.2, 0.76, 1.2, .cylinder, "6B5847"),
        ("furn.diningtable.8", "Dining Table (8-seat)", 2.4, 0.76, 1.0, .box, "6B5847"),
        ("furn.bench.dining", "Dining Bench", 1.5, 0.46, 0.38, .box, "4A3F35"),
        ("furn.barstool", "Bar Stool", 0.42, 0.75, 0.42, .cylinder, "3C3F42"),
        ("furn.counterstool", "Counter Stool", 0.42, 0.65, 0.42, .cylinder, "3C3F42"),
        ("furn.deskchair", "Desk Chair", 0.6, 1.0, 0.6, .box, "2F3033"),
        ("furn.bed.twin", "Twin Bed", 0.99, 0.55, 1.9, .roundedBox, "9C8C7A"),
        ("furn.bed.full", "Full Bed", 1.37, 0.58, 1.9, .roundedBox, "9C8C7A"),
        ("furn.bed.bunk", "Bunk Bed", 1.0, 1.7, 2.0, .box, "8A6A4A"),
        ("furn.bed.crib", "Crib", 0.7, 0.95, 1.3, .box, "ECEAE4"),
        ("furn.nightstand.floating", "Floating Nightstand", 0.45, 0.25, 0.35, .box, "6B5847"),
        ("furn.dresser.tall", "Tall 5-Drawer Chest", 0.9, 1.3, 0.5, .box, "6B5847"),
        ("furn.credenza", "Credenza (6 ft)", 1.8, 0.75, 0.45, .box, "4A3F35"),
        ("furn.sideboard", "Sideboard", 1.6, 0.85, 0.45, .box, "6B5847"),
        ("furn.desk.l", "L-Shaped Desk", 1.8, 0.75, 1.5, .box, "4A3F35"),
        ("furn.desk.standing", "Standing Desk", 1.5, 1.05, 0.75, .box, "E8E2D6"),
        ("furn.bookshelf.tall", "Tall Bookshelf (7 ft)", 1.0, 2.1, 0.35, .box, "6B5847"),
        ("furn.tvstand.low", "Low Media Console", 1.8, 0.45, 0.42, .box, "3A3A3A"),
        ("furn.vanity.makeup", "Makeup Vanity", 1.0, 0.78, 0.45, .box, "ECEAE4"),
        ("furn.rug.runner", "Runner Rug (2.5x8 ft)", 0.76, 0.01, 2.44, .plane, "A88C74"),
        ("furn.rug.round", "Round Rug (6 ft)", 1.83, 0.01, 1.83, .plane, "C4B29A"),
    ])

    // MARK: - More lighting

    static let moreLighting: [CatalogItem] = make(.lighting, [
        ("light.pendant.cluster", "Pendant Cluster (3)", 0.8, 0.9, 0.3, .box, "C8A165"),
        ("light.pendant.linear", "Linear Island Pendant", 1.4, 0.8, 0.2, .box, "2A2B2D"),
        ("light.chandelier.modern", "Modern Ring Chandelier", 0.9, 0.8, 0.9, .cylinder, "2A2B2D"),
        ("light.chandelier.crystal", "Crystal Chandelier", 0.8, 0.9, 0.8, .cylinder, "E8E4DA"),
        ("light.ceilingfan", "Ceiling Fan with Light", 1.2, 0.35, 1.2, .cylinder, "6B5847"),
        ("light.lamp.table", "Table Lamp", 0.35, 0.6, 0.35, .cylinder, "E8E4DA"),
        ("light.track", "Track Lighting (1.5 m)", 1.5, 0.15, 0.1, .box, "2A2B2D"),
        ("light.wallsconce.pair", "Wall Sconce", 0.15, 0.3, 0.12, .cylinder, "C0C0C0"),
        ("light.lantern.outdoor", "Outdoor Lantern", 0.25, 0.45, 0.25, .cylinder, "2A2B2D"),
        ("light.recessed.can.wet", "Wet-Rated Recessed Light", 0.15, 0.08, 0.15, .cylinder, "EDEDED"),
    ])

    // MARK: - Decor and plants

    static let decor: [CatalogItem] = make(.decor, [
        ("decor.plant.fiddle", "Fiddle-Leaf Fig", 0.7, 1.6, 0.7, .box, "4F7A3A"),
        ("decor.plant.snake", "Snake Plant", 0.4, 0.9, 0.4, .box, "3F6B3A"),
        ("decor.plant.palm.indoor", "Indoor Palm", 0.9, 1.7, 0.9, .box, "4E8A3A"),
        ("decor.plant.succulent", "Succulent Planter", 0.3, 0.25, 0.3, .box, "6E9A82"),
        ("decor.tv.65", "65in TV (wall mounted)", 1.45, 0.85, 0.06, .box, "1E1F21"),
        ("decor.tv.85", "85in TV (wall mounted)", 1.9, 1.1, 0.06, .box, "1E1F21"),
        ("decor.art.large", "Large Wall Art", 1.2, 0.9, 0.04, .box, "8FA3B5"),
        ("decor.mirror.floor", "Full-Length Mirror", 0.6, 1.7, 0.05, .box, "AEE1F5"),
        ("decor.mirror.round", "Round Wall Mirror", 0.9, 0.9, 0.04, .box, "AEE1F5"),
        ("decor.curtains.pair", "Curtain Panels (pair)", 1.8, 2.4, 0.1, .box, "C9C1B4"),
        ("decor.clock.wall", "Wall Clock", 0.5, 0.5, 0.05, .cylinder, "2A2B2D"),
    ])

    // MARK: - Storage and closets

    static let storage: [CatalogItem] = make(.storage, [
        ("storage.wardrobe.double", "Double Wardrobe", 1.5, 2.1, 0.6, .box, "E8E2D6"),
        ("storage.closet.reachin", "Reach-In Closet System", 1.8, 2.3, 0.6, .box, "E8E2D6"),
        ("storage.closet.walkin", "Walk-In Closet Island", 1.4, 1.0, 0.6, .box, "6B5847"),
        ("storage.shelf.wall", "Floating Wall Shelf", 1.0, 0.05, 0.25, .box, "6B5847"),
        ("storage.lockers.mudroom", "Mudroom Lockers", 1.8, 2.1, 0.5, .box, "E8E2D6"),
        ("storage.cabinet.laundry", "Laundry Cabinet", 0.9, 2.1, 0.45, .box, "E8E2D6"),
        ("storage.garage.shelving", "Garage Shelving Unit", 1.2, 1.8, 0.5, .box, "5E6468"),
        ("storage.workbench", "Workbench", 1.8, 0.9, 0.7, .box, "8A6A4A"),
        ("storage.cabinet.metal", "Metal Storage Cabinet", 0.9, 1.8, 0.5, .box, "8E9396"),
    ])

    // MARK: - More outdoor, pools, outdoor furniture

    static let moreOutdoor: [CatalogItem] = make(.outdoor, [
        ("out.pool.rect", "Rectangular Pool (4x8 m)", 4, 0.4, 8, .box, "4FA7C9"),
        ("out.pool.lap", "Lap Pool (3x12 m)", 3, 0.4, 12, .box, "4FA7C9"),
        ("out.pool.plunge", "Plunge Pool (2.4x3.6 m)", 2.4, 0.4, 3.6, .box, "4FA7C9"),
        ("out.pool.freeform", "Freeform Pool (5x9 m)", 5, 0.4, 9, .box, "4FA7C9"),
        ("out.spa.round", "Round Spa", 2.0, 0.9, 2.0, .cylinder, "3A4A52"),
        ("out.diningset.6", "Patio Dining Set (6)", 2.4, 0.9, 1.4, .box, "6B5847"),
        ("out.chaise.lounge", "Chaise Lounge", 0.7, 0.7, 1.9, .box, "E8E4DA"),
        ("out.sofa.sectional", "Outdoor Sectional", 2.7, 0.75, 1.7, .roundedBox, "8C9AA6"),
        ("out.umbrella.market", "Market Umbrella", 2.4, 2.4, 2.4, .cylinder, "D9CBB5"),
        ("out.trampoline", "Trampoline", 3.0, 0.9, 3.0, .cylinder, "2F3033"),
        ("out.deck.lowlevel", "Low Deck (4x5 m)", 4, 0.3, 5, .box, "7A5C44"),
        ("out.patio.concrete", "Concrete Patio (4x4 m)", 4, 0.1, 4, .box, "AEB0B1"),
    ])
}
