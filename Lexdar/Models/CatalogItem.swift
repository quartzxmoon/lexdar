import SwiftUI

/// Top-level category for everything in the build-out catalog. Mirrors the
/// grouping MagicPlan/Polycam-style renovation tools use: structural finishes
/// first, then room-by-room fixtures, then furniture and outdoor items.
enum CatalogCategory: String, CaseIterable, Identifiable, Codable {
    case flooring
    case wallFinish
    case kitchenFixture
    case bathroomFixture
    case appliance
    case furniture
    case lighting
    case outdoor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flooring: return "Flooring"
        case .wallFinish: return "Wall Finishes"
        case .kitchenFixture: return "Kitchen Fixtures"
        case .bathroomFixture: return "Bathroom Fixtures"
        case .appliance: return "Appliances"
        case .furniture: return "Furniture"
        case .lighting: return "Lighting"
        case .outdoor: return "Outdoor"
        }
    }

    var symbolName: String {
        switch self {
        case .flooring: return "square.grid.3x3.fill"
        case .wallFinish: return "paintbrush.fill"
        case .kitchenFixture: return "sink.fill"
        case .bathroomFixture: return "shower.fill"
        case .appliance: return "refrigerator.fill"
        case .furniture: return "sofa.fill"
        case .lighting: return "lightbulb.fill"
        case .outdoor: return "leaf.fill"
        }
    }

    /// Flooring and wall finishes are "surface materials" — applied to an
    /// existing floor/wall rather than placed as a free-standing object.
    var isSurfaceMaterial: Bool {
        self == .flooring || self == .wallFinish
    }
}

/// A primitive 3D shape used to represent a catalog item in the SceneKit
/// renovation editor when no real USDZ/Reality asset is bundled. Keeps the
/// scaffold fully functional without requiring external asset downloads —
/// swap `assetName` in to load a bundled/USDZ model instead when available.
enum CatalogPrimitive: String, Codable {
    case box
    case cylinder
    case roundedBox
    case plane
    case sphere
}

/// One entry in the renovation build-out catalog: a piece of flooring,
/// a wall paint/finish, a fixture, an appliance, a furniture piece, a light,
/// or an outdoor item. `assetName` is optional — when set, the renovation
/// scene loads `Resources/Models/<assetName>.usdz` instead of drawing the
/// primitive placeholder.
struct CatalogItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: CatalogCategory
    /// Real-world footprint in meters (width, height, depth) used both for
    /// the placeholder geometry and for snapping/scaling against the room.
    let dimensions: SIMD3<Float>
    let primitive: CatalogPrimitive
    let colorHex: String
    var assetName: String?
    /// Short note shown in the catalog browser and in the renovation
    /// summary export (e.g. "36in base cabinet run").
    var note: String?

    var color: Color { Color(hex: colorHex) }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, dimensions, primitive, colorHex, assetName, note
    }

    init(id: String, name: String, category: CatalogCategory, dimensions: SIMD3<Float>,
         primitive: CatalogPrimitive, colorHex: String, assetName: String? = nil, note: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.dimensions = dimensions
        self.primitive = primitive
        self.colorHex = colorHex
        self.assetName = assetName
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(CatalogCategory.self, forKey: .category)
        let dims = try c.decode([Float].self, forKey: .dimensions)
        dimensions = SIMD3<Float>(dims[0], dims[1], dims[2])
        primitive = try c.decode(CatalogPrimitive.self, forKey: .primitive)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        assetName = try c.decodeIfPresent(String.self, forKey: .assetName)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(category, forKey: .category)
        try c.encode([dimensions.x, dimensions.y, dimensions.z], forKey: .dimensions)
        try c.encode(primitive, forKey: .primitive)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encodeIfPresent(assetName, forKey: .assetName)
        try c.encodeIfPresent(note, forKey: .note)
    }
}

extension Color {
    /// Convenience initializer for catalog swatches stored as "#RRGGBB".
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if s.count != 6 { s = "888888" }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
