import NetworkExtension
import os.log

/// The packet-tunnel extension. Runs in a SEPARATE, memory-constrained (~50 MiB) process.
/// Flow: receive Profile via providerConfiguration → configure the TUN → build a sing-box
/// config → hand it to the embedded engine.
final class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: AppGroup.tunnelBundleID, category: "tunnel")
    private let engine = LibboxEngine()

    override func startTunnel(options: [String: NSObject]?,
                             completionHandler: @escaping (Error?) -> Void) {
        os_log("startTunnel", log: log, type: .info)

        guard let profile = decodeProfile() else {
            completionHandler(VeilTunnelError.missingProfile)
            return
        }

        // The engine's platform interface configures the TUN itself (it calls
        // setTunnelNetworkSettings during openTun), so we do NOT set it here — we just hand
        // the engine the sing-box config (built from the profile) and ourselves as provider.
        guard let configContent = String(data: SingBoxConfig.json(for: profile), encoding: .utf8) else {
            completionHandler(VeilTunnelError.missingProfile)
            return
        }
        do {
            try engine.start(configContent: configContent, provider: self)
            completionHandler(nil)
        } catch {
            os_log("engine start failed: %{public}@", log: log, type: .error, error.localizedDescription)
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                            completionHandler: @escaping () -> Void) {
        os_log("stopTunnel reason=%{public}d", log: log, type: .info, reason.rawValue)
        engine.stop()
        completionHandler()
    }

    override func wake() { engine.wake() }

    override func sleep(completionHandler: @escaping () -> Void) {
        engine.sleep()
        completionHandler()
    }

    // MARK: - Helpers

    private func decodeProfile() -> Profile? {
        guard
            let proto = protocolConfiguration as? NETunnelProviderProtocol,
            let data = proto.providerConfiguration?["profile"] as? Data
        else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: data)
    }
}

enum VeilTunnelError: LocalizedError {
    case missingProfile
    case engineUnavailable

    var errorDescription: String? {
        switch self {
        case .missingProfile:   return "No proxy profile was provided to the tunnel."
        case .engineUnavailable: return "Proxy engine not yet integrated. Build Libbox.xcframework (scripts/build-libbox.sh) and wire LibboxEngine."
        }
    }
}
