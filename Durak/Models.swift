import Foundation

enum Suit: Int, CaseIterable, Sendable {
    case spades, clubs, diamonds, hearts
    var symbol: String { ["♠", "♣", "♦", "♥"][rawValue] }
    var isRed: Bool { self == .diamonds || self == .hearts }
}

struct Card: Equatable, Hashable, Sendable {
    let id: Int // 0...35
    var suit: Suit { Suit(rawValue: id / 9)! }
    var rank: Int { id % 9 + 6 } // 6...14 (J=11, Q=12, K=13, A=14)
    var rankLabel: String {
        switch rank {
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        case 14: return "A"
        default: return "\(rank)"
        }
    }
    var label: String { rankLabel + suit.symbol }
}
