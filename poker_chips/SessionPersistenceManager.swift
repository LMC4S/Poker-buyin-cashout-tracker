import Foundation

class SessionPersistenceManager {
    static let shared = SessionPersistenceManager()
    
    private let sessionsKey = "saved_sessions"
    
    func saveSessions(_ sessions: [Session]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: sessionsKey)
        }
    }
    
    func loadSessions() -> [Session] {
        if let data = UserDefaults.standard.data(forKey: sessionsKey) {
            let decoder = JSONDecoder()
            if let sessions = try? decoder.decode([Session].self, from: data) {
                return sessions
            }
        }
        return []
    }
}
