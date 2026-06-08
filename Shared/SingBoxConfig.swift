import Foundation

/// Builds a sing-box configuration JSON from a Profile. This is the config the embedded
/// libbox engine consumes inside the tunnel extension. Schema target: sing-box 1.8+.
///
/// Phase 1 is intentionally a minimal "route everything through the proxy" config. Phase 2
/// replaces `route` with geosite/geoip rule-sets and per-app rules, and supports importing
/// full sing-box / Clash configs directly (bypassing this builder).
enum SingBoxConfig {
    static func json(for profile: Profile, dnsServer: String = "192.168.1.3") -> Data {
        let config: [String: Any] = [
            "log": ["level": "warn", "timestamp": false],   // keep low — logs cost NE memory
            "dns": [
                "servers": [
                    ["tag": "dns-remote", "address": dnsServer]   // AdGuard Home
                ],
                "final": "dns-remote",
                "strategy": "prefer_ipv4"
            ],
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "utun-veil",
                "inet4_address": "172.19.0.1/30",
                "auto_route": true,
                "stack": "gvisor",
                "mtu": 1500,
                "sniff": true
            ]],
            "outbounds": [
                outboundDict(for: profile),
                ["type": "direct", "tag": "direct"],
                ["type": "block", "tag": "block"]
            ],
            "route": [
                "final": "proxy",
                "auto_detect_interface": true
            ]
        ]
        return (try? JSONSerialization.data(
            withJSONObject: config, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    private static func outboundDict(for p: Profile) -> [String: Any] {
        switch p.type {
        case .http:
            var d: [String: Any] = ["type": "http", "tag": "proxy",
                                    "server": p.host, "server_port": p.port]
            if let u = p.username, let pw = p.password { d["username"] = u; d["password"] = pw }
            return d
        case .socks:
            var d: [String: Any] = ["type": "socks", "tag": "proxy",
                                    "server": p.host, "server_port": p.port, "version": "5"]
            if let u = p.username, let pw = p.password { d["username"] = u; d["password"] = pw }
            return d
        case .shadowsocks:
            return ["type": "shadowsocks", "tag": "proxy",
                    "server": p.host, "server_port": p.port,
                    "method": p.method ?? "aes-256-gcm", "password": p.password ?? ""]
        }
    }
}
