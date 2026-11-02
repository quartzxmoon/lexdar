import SwiftUI

@main
struct LexdarApp: App {
    @StateObject private var store = ScanStore()

    var body: some Scene {
        WindowGroup {
            ScanListView()
                .environmentObject(store)
        }
    }
}
