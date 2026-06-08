import SwiftUI

@main
struct VeilApp: App {
    @StateObject private var store = ProfileStore()
    @StateObject private var tunnel = TunnelManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(tunnel)
        }
    }
}
