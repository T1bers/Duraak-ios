import Foundation

enum Move: Equatable, Sendable {
    case attack(Card)
    case defend(Int, Card)
    case take
    case pass
}

struct Pair: Sendable {
    var attack: Card
    var defense: Card?
}

struct GameState: Sendable {
    var hands: [DynamicArray<Card>]
    var deck: DynamicArray<Card>
    var trump: Suit
    var table = DynamicArray<Pair>()
    var tableRanks = HashTable()
    var discard = Stack<Card>()
    var order: CircularQueue<Int>
    var defenderTaking = false
    var roundLimit = 6
    var moveCount = 0
    var over = false
    var durak: Int? = nil
    var deckSize: Int = 36
    // A hidden illegal throw-in can be challenged by the human player.
    var cheatingPlayer: Int? = nil
    var cheatingTableIndex: Int? = nil

    init(hands: [DynamicArray<Card>], deck: DynamicArray<Card>, trump: Suit, order: CircularQueue<Int>, deckSize: Int = 36) {
        precondition((2...4).contains(hands.count), "Durak supports 2–4 players")
        self.hands = hands
        self.deck = deck
        self.trump = trump
        self.order = order
        self.deckSize = deckSize
        self.roundLimit = min(6, hands[order[1]].count)
    }

    var playerCount: Int { hands.count }
    var attacker: Int { order[0] }
    var defender: Int { order[1] }

    var undefendedCount: Int {
        var n = 0
        for p in table where p.defense == nil { n += 1 }
        return n
    }

    var firstUndefended: Int {
        for i in 0..<table.count where table[i].defense == nil { return i }
        return -1
    }

    var actor: Int {
        if over { return -1 }
        if defenderTaking { return attacker }
        return undefendedCount > 0 ? defender : attacker
    }

    func beats(_ card: Card, _ attack: Card) -> Bool {
        if card.suit == attack.suit { return card.rank > attack.rank }
        return card.suit == trump && attack.suit != trump
    }

    /// Sort key 0...35: non-trump suits first, trump suit last, ranks ascending.
    func sortKey(_ card: Card) -> Int {
        let group = card.suit == trump ? 3 : (card.suit.rawValue < trump.rawValue ? card.suit.rawValue : card.suit.rawValue - 1)
        return group * 9 + (card.rank - 6)
    }

    func legalMoves() -> [Move] {
        guard !over, order.count >= 2 else { return [] }
        var moves = [Move]()
        let a = attacker, d = defender

        if actor == d {
            let index = firstUndefended
            guard index >= 0 else { return [] }
            let attack = table[index].attack
            for card in hands[d] where beats(card, attack) {
                moves.append(.defend(index, card))
            }
            moves.append(.take)
        } else {
            if table.count == 0 {
                for card in hands[a] { moves.append(.attack(card)) }
            } else {
                if table.count < roundLimit {
                    for card in hands[a] where tableRanks.contains(card.rank) {
                        moves.append(.attack(card))
                    }
                }
                moves.append(.pass)
            }
        }
        return moves
    }

    /// A bot may secretly throw in a card whose rank is not on the table.
    /// This is deliberately separate from legalMoves(), so fair-play bots and
    /// the human player can never use this path.
    mutating func playCheat(_ card: Card, by player: Int) -> Bool {
        guard !over, player > 0, player < playerCount, actor == player,
              table.count > 0, table.count < roundLimit,
              !tableRanks.contains(card.rank) else { return false }
        var found = false
        for held in hands[player] where held == card { found = true; break }
        guard found else { return false }
        removeFromHand(player, card)
        table.append(Pair(attack: card, defense: nil))
        tableRanks.increment(card.rank)
        cheatingPlayer = player
        cheatingTableIndex = table.count - 1
        moveCount += 1
        return true
    }

    /// The player calls out the bot's suspicious card. The card is returned
    /// to the bot and the invalid throw-in is removed before play continues.
    mutating func challengeCheat() -> Bool {
        guard let player = cheatingPlayer, let index = cheatingTableIndex,
              index < table.count, table[index].defense == nil else { return false }
        let card = table[index].attack
        table.remove(at: index)
        hands[player].append(card)
        tableRanks = HashTable()
        for pair in table {
            tableRanks.increment(pair.attack.rank)
            if let defense = pair.defense { tableRanks.increment(defense.rank) }
        }
        cheatingPlayer = nil
        cheatingTableIndex = nil
        return true
    }

