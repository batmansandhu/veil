# Veil — iOS proxy client (Shadowrocket-class)

Route Safari / per-app iOS traffic through a proxy you configure — built for self-hosters.
Default target: your homelab gluetun proxy (`:8889` → Riseup exit) reached over Tailscale,
with DNS pinned to AdGuard Home (`192.168.1.3`).

> **Status: Phase 1 scaffold.** The app, UI, profile persistence, and the full Network
> Extension wiring are in place and build on a Mac. The proxy *engine* is a documented stub
> (`PacketTunnel/LibboxEngine.swift`) — tapping **Connect** installs the VPN profile and
> fails with a clear "engine not wired" message until you build and integrate the engine.
> This is intentional: a working app to iterate on before the hard part.

## Why it's structured this way

iOS has exactly one sanctioned mechanism for a proxy app: a **`NEPacketTunnelProvider`**
Network Extension that captures IP packets and forwards them through an embedded userspace
proxy engine. The extension runs in a separate process with a **~50 MiB memory ceiling** —
the dominant engineering constraint. See `plans/proxy-app/docs/plan-v1.html` for the full
plan, self-review, and monetization analysis.

## Layout

```
project.yml                 XcodeGen spec (source of truth — generates Veil.xcodeproj)
Config/Veil.xcconfig        TEAM id + App Group id
App/                        SwiftUI main app
  VeilApp.swift             entry point
  TunnelManager.swift       NETunnelProviderManager wrapper (install/start/stop/status)
  Views/ContentView.swift   connect toggle + editable home-proxy profile
  Veil.entitlements         networkextension + app group
Shared/                     compiled into BOTH targets
  AppGroup.swift            shared container + bundle ids
  Profile.swift             proxy endpoint model (http/socks/shadowsocks)
  ProfileStore.swift        persists active profile to the App Group
  SingBoxConfig.swift       builds sing-box JSON from a Profile
PacketTunnel/               the Network Extension (≤50 MiB process)
  PacketTunnelProvider.swift  TUN setup + hands config to the engine
  LibboxEngine.swift        ENGINE SEAM (stub → wire sing-box or leaf here)
  PacketTunnel.entitlements
scripts/
  bootstrap.sh             installs xcodegen, generates the project
  build-libbox.sh          builds Libbox.xcframework from sing-box via gomobile
```

## Build (on a Mac)

```bash
./scripts/bootstrap.sh        # installs XcodeGen, runs `xcodegen generate`
open Veil.xcodeproj
# set DEVELOPMENT_TEAM on both targets, then build to a REAL DEVICE
```

Edit the **Host** field to your HOMENET Tailscale IP (`100.x.y.z`) on first launch.

## Integrate the engine (next step)

```bash
./scripts/build-libbox.sh     # → Frameworks/Libbox.xcframework (GPLv3 sing-box)
# uncomment the framework dependency in project.yml, then:
xcodegen generate
# wire PacketTunnel/LibboxEngine.swift per the comments (mirror sing-box-for-apple)
```

Then run the **`ne-memory-audit`** Claude Code skill to keep the extension under budget.

## Engine bake-off (Phase 1 decision)

| | sing-box (default) | leaf |
|---|---|---|
| Language | Go | Rust |
| License | **GPLv3** → client must be open source | **Apache-2.0** → closed-source OK |
| Protocols | All (SS/VMess/Trojan/Hysteria2/WG/TUIC…) | SS/VMess/Trojan/WG/SOCKS |
| Memory baseline | Higher (Go runtime/GC) — risk vs 50 MiB | Lower |
| Business model implied | open client + paid **service** | closed client, sell the app |

Test both on the oldest device you support **before** committing — the engine choice also
decides your open-vs-closed-source business model.

## License & distribution notes

- Embedding sing-box makes the client **GPLv3**; monetize the hosted service / Pro features,
  not the client source (the Outline/Mullvad model).
- App Store distribution of any VPN app requires an **organization** developer account
  (Apple Guideline 5.4) → LLC + D-U-N-S. Personal/TestFlight use does not.
- Before submitting, run the **`app-review-prep`** Claude Code skill.

## Reference

`SagerNet/sing-box-for-apple` (the canonical NE + libbox integration), `WireGuard/wireguard-apple`,
`eycorsican/leaf`, `Jigsaw-Code/outline-apps`.
