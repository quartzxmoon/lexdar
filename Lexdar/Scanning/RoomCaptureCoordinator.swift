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
        errorMessage = nil
    }

    func stop() {
        captureView.captureSession.stop()
        isScanning = false
    }

    // `RoomCaptureViewDelegate` inherits from `NSCoding` (see Apple's
    // documentation — unusual for a delegate protocol, but required).
    // This coordinator is never actually archived/unarchived; these exist
    // purely to satisfy that conformance.
    init?(coder: NSCoder) {
        nil
    }

    func encode(with coder: NSCoder) {}
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
            self.finalRoom = processedResult
        }
    }
}

extension RoomCaptureCoordinator: RoomCaptureSessionDelegate {
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
