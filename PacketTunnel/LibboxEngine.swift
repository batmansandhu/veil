import Foundation
import NetworkExtension
import os.log

// The real engine activates automatically once BOTH are present:
//   1. Frameworks/Libbox.xcframework  (build with scripts/build-libbox.sh)
//   2. VeilPlatformInterface.swift    (vendored from sing-box-for-apple — see INTEGRATION.md)
// Until then the #else stub keeps the app building so you can iterate the UI.

#if canImport(Libbox)
import Libbox

/// Faithful to SagerNet/sing-box-for-apple `ExtensionProvider`'s start sequence.
/// The platform interface performs the TUN open (it calls setTunnelNetworkSettings itself),
/// so PacketTunnelProvider must NOT set network settings.
final class LibboxEngine {
    private let log = OSLog(subsystem: AppGroup.tunnelBundleID, category: "engine")
    private var commandServer: LibboxCommandServer?
    private var platform: VeilPlatformInterface?

    func start(configContent: String, provider: NEPacketTunnelProvider) throws {
        // 1) Paths in the App Group container + bounded logging.
        let base = AppGroup.containerURL
        let opts = LibboxSetupOptions()
        opts.basePath = base.path
        opts.workingPath = base.appendingPathComponent("work").path
        opts.tempPath = base.appendingPathComponent("tmp").path
        opts.logMaxLines = 3000
        var setupErr: NSError?
        LibboxSetup(opts, &setupErr)
        if let setupErr { throw setupErr }

        // 2) Respect the ~50 MiB Network Extension budget (see the ne-memory-audit skill).
        LibboxSetMemoryLimit(true)

        // 3) Command server bound to our platform interface (TUN + interface monitor).
        let platform = VeilPlatformInterface(provider: provider)
        self.platform = platform
        var err: NSError?
        commandServer = LibboxNewCommandServer(platform, platform, &err)
        if let err { throw err }
        try commandServer?.start()

        // 4) Start sing-box with the config we build in Shared/SingBoxConfig.swift.
        try commandServer?.startOrReloadService(configContent, options: LibboxOverrideOptions())
    }

    func stop() {
        try? commandServer?.closeService()
        commandServer?.close()
        commandServer = nil
        platform = nil
    }

    func wake() { commandServer?.wake() }
    func sleep() { commandServer?.pause() }
}

#else

/// Stub — active until Libbox.xcframework is added. App builds; Connect fails clearly.
final class LibboxEngine {
    private let log = OSLog(subsystem: AppGroup.tunnelBundleID, category: "engine")

    func start(configContent: String, provider: NEPacketTunnelProvider) throws {
        os_log("LibboxEngine STUB — no engine wired (see INTEGRATION.md). config=%{public}d bytes",
               log: log, type: .info, configContent.utf8.count)
        throw VeilTunnelError.engineUnavailable
    }

    func stop() {}
    func wake() {}
    func sleep() {}
}
#endif
