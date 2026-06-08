import Foundation

/// A proxy endpoint the tunnel routes traffic through.
/// MVP (Phase 1) supports an HTTP/SOCKS proxy — i.e. your gluetun proxy at :8889 reached
/// over Tailscale — plus Shadowsocks. Phase 2 adds VMess/Trojan/Hysteria2/WireGuard via
/// sing-box config import.
struct Profile: Codable, Identifiable, Equatable {
    enum ProxyType: String, Codable, CaseIterable, Identifiable {
        case http, socks, shadowsocks
        var id: String { rawValue }
        var label: String {
            switch self {
            case .http: return "HTTP proxy"
            case .socks: return "SOCKS5"
            case .shadowsocks: return "Shadowsocks"
            }
        }
    }

    var id: UUID
    var name: String
    var type: ProxyType
    var host: String
    var port: Int
    var username: String?
    var password: String?
    var method: String?   // Shadowsocks cipher, e.g. "aes-256-gcm"

    init(id: UUID = UUID(), name: String, type: ProxyType, host: String, port: Int,
         username: String? = nil, password: String? = nil, method: String? = nil) {
        self.id = id; self.name = name; self.type = type; self.host = host; self.port = port
        self.username = username; self.password = password; self.method = method
    }

    /// Default tuned to this homelab: gluetun HTTP proxy (→ Riseup), reached over Tailscale.
    /// Replace the host with your HOMENET Tailscale IP (100.x.y.z) on first launch.
    static let homelabDefault = Profile(
        name: "Home (gluetun → Riseup)",
        type: .http,
        host: "100.100.100.100",
        port: 8889
    )
}
