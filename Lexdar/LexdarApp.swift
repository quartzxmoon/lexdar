import SwiftUI

@main
struct LexdarApp: App {
    @StateObject private var store = ScanStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                ScanListView()
                    .tabItem { Label("Scans", systemImage: "camera.viewfinder") }
                FloorPlanListView()
                    .tabItem { Label("Floor Plans", systemImage: "pencil.and.ruler") }
            }
            .environmentObject(store)
        }
    }
}
