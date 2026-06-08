# Engine integration — wiring sing-box (libbox) into Veil

The packet-tunnel needs a proxy engine. Veil uses **sing-box** via its `libbox` gomobile
framework. The Swift side is already wired (`PacketTunnel/LibboxEngine.swift`) and activates
automatically behind `#if canImport(Libbox)` once two things are present:

1. `Frameworks/Libbox.xcframework` — the built engine
2. `PacketTunnel/VeilPlatformInterface.swift` — the TUN/interface bridge (vendored)

Until both exist, the `#else` stub keeps the app building so you can iterate the UI; tapping
**Connect** fails with a clear "engine not wired" message.

> **Do this in the macOS build VM** (v12 `veil-mac`, or a Mac). gomobile needs macOS + Xcode,
> and you want the compiler + libbox headers in front of you — don't hand-write this blind.

---

## Step 1 — Build Libbox.xcframework

```bash
./scripts/build-libbox.sh          # clones sing-box @ $SINGBOX_REF, gomobile bind → xcframework
```
Then in `project.yml` uncomment the framework dependency on the `PacketTunnel` target and
re-run `xcodegen generate`. Keep build tags minimal (`with_gvisor` is in the script); add
`with_quic`, `with_wireguard`, `with_utls`, etc. only as you ship those protocols — every tag
costs binary + runtime memory against the ~50 MiB NE budget.

## Step 2 — Vendor the platform interface (don't re-port it)

The platform interface is ~500 lines of version-coupled, GPLv3 code that converts libbox's
`LibboxTunOptions` into `NEPacketTunnelNetworkSettings`, opens the TUN, and runs the default
interface monitor. Since the Veil client is GPLv3 (open source) anyway, **vendor upstream's
maintained version** rather than forking it:

Copy from <https://github.com/SagerNet/sing-box-for-apple> (`Library/Network/`):
- `ExtensionPlatformInterface.swift` → rename the class to **`VeilPlatformInterface`** and
  change its initializer to `init(provider: NEPacketTunnelProvider)` (it currently takes the
  `ExtensionProvider`; we only need the provider handle for `setTunnelNetworkSettings` + the
  tun fd via `packetFlow.value(forKeyPath: "socket.fileDescriptor")`).
- `Extension+RunBlocking.swift` (the `runBlocking { }` helper `openTun` uses).
- Any small helpers it references (e.g. `NEVPNStatus+isConnected`, logger shims) — pull only
  what the compiler asks for.

Keep the upstream copyright/licence headers. Pin the source to the **same `SINGBOX_REF`** you
built libbox from in Step 1 — the libbox API (`LibboxNewCommandServer`, `LibboxTunOptions`,
`LibboxSetupOptions`) shifts between versions.

## Step 3 — Call sequence (already implemented)

`LibboxEngine.start(configContent:provider:)` does, faithfully to upstream:
`LibboxSetup` → `LibboxSetMemoryLimit(true)` → `LibboxNewCommandServer(platform, platform)` →
`start()` → `startOrReloadService(configContent)`. The `configContent` string is the sing-box
JSON produced by `Shared/SingBoxConfig.swift` from the active `Profile`. Nothing to change
here unless the libbox API moved.

## Step 4 — Memory discipline

Run the **`ne-memory-audit`** Claude Code skill. Key levers: `LibboxSetMemoryLimit(true)` (on),
low `GOMEMLIMIT`/`GOGC` baked into the gomobile build, minimal build tags, bounded buffers.
Measure idle / peak-under-load / steady-state on the oldest target device. If sing-box can't
stay under ~40 MiB, that's the signal to switch the engine to **leaf** (Rust, Apache-2.0) —
which also flips the licensing model toward a closed-source client.

## Gotchas

- **openTun owns the TUN.** The platform interface calls `setTunnelNetworkSettings` itself, so
  `PacketTunnelProvider` does NOT (already removed). Don't add it back.
- **GPLv3.** Shipping libbox makes the client GPLv3 — keep it open source and monetize the
  service/Pro features (see `plans/proxy-app/docs/plan-v1.html`).
- **Config schema.** `SingBoxConfig.swift` targets sing-box 1.8+; if you bump `SINGBOX_REF`
  across a schema change, update the JSON builder too.
