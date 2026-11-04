import Foundation
import simd

/// A single catalog item the user has dropped into the 3D renovation scene:
/// a sofa moved into the new open-concept great room, a vanity placed in the
/// remodeled bath, a pendant light over the island, etc.
struct PlacedItem: Identifiable, Codable, Hashable {
    let id: UUID
    let catalogItemID: String
    /// World-space position in meters, same coordinate space as the
    /// CapturedRoom (RoomPlan's ARKit world space: +Y up).
    var position: SIMD3<Float>
    /// Rotation about the world Y (vertical) axis, in radians.
    var rotationY: Float
    /// Uniform scale applied on top of the catalog item's base dimensions,
    /// so a "Dining Table (6-seat)" can be stretched to fit a bigger room.
    var scale: Float

    init(id: UUID = UUID(), catalogItemID: String, position: SIMD3<Float>,
         rotationY: Float = 0, scale: Float = 1) {
        self.id = id
        self.catalogItemID = catalogItemID
        self.position = position
        self.rotationY = rotationY
        self.scale = scale
    }

    var catalogItem: CatalogItem? { Catalog.item(id: catalogItemID) }
}

/// A material override applied to one captured surface (a wall, or the
/// floor) by `identifier` — RoomPlan's `CapturedRoom.Surface.identifier`
/// stays stable across the life of a single capture, which is what lets us
/// remember "this wall is now Sage Green" or "this floor is now Walnut".
struct SurfaceMaterialOverride: Codable, Hashable {
    let surfaceID: UUID
    var catalogItemID: String
}

/// A renovation "what if" built on top of one scan. Multiple plans can exist
/// for the same scan (e.g. "Open-concept kitchen", "Primary bath remodel —
/// option A", "Primary bath remodel — option B") so different ideas can be
/// compared without losing any of them.
///
/// `removedWallIDs` is the core "knock down a wall" feature: surfaces whose
/// identifier is in this set are hidden from the 3D/2D render and excluded
/// from the floor-plan wall list, so the user can see what an open floor
/// plan would look like before committing to the real renovation.
struct RenovationPlan: Identifiable, Codable, Hashable {
    let id: UUID
    let scanID: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    /// `CapturedRoom.Surface.identifier` values for walls the user has
    /// marked as "removed" in this plan (does not touch the original scan).
    var removedWallIDs: Set<UUID>
    /// Captured objects (RoomPlan-detected furniture) the user has hidden
    /// from this plan's render, e.g. because it'll be hauled away.
    var hiddenObjectIDs: Set<UUID>
    /// Floor and wall finish swaps, keyed by surface identifier.
    var surfaceMaterials: [SurfaceMaterialOverride]
    /// New furniture/fixtures/appliances/outdoor items placed into the scene.
    var placedItems: [PlacedItem]
    /// Free-form per-room labels, e.g. "Primary Bath", "Kitchen" — keyed by
    /// the identifier of that room's floor surface.
    var roomLabels: [UUID: String]
    var notes: String

    init(id: UUID = UUID(), scanID: UUID, name: String) {
        self.id = id
        self.scanID = scanID
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.removedWallIDs = []
        self.hiddenObjectIDs = []
        self.surfaceMaterials = []
        self.placedItems = []
        self.roomLabels = [:]
        self.notes = ""
    }

    mutating func toggleWallRemoved(_ id: UUID) {
        if removedWallIDs.contains(id) {
            removedWallIDs.remove(id)
        } else {
            removedWallIDs.insert(id)
        }
        updatedAt = Date()
    }

    mutating func setMaterial(surfaceID: UUID, catalogItemID: String) {
        if let idx = surfaceMaterials.firstIndex(where: { $0.surfaceID == surfaceID }) {
            surfaceMaterials[idx].catalogItemID = catalogItemID
        } else {
            surfaceMaterials.append(SurfaceMaterialOverride(surfaceID: surfaceID, catalogItemID: catalogItemID))
        }
        updatedAt = Date()
    }

    func material(for surfaceID: UUID) -> CatalogItem? {
        guard let override = surfaceMaterials.first(where: { $0.surfaceID == surfaceID }) else { return nil }
        return Catalog.item(id: override.catalogItemID)
    }

    mutating func addItem(_ catalogItemID: String, at position: SIMD3<Float>) -> PlacedItem {
        let item = PlacedItem(catalogItemID: catalogItemID, position: position)
        placedItems.append(item)
        updatedAt = Date()
        return item
    }

    mutating func removeItem(_ id: UUID) {
        placedItems.removeAll { $0.id == id }
        updatedAt = Date()
    }

    mutating func updateItem(_ id: UUID, _ transform: (inout PlacedItem) -> Void) {
        guard let idx = placedItems.firstIndex(where: { $0.id == id }) else { return }
        transform(&placedItems[idx])
        updatedAt = Date()
    }
}
