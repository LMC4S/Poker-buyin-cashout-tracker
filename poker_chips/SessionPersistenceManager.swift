import Foundation

class SessionPersistenceManager {
    static let shared = SessionPersistenceManager()
    
    private let sessionsKey = "saved_sessions"
    private let activeSessionKey = "active_session"
    
    func saveSessions(_ sessions: [Session]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: sessionsKey)
        }
    }

    func saveActiveSession(_ session: Session?) {
        let encoder = JSONEncoder()
        if let session = session, let encoded = try? encoder.encode(session) {
            UserDefaults.standard.set(encoded, forKey: activeSessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeSessionKey)
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

    func loadActiveSession() -> Session? {
        if let data = UserDefaults.standard.data(forKey: activeSessionKey) {
            let decoder = JSONDecoder()
            if let session = try? decoder.decode(Session.self, from: data) {
                return session
            }
        }
        return nil
    }
}
