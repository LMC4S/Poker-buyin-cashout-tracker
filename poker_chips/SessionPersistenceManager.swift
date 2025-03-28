import Foundation
import SwiftUI

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
    
    // MARK: - Export Functions
    
    func exportSessionsToJSON(sessions: [Session]) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        guard let jsonData = try? encoder.encode(sessions) else {
            return nil
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "poker_sessions_\(Date().timeIntervalSince1970).json"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing JSON file: \(error)")
            return nil
        }
    }
    
    func exportSessionsToCSV(sessions: [Session]) -> URL? {
        var csvString = "Session Date,Player,Buy-In,Cash-Out,Net\n"
        
        for session in sessions {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: session.startDate)
            
            for player in session.buyIns.keys.sorted() {
                let buyIn = session.buyIns[player] ?? 0.0
                let cashOut = session.cashOuts[player] ?? 0.0
                let net = cashOut - buyIn
                
                // Escape commas in player names
                let escapedPlayerName = player.contains(",") ? "\"\(player)\"" : player
                
                csvString.append("\(dateString),\(escapedPlayerName),\(buyIn),\(cashOut),\(net)\n")
            }
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "poker_sessions_\(Date().timeIntervalSince1970).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV file: \(error)")
            return nil
        }
    }
}
