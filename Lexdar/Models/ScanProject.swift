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

    var folderName: String { id.uuidString }

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), floorAreaSquareMeters: Double? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.floorAreaSquareMeters = floorAreaSquareMeters
    }
}
