import Foundation
#if canImport(RoomPlan)
import RoomPlan
#endif

/// Owns all on-disk persistence for scans, their renovation plans, and
/// floor plans (LiDAR-generated or hand-drawn).
///
/// Layout on disk:
///   Documents/Scans/<scanID>/metadata.json
///   Documents/Scans/<scanID>/room.json        (CapturedRoom, JSON)
///   Documents/Scans/<scanID>/model.usdz        (exported 3D model)
///   Documents/Scans/<scanID>/Plans/<planID>.json
///   Documents/FloorPlans/<floorPlanID>.json     (FloorPlan, JSON --
///     top-level, not nested under a scan, since a hand-drawn FloorPlan
///     need not come from any scan at all)
@MainActor
final class ScanStore: ObservableObject {
    @Published private(set) var projects: [ScanProject] = []
    @Published private(set) var plans: [UUID: [RenovationPlan]] = [:] // keyed by scanID
    @Published private(set) var floorPlans: [FloorPlan] = []

    private let fileManager = FileManager.default

    private var rootDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = docs.appendingPathComponent("Scans", isDirectory: true)
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private var floorPlansDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = docs.appendingPathComponent("FloorPlans", isDirectory: true)
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    init() { reload() }

    // MARK: - Paths

    func folderURL(for project: ScanProject) -> URL {
        rootDirectory.appendingPathComponent(project.folderName, isDirectory: true)
    }

    func modelURL(for project: ScanProject) -> URL {
        folderURL(for: project).appendingPathComponent("model.usdz")
    }

    private func roomJSONURL(for project: ScanProject) -> URL {
        folderURL(for: project).appendingPathComponent("room.json")
    }

    private func metadataURL(for project: ScanProject) -> URL {
        folderURL(for: project).appendingPathComponent("metadata.json")
    }

    private func plansFolderURL(for scanID: UUID) -> URL {
        rootDirectory.appendingPathComponent(scanID.uuidString, isDirectory: true)
            .appendingPathComponent("Plans", isDirectory: true)
    }

    private func planURL(scanID: UUID, planID: UUID) -> URL {
        plansFolderURL(for: scanID).appendingPathComponent("\(planID.uuidString).json")
    }

    // MARK: - Loading

    func reload() {
        let folders = (try? fileManager.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: nil)) ?? []
        var loaded: [ScanProject] = []
        var loadedPlans: [UUID: [RenovationPlan]] = [:]

        for folder in folders {
            let metaURL = folder.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metaURL),
                  let project = try? JSONDecoder().decode(ScanProject.self, from: data) else { continue }
            loaded.append(project)

