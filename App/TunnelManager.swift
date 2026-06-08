import Foundation
import NetworkExtension
import Combine

/// App-side wrapper around NETunnelProviderManager: installs the VPN profile that points at
/// our packet-tunnel extension, carries the active Profile to it, and starts/stops the tunnel.
@MainActor
final class TunnelManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    init() { Task { await reload() } }

    func reload() async {
        do {
            let all = try await NETunnelProviderManager.loadAllFromPreferences()
            let mgr = all.first ?? NETunnelProviderManager()
            manager = mgr
            observe(mgr)
            status = mgr.connection.status
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Persist a VPN configuration that runs our extension and carries `profile`.
    func install(profile: Profile) async {
        let mgr = manager ?? NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppGroup.tunnelBundleID
        proto.serverAddress = "\(profile.host):\(profile.port)"   // shown in iOS Settings > VPN
        if let data = try? JSONEncoder().encode(profile) {
            proto.providerConfiguration = ["profile": data]
        }
        mgr.protocolConfiguration = proto
        mgr.localizedDescription = "Veil"
        mgr.isEnabled = true
        do {
            try await mgr.saveToPreferences()
            try await mgr.loadFromPreferences()   // reload so connection is valid
            manager = mgr
            observe(mgr)
        } catch {
            lastError = "save failed: \(error.localizedDescription)"
        }
    }

    func start(profile: Profile) async {
        await install(profile: profile)
        do {
            try manager?.connection.startVPNTunnel()
        } catch {
            lastError = "start failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
    }

    private func observe(_ mgr: NETunnelProviderManager) {
        if let o = statusObserver { NotificationCenter.default.removeObserver(o) }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: mgr.connection, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.status = mgr.connection.status }
        }
    }
}
