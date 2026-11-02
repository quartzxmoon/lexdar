import SwiftUI

#if canImport(RoomPlan)
import RoomPlan

/// Full-screen LiDAR capture flow: start scanning, walk the room/house,
/// tap "Finish Scan" when done, name it, save. Mirrors the standard
/// RoomPlan capture pattern (live AR view + start/stop + processed result).
struct ScanCaptureView: View {
    @StateObject private var coordinator = RoomCaptureCoordinator()
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = Self.defaultName()
    @State private var isSaving = false
    @State private var showNamePrompt = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RoomCaptureRepresentable(coordinator: coordinator)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                if let instruction = coordinator.instruction, coordinator.isScanning {
                    Text(instruction)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                if let error = coordinator.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                }

                HStack {
                    Button(role: .cancel) {
                        coordinator.stop()
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    primaryButton
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .onAppear { coordinator.start() }
        .alert("Name this scan", isPresented: $showNamePrompt) {
            TextField("Scan name", text: $projectName)
            Button("Save") { save() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can create multiple renovation plans from this scan afterward.")
        }
        .navigationBarBackButtonHidden(true)
        .disabled(isSaving)
    }

    @ViewBuilder
    private var primaryButton: some View {
        if coordinator.isScanning {
            Button {
                coordinator.stop()
            } label: {
                Label("Finish Scan", systemImage: "checkmark.circle.fill").font(.headline)
            }
            .buttonStyle(.borderedProminent)
        } else if coordinator.finalRoom != nil {
            Button {
                showNamePrompt = true
            } label: {
                Label(isSaving ? "Saving…" : "Save Scan", systemImage: "square.and.arrow.down").font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
        } else {
            Button {
                coordinator.start()
            } label: {
                Label("Start Scanning", systemImage: "camera.viewfinder").font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func save() {
        guard let room = coordinator.finalRoom else { return }
        isSaving = true
        Task {
            do {
                _ = try await store.saveNewScan(name: projectName, room: room)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                coordinator.errorMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    private static func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Scan \(formatter.string(from: Date()))"
    }
}

#else

/// Fallback shown when building for a target without RoomPlan (e.g. a
/// Simulator-only or non-LiDAR build configuration), so the rest of the app
/// still compiles and runs for browsing/editing previously-saved scans.
struct ScanCaptureView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("LiDAR scanning requires a physical device with a LiDAR scanner (iPhone 12 Pro or later Pro models, iPad Pro 2020 or later), running iOS/iPadOS 16+, built with Xcode 14+.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
#endif