            let plansFolder = folder.appendingPathComponent("Plans", isDirectory: true)
            let planFiles = (try? fileManager.contentsOfDirectory(at: plansFolder, includingPropertiesForKeys: nil)) ?? []
            var plansForScan: [RenovationPlan] = []
            for file in planFiles where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let plan = try? JSONDecoder().decode(RenovationPlan.self, from: data) {
                    plansForScan.append(plan)
                }
            }
            loadedPlans[project.id] = plansForScan.sorted { $0.updatedAt > $1.updatedAt }
        }

        projects = loaded.sorted { $0.createdAt > $1.createdAt }
        plans = loadedPlans

        let floorPlanFiles = (try? fileManager.contentsOfDirectory(at: floorPlansDirectory, includingPropertiesForKeys: nil)) ?? []
        var loadedFloorPlans: [FloorPlan] = []
        for file in floorPlanFiles where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let plan = try? JSONDecoder().decode(FloorPlan.self, from: data) {
                loadedFloorPlans.append(plan)
            }
        }
        floorPlans = loadedFloorPlans.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Scans

    #if canImport(RoomPlan)
    /// Persists a freshly-processed `CapturedRoom`: exports a combined
    /// parametric+mesh USDZ, writes the raw room JSON for later re-export
    /// and floor-plan regeneration, and records the metadata entry.
    func saveNewScan(name: String, room: CapturedRoom) async throws -> ScanProject {
        let area = room.floors.reduce(0.0) { partial, floor in
            partial + Double(floor.dimensions.x * floor.dimensions.z)
        }
        let project = ScanProject(name: name, floorAreaSquareMeters: area > 0 ? area : nil)
        let folder = folderURL(for: project)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: plansFolderURL(for: project.id), withIntermediateDirectories: true)

        let roomData = try JSONEncoder().encode(room)
        try roomData.write(to: roomJSONURL(for: project))

        try room.export(to: modelURL(for: project), exportOptions: .parametric)

        let metadata = try JSONEncoder().encode(project)
        try metadata.write(to: metadataURL(for: project))

        reload()
        return project
    }

    func loadRoom(for project: ScanProject) -> CapturedRoom? {
        guard let data = try? Data(contentsOf: roomJSONURL(for: project)) else { return nil }
        return try? JSONDecoder().decode(CapturedRoom.self, from: data)
    }

    /// Re-exports the USDZ for a scan — used after merging multiple scan
    /// passes, or if the export options change.
    func reexportModel(for project: ScanProject) throws {
        guard let room = loadRoom(for: project) else { return }
        try room.export(to: modelURL(for: project), exportOptions: .parametric)
    }
    #endif

    func delete(_ project: ScanProject) {
        try? fileManager.removeItem(at: folderURL(for: project))
        reload()
    }

    func rename(_ project: ScanProject, to newName: String) {
        guard var updated = projects.first(where: { $0.id == project.id }) else { return }
        updated.name = newName
        guard let data = try? JSONEncoder().encode(updated) else { return }
        try? data.write(to: metadataURL(for: updated))
        reload()
    }

    // MARK: - Renovation plans

    func plans(for scanID: UUID) -> [RenovationPlan] {
        plans[scanID] ?? []
    }

    func createPlan(scanID: UUID, name: String) -> RenovationPlan {
        let plan = RenovationPlan(scanID: scanID, name: name)
        save(plan)
        return plan
    }

    func save(_ plan: RenovationPlan) {
        let folder = plansFolderURL(for: plan.scanID)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(plan) else { return }
        try? data.write(to: planURL(scanID: plan.scanID, planID: plan.id))
        reload()
    }

    func deletePlan(_ plan: RenovationPlan) {
        try? fileManager.removeItem(at: planURL(scanID: plan.scanID, planID: plan.id))
        reload()
    }

    // MARK: - Floor plans (LiDAR-generated or hand-drawn)

    private func floorPlanURL(_ floorPlan: FloorPlan) -> URL {
        floorPlansDirectory.appendingPathComponent("\(floorPlan.id.uuidString).json")
    }

    func floorPlans(for scanID: UUID) -> [FloorPlan] {
        floorPlans.filter { $0.scanID == scanID }
    }

    /// Hand-drawn floor plans with no originating scan -- documenting a
    /// space that was never LiDAR-scanned, or a renovation concept sketched
    /// before ever scanning the real room.
    var handDrawnFloorPlans: [FloorPlan] {
        floorPlans.filter { $0.scanID == nil }
    }

    func createHandDrawnFloorPlan(name: String) -> FloorPlan {
        let plan = FloorPlan(name: name, source: .handDrawn)
        save(plan)
        return plan
    }

    #if canImport(RoomPlan)
    /// Generates a new `FloorPlan` from a scan's `CapturedRoom`. Creates a
    /// fresh plan every call (rather than overwriting) so re-generating
    /// after a re-scan doesn't silently discard hand-corrections made to a
    /// previous generation -- the user deletes the old one explicitly if
    /// they want it gone.
    func generateFloorPlan(from project: ScanProject) -> FloorPlan? {
        guard let room = loadRoom(for: project) else { return nil }
        let plan = RoomPlanImporter.makeFloorPlan(from: room, scanID: project.id, name: project.name)
        save(plan)
        return plan
    }
    #endif

    func save(_ floorPlan: FloorPlan) {
        var toSave = floorPlan
        toSave.touch()
        guard let data = try? JSONEncoder().encode(toSave) else { return }
        try? data.write(to: floorPlanURL(toSave))
        reload()
    }

    func deleteFloorPlan(_ floorPlan: FloorPlan) {
        try? fileManager.removeItem(at: floorPlanURL(floorPlan))
        reload()
    }
}
