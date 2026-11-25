import Foundation

/// A single LiDAR room/house scan, persisted on disk under
/// Documents/Scans/<id>/ as:
///   - metadata.json   (this struct)
///   - room.json       (the processed RoomPlan `CapturedRoom`, JSON-encoded)
///   - model.usdz       (exported 3D model, parametric + mesh)
/// Renovation ideas built from this scan live as separate `RenovationPlan`
/// files in the same folder, so one scan can have many "what if" plans
/// (e.g. "Open concept kitchen", "Guest bath remodel").
struct ScanProject: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    /// Rough total floor area in square meters, filled in after processing
    /// (sum of CapturedRoom.floors area). Nil until a scan has been saved.
    var floorAreaSquareMeters: Double?
    /// Whether the furniture and fixtures RoomPlan detected (cabinets,
    /// tables, sofas, beds, toilets, ...) are shown and exported. Optional so
    /// scans saved before this existed still decode; nil means included.
    var includeObjects: Bool?

    var folderName: String { id.uuidString }

    var showsDetectedObjects: Bool { includeObjects ?? true }

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), floorAreaSquareMeters: Double? = nil,
         includeObjects: Bool? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.floorAreaSquareMeters = floorAreaSquareMeters
        self.includeObjects = includeObjects
    }
}
