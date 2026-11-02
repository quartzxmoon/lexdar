import SwiftUI

#if canImport(RoomPlan)
import RoomPlan
#endif

/// App root: the list of saved scans, with a prominent "Scan a Room" action.
/// Gated on LiDAR hardware support so the button is clearly disabled (with
/// an explanation) on devices/simulators that can't scan.
struct ScanListView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var showCapture = false

    private var isLiDARSupported: Bool {
        #if canImport(RoomPlan)
        return RoomCaptureCoordinator.isSupported
        #else
        return false
        #endif
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.projects.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.projects) { project in
                            NavigationLink(value: project) {
                                ScanRow(project: project, planCount: store.plans(for: project.id).count)
                            }
                        }
                        .onDelete { indices in
                            for index in indices { store.delete(store.projects[index]) }
                        }
                    }
                }
            }
            .navigationTitle("My Scans")
            .navigationDestination(for: ScanProject.self) { project in
                ScanDetailView(project: project)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCapture = true
                    } label: {
                        Label("Scan a Room", systemImage: "camera.viewfinder")
                    }
                    .disabled(!isLiDARSupported)
                }
            }
            .fullScreenCover(isPresented: $showCapture) {
                ScanCaptureView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "house.and.flag")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No scans yet")
                .font(.title3.weight(.semibold))
            Text(isLiDARSupported
                 ? "Walk through a room with your iPad to capture a 3D model, floor plan, and dimensions."
                 : "This device doesn't have a LiDAR scanner, so room scanning isn't available here. You can still inspect scans created on a supported device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if isLiDARSupported {
                Button {
                    showCapture = true
                } label: {
                    Label("Scan a Room", systemImage: "camera.viewfinder")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct ScanRow: View {
    let project: ScanProject
    let planCount: Int

    var body: some View {
        HStack {
            Image(systemName: "house.fill")
                .font(.title2)
                .foregroundStyle(.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name).font(.headline)
                HStack(spacing: 6) {
                    Text(project.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let area = project.floorAreaSquareMeters {
                        Text("· \(Int(area * 10.7639)) sq ft")
                    }
                    if planCount > 0 {
                        Text("· \(planCount) plan\(planCount == 1 ? "" : "s")")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