    private mutating func removeFromHand(_ player: Int, _ card: Card) {
        for i in 0..<hands[player].count where hands[player][i] == card {
            hands[player].remove(at: i)
            return
        }
    }

    mutating func apply(_ move: Move) {
        guard !over, legalMoves().contains(move) else { return }
        moveCount += 1
        switch move {
        case .attack(let card):
            removeFromHand(attacker, card)
            table.append(Pair(attack: card, defense: nil))
            tableRanks.increment(card.rank)
        case .defend(let index, let card):
            removeFromHand(defender, card)
            table[index].defense = card
            tableRanks.increment(card.rank)
        case .take:
            defenderTaking = true
        case .pass:
            finishRound()
        }
        // A hard cap turns pathological card-transfer cycles into a draw.
        if moveCount >= 1_000 && !over {
            over = true
            durak = nil
        }
    }

    private mutating func finishRound() {
        let defended = !defenderTaking
        let oldAttacker = attacker
        let oldDefender = defender

        for i in 0..<table.count {
            let pair = table[i]
            if defended {
                discard.push(pair.attack)
                if let defense = pair.defense { discard.push(defense) }
            } else {
                hands[oldDefender].append(pair.attack)
                if let defense = pair.defense { hands[oldDefender].append(defense) }
            }
        }

        table.removeAll()
        tableRanks = HashTable()
        cheatingPlayer = nil
        cheatingTableIndex = nil
        defenderTaking = false

        // The attacker draws first; the defender draws last.
        var drawOrder = [oldAttacker]
        if order.count > 2 {
            for i in 2..<order.count { drawOrder.append(order[i]) }
        }
        drawOrder.append(oldDefender)

        for player in drawOrder {
            while hands[player].count < 6 && !deck.isEmpty {
                hands[player].append(deck.removeLast())
            }
        }

        // If defended, defender attacks next. If cards were taken, the next
        // player after the defender attacks.
        order.rotate(by: defended ? 1 : 2)

        if deck.isEmpty {
            let activePlayers = (0..<playerCount).filter { !hands[$0].isEmpty }
            for player in 0..<playerCount where hands[player].isEmpty {
                order.remove(player)
            }
            if activePlayers.count <= 1 {
                over = true
                durak = activePlayers.first
                return
            }
        }

        if order.count <= 1 {
            over = true
            durak = order.count == 1 ? order[0] : nil
        } else {
            roundLimit = min(6, hands[order[1]].count)
        }
    }

    static func newGame(players: Int, deckSize: Int = 36) -> GameState {
        var rng = SystemRandomNumberGenerator()
        return newGame(players: players, deckSize: deckSize, using: &rng)
    }

    static func newGame<G: RandomNumberGenerator>(players n: Int, deckSize: Int = 36, using rng: inout G) -> GameState {
        precondition((2...4).contains(n), "Durak supports 2–4 players")
        precondition(deckSize == 24 || deckSize == 36, "Deck size must be 24 or 36")
        var deck = DynamicArray<Card>()
        for id in 0..<deckSize { deck.append(Card(id: id, deckSize: deckSize)) }
        Sorts.fisherYates(&deck, using: &rng)

        let trump = deck[0].suit
        var hands = [DynamicArray<Card>](repeating: DynamicArray<Card>(), count: n)
        for _ in 0..<6 {
            for player in 0..<n { hands[player].append(deck.removeLast()) }
        }

        var first = -1
        var lowestTrump = 99
        for player in 0..<n {
            for card in hands[player] where card.suit == trump && card.rank < lowestTrump {
                lowestTrump = card.rank
                first = player
            }
        }
        if first < 0 { first = Int.random(in: 0..<n, using: &rng) }

        var order = CircularQueue<Int>(capacity: n)
        for offset in 0..<n { order.enqueue((first + offset) % n) }
        return GameState(hands: hands, deck: deck, trump: trump, order: order, deckSize: deckSize)
    }
}
