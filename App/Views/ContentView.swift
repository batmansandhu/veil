import SwiftUI
import NetworkExtension

struct ContentView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var tunnel: TunnelManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    HStack(spacing: 10) {
                        Circle().fill(statusColor).frame(width: 10, height: 10)
                        Text(statusText)
                        Spacer()
                        Button(isActive ? "Disconnect" : "Connect") {
                            Task {
                                if isActive {
                                    tunnel.stop()
                                } else {
                                    store.save()
                                    await tunnel.start(profile: store.profile)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Section("Home proxy") {
                    TextField("Name", text: $store.profile.name)
                    Picker("Type", selection: $store.profile.type) {
                        ForEach(Profile.ProxyType.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Host (Tailscale IP)", text: $store.profile.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Port", value: $store.profile.port, format: .number)
                        .keyboardType(.numberPad)
                }

                if store.profile.type != .shadowsocks {
                    Section("Auth (optional)") {
                        TextField("Username", text: bind(\.username))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: bind(\.password))
                    }
                }

                Section {
                    Text("Routes all traffic through your home proxy and uses AdGuard (192.168.1.3) for DNS. Connect over Tailscale so the proxy is never exposed to the internet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Veil")
            .onChange(of: store.profile) { _ in store.save() }
            .alert("Error", isPresented: errorBinding) {
                Button("OK") { tunnel.lastError = nil }
            } message: {
                Text(tunnel.lastError ?? "")
            }
        }
    }

    // MARK: - Derived state

    private var isActive: Bool {
        tunnel.status == .connected || tunnel.status == .connecting || tunnel.status == .reasserting
    }

    private var statusText: String {
        switch tunnel.status {
        case .connected:     return "Connected"
        case .connecting:    return "Connecting…"
        case .disconnecting: return "Disconnecting…"
        case .disconnected:  return "Disconnected"
        case .reasserting:   return "Reconnecting…"
        case .invalid:       return "Not configured"
        @unknown default:    return "Unknown"
        }
    }

    private var statusColor: Color {
        switch tunnel.status {
        case .connected:               return .green
        case .connecting, .reasserting: return .yellow
        default:                        return .secondary
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { tunnel.lastError != nil },
                set: { if !$0 { tunnel.lastError = nil } })
    }

    /// Binding for an optional String field on the profile, treating "" as nil.
    private func bind(_ keyPath: WritableKeyPath<Profile, String?>) -> Binding<String> {
        Binding(
            get: { store.profile[keyPath: keyPath] ?? "" },
            set: { store.profile[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}
