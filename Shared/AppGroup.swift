import Foundation

/// Shared identifiers and the App Group container used to hand the active profile
/// from the main app to the packet-tunnel extension.
enum AppGroup {
    static let identifier = "group.space.gigapro.veil"
    static let tunnelBundleID = "space.gigapro.veil.tunnel"

    static var containerURL: URL {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            fatalError("App Group \(identifier) not configured — check entitlements on both targets.")
        }
        return url
    }

    static var activeProfileURL: URL {
        containerURL.appendingPathComponent("active-profile.json")
    }
}
