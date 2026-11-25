import Foundation

enum Suit: Int, CaseIterable, Sendable {
    case spades, clubs, diamonds, hearts
    var symbol: String { ["♠", "♣", "♦", "♥"][rawValue] }
    var isRed: Bool { self == .diamonds || self == .hearts }
}

struct Card: Equatable, Hashable, Sendable {
    let id: Int // 0...35
    var suit: Suit { Suit(rawValue: id / 9)! }
    var rank: Int { id % 9 + 6 } // 6...14 (В=11, Д=12, К=13, Т=14)
    var rankLabel: String {
        switch rank {
        case 11: return "В"
        case 12: return "Д"
        case 13: return "К"
        case 14: return "Т"
        default: return "\(rank)"
        }
    }
    var label: String { rankLabel + suit.symbol }
}
