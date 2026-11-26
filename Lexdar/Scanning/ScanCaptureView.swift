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
    /// Remembered between scans. Off keeps the saved scan to walls, doors,
    /// windows and openings; on also keeps cabinets, tables, sofas, beds,
    /// toilets and the other fixtures RoomPlan recognizes.
    @AppStorage("scanIncludeObjects") private var includeObjects = true

    var body: some View {
        ZStack(alignment: .bottom) {
            RoomCaptureRepresentable(coordinator: coordinator)
                .ignoresSafeArea()

            Toggle(isOn: $includeObjects) {
                Label("Furniture & fixtures", systemImage: "sofa")
                    .font(.footnote.weight(.medium))
            }
            .fixedSize()
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()

            if coordinator.isScanning, coordinator.liveRoom != nil {
                LiveRoomPreview(room: coordinator.liveRoom, showObjects: includeObjects)
                    .frame(width: 280, height: 210)
                    .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding()
            }

            VStack(spacing: 10) {
                if let instruction = coordinator.instruction, coordinator.isScanning {
                    Text(instruction)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                if !coordinator.isScanning, !coordinator.completedRooms.isEmpty {
                    Text("\(coordinator.completedRooms.count) room(s) captured. Open space or an arch you could not finish? Walk into the next room and tap Scan Next Room. Stay in the app so the rooms line up, then Save.")
                        .font(.footnote)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
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
                coordinator.finishRoom()
            } label: {
                Label(coordinator.completedRooms.isEmpty ? "Finish Room" : "Finish Room \(coordinator.completedRooms.count + 1)",
                      systemImage: "checkmark.circle.fill").font(.headline)
            }
            .buttonStyle(.borderedProminent)
        } else if coordinator.finalRoom != nil {
            HStack(spacing: 12) {
                Button {
                    coordinator.scanNextRoom()
                } label: {
                    Label("Scan Next Room", systemImage: "plus.viewfinder").font(.headline)
                }
                .buttonStyle(.bordered)
                .disabled(isSaving)

                Button {
                    showNamePrompt = true
                } label: {
                    Label(isSaving ? "Saving…" : "Save \(coordinator.completedRooms.count > 1 ? "\(coordinator.completedRooms.count) Rooms" : "Scan")",
                          systemImage: "square.and.arrow.down").font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
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
        guard coordinator.finalRoom != nil else { return }
        isSaving = true
        Task {
            do {
                guard let room = await coordinator.mergedRoom() else {
                    isSaving = false
                    coordinator.errorMessage = "Nothing to save yet."
                    return
                }
                _ = try await store.saveNewScan(name: projectName, room: room, includeObjects: includeObjects)
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
