import Foundation

/// Persisted login session — mirrors Android `SessionManager` / SharedPreferences.
struct StoredLoginSession: Codable {
    var token: String?
    var user: LoginUser?
    var portal_type: String?
    var portal_info: TraderPortalInfo?
}

enum LoginSessionStore {
    private static let key = "ax_login_session"

    static func save(_ session: StoredLoginSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> StoredLoginSession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredLoginSession.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
