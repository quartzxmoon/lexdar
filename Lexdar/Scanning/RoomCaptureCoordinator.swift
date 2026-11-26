import Foundation
#if canImport(RoomPlan)
import RoomPlan

/// Drives a single RoomPlan capture session and exposes its state to
/// SwiftUI. One coordinator = one scan pass; start a new one for a new scan.
@MainActor
final class RoomCaptureCoordinator: NSObject, ObservableObject {
    let captureView: RoomCaptureView
    @Published var isScanning = false
    @Published var finalRoom: CapturedRoom?
    @Published var errorMessage: String?
    /// Live guidance surfaced to the user while scanning (move closer, pan
    /// slower, etc.) — mirrors RoomPlan's own on-screen instructions so the
    /// SwiftUI chrome can show a consistent banner alongside them.
    @Published var instruction: String?
    /// Latest in-progress room model from RoomPlan, throttled, for the live
    /// 3D preview shown while scanning.
    @Published var liveRoom: CapturedRoom?
    /// Every room finished so far in this scan, in order. Open-plan spaces
    /// (kitchen + dining, a hallway with side rooms) are scanned one room at a
    /// time on the same AR session and merged on save.
    @Published private(set) var completedRooms: [CapturedRoom] = []
    private var lastLiveUpdate = Date.distantPast
    /// True between asking the session to stop and RoomPlan handing back the
    /// processed room, so that room is recorded exactly once.
    private var awaitingRoom = false

    static var isSupported: Bool {
        RoomCaptureSession.isSupported
    }

    override init() {
        captureView = RoomCaptureView(frame: .zero)
        super.init()
        captureView.delegate = self
        captureView.captureSession.delegate = self
    }

    func start() {
        guard Self.isSupported else {
            errorMessage = "This device doesn't have the LiDAR scanner RoomPlan requires."
            return
        }
        let configuration = RoomCaptureSession.Configuration()
        captureView.captureSession.run(configuration: configuration)
        isScanning = true
        finalRoom = nil
        liveRoom = nil
        errorMessage = nil
        completedRooms = []
        awaitingRoom = false
    }

    /// Ends the current room but keeps the AR session running so the next
    /// room lands in the same coordinate space.
    func finishRoom() {
        awaitingRoom = true
        captureView.captureSession.stop(pauseARSession: false)
        isScanning = false
    }

    /// Starts another room on the same session, keeping the finished ones.
    func scanNextRoom() {
        let configuration = RoomCaptureSession.Configuration()
        captureView.captureSession.run(configuration: configuration)
        isScanning = true
        finalRoom = nil
        liveRoom = nil
        errorMessage = nil
    }

    /// One room for saving: the single room, or all finished rooms combined.
    func mergedRoom() async -> CapturedRoom? {
        guard completedRooms.count > 1 else { return completedRooms.first ?? finalRoom }
        do {
            let structure = try await StructureBuilder(options: []).capturedStructure(from: completedRooms)
            if let merged = Self.merge(structure.rooms) { return merged }
        } catch {
            errorMessage = "Room alignment failed (\(error.localizedDescription)); combining rooms as scanned."
        }
        // The AR session was continuous, so the rooms already share one space.
        return Self.merge(completedRooms) ?? finalRoom
    }

    /// Concatenates the surfaces and objects of several rooms through their
    /// JSON form (CapturedRoom has no public initializer). The key names are an
    /// assumption about RoomPlan's coding format; nil means it did not work.
    static func merge(_ rooms: [CapturedRoom]) -> CapturedRoom? {
        guard let first = rooms.first else { return nil }
        guard rooms.count > 1 else { return first }
        let encoder = JSONEncoder()
        func dictionary(_ room: CapturedRoom) -> [String: Any]? {
            guard let data = try? encoder.encode(room) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        guard var base = dictionary(first) else { return nil }
        let keys = ["walls", "doors", "windows", "openings", "objects", "floors"]
        for room in rooms.dropFirst() {
            guard let extra = dictionary(room) else { return nil }
            for key in keys {
                if let more = extra[key] as? [Any], let existing = base[key] as? [Any] {
                    base[key] = existing + more
                }
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: base),
              let merged = try? JSONDecoder().decode(CapturedRoom.self, from: data),
              merged.walls.count >= first.walls.count else { return nil }
        return merged
    }

    func acceptLiveUpdate(_ room: CapturedRoom) {
        guard Date().timeIntervalSince(lastLiveUpdate) > 0.6 else { return }
        lastLiveUpdate = Date()
        liveRoom = room
    }

    func stop() {
        awaitingRoom = true
        captureView.captureSession.stop()
        isScanning = false
    }

    // `RoomCaptureViewDelegate` inherits from `NSCoding` (see Apple's
    // documentation — unusual for a delegate protocol, but required).
    // This coordinator is never actually archived/unarchived; these exist
    // purely to satisfy that conformance.
    nonisolated init?(coder: NSCoder) {
        nil
    }

    nonisolated func encode(with coder: NSCoder) {}
}

extension RoomCaptureCoordinator: RoomCaptureViewDelegate {
    nonisolated func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: (any Error)?) -> Bool {
        error == nil
    }

    nonisolated func captureView(didPresent processedResult: CapturedRoom, error: (any Error)?) {
        Task { @MainActor in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            if self.awaitingRoom {
                self.completedRooms.append(processedResult)
                self.awaitingRoom = false
            } else if !self.completedRooms.isEmpty {
                self.completedRooms[self.completedRooms.count - 1] = processedResult
            }
            self.finalRoom = processedResult
        }
    }
}

extension RoomCaptureCoordinator: RoomCaptureSessionDelegate {
    nonisolated func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        Task { @MainActor in
            self.acceptLiveUpdate(room)
        }
    }

    nonisolated func captureSession(_ session: RoomCaptureSession, didProvideInstructions instruction: RoomCaptureSession.Instruction) {
        Task { @MainActor in
            self.instruction = Self.describe(instruction)
        }
    }

    nonisolated func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: (any Error)?) {
        guard let error else { return }
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }

    private static func describe(_ instruction: RoomCaptureSession.Instruction) -> String {
        switch instruction {
        case .moveCloseToWall: return "Move closer to the wall"
        case .moveAwayFromWall: return "Move away from the wall"
        case .slowDown: return "Slow down"
        case .turnOnLight: return "Turn on the light — it's too dark"
        case .normal: return "Keep scanning"
        case .lowTexture: return "Point at a more detailed surface"
        @unknown default: return "Keep scanning"
        }
    }
}
#endif
