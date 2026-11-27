import Foundation

enum Suit: Int, CaseIterable, Sendable {
    case spades, clubs, diamonds, hearts
    var symbol: String { ["♠", "♣", "♦", "♥"][rawValue] }
    var isRed: Bool { self == .diamonds || self == .hearts }
}

struct Card: Equatable, Hashable, Sendable {
    let id: Int
    let deckSize: Int
    init(id: Int, deckSize: Int = 36) {
        self.id = id
        self.deckSize = deckSize
    }
    private var cardsPerSuit: Int { deckSize / 4 }
    var suit: Suit { Suit(rawValue: id / cardsPerSuit)! }
    var rank: Int { id % cardsPerSuit + (cardsPerSuit == 6 ? 9 : 6) } // 24-card: 9-A; 36-card: 6-A
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
