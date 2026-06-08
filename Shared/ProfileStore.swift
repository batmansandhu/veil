import Foundation
import Combine

/// Persists the active profile to the App Group container so the extension can read it.
final class ProfileStore: ObservableObject {
    @Published var profile: Profile

    init() {
        self.profile = ProfileStore.load() ?? .homelabDefault
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(profile)
            try data.write(to: AppGroup.activeProfileURL, options: .atomic)
        } catch {
            NSLog("Veil: failed to persist profile: \(error)")
        }
    }

    static func load() -> Profile? {
        guard let data = try? Data(contentsOf: AppGroup.activeProfileURL) else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: data)
    }
}
