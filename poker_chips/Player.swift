//
//  Player.swift
//  poker_chips
//
//  Created by lmc4s on 3/28/25.
//

import Foundation

struct Player: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id
    }
}
