import Foundation

enum ThrowInScope: String, Sendable, Hashable { case neighbors, all }

enum Move: Equatable, Sendable {
    case attack(Card)
    case defend(Int, Card)
    case transfer(Card)
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
    var transferEnabled: Bool = false
    var drawOnMoveLimit: Bool = true
    var throwInScope: ThrowInScope = .neighbors
    var throwInPassed: Set<Int> = []
    var throwInCursor: Int? = nil
    // A hidden illegal throw-in can be challenged by the human player.
    var cheatingPlayer: Int? = nil
    var cheatingTableIndex: Int? = nil

    init(hands: [DynamicArray<Card>], deck: DynamicArray<Card>, trump: Suit, order: CircularQueue<Int>, deckSize: Int = 36, transferEnabled: Bool = false, drawOnMoveLimit: Bool = true, throwInScope: ThrowInScope = .neighbors) {
        precondition((2...4).contains(hands.count), "Durak supports 2–4 players")
        self.hands = hands
        self.deck = deck
        self.trump = trump
        self.order = order
        self.deckSize = deckSize
        self.transferEnabled = transferEnabled
        self.drawOnMoveLimit = drawOnMoveLimit
        self.throwInScope = throwInScope
        self.throwInCursor = order[0]
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
        if !defenderTaking && undefendedCount > 0 { return defender }
        if table.count > 0 { return throwInCursor ?? attacker }
        return attacker
    }

    private var eligibleThrowInPlayers: [Int] {
        guard order.count >= 2 else { return [] }
        if throwInScope == .all {
            return (0..<order.count).map { order[$0] }.filter { $0 != defender }
        }
        let next = order.count > 2 ? order[2] : attacker
        return Array(Set([attacker, next])).filter { $0 != defender }
    }

    private func nextThrowIn(after player: Int, excluding passed: Set<Int>) -> Int? {
        guard order.count > 0 else { return nil }
        var position = 0
        for i in 0..<order.count where order[i] == player { position = i; break }
        for offset in 1...order.count {
            let candidate = order[(position + offset) % order.count]
            if eligibleThrowInPlayers.contains(candidate) && !passed.contains(candidate) { return candidate }
        }
        return nil
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
        let current = actor

        if !defenderTaking && current == defender && undefendedCount > 0 {
            let index = firstUndefended
            guard index >= 0 else { return [] }
            let attack = table[index].attack
            for card in hands[current] where beats(card, attack) {
                moves.append(.defend(index, card))
            }
            // Transfer Durak: pass the attack to the next player with a same-rank card.
            if transferEnabled, order.count > 2, table.count < roundLimit {
                let nextDefender = order[2]
                let transferRank = attack.rank
                if hands[nextDefender].count >= table.count + 1 {
                    for card in hands[current] where card.rank == transferRank {
                        moves.append(.transfer(card))
                    }
                }
            }
            moves.append(.take)
        } else if table.count == 0 {
            if current == attacker {
                for card in hands[current] { moves.append(.attack(card)) }
            }
        } else {
            if eligibleThrowInPlayers.contains(current), table.count < roundLimit {
                for card in hands[current] where tableRanks.contains(card.rank) {
                    moves.append(.attack(card))
                }
            }
            moves.append(.pass)
        }
        return moves
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
            let playingPlayer = actor
            removeFromHand(playingPlayer, card)
            table.append(Pair(attack: card, defense: nil))
            tableRanks.increment(card.rank)
            throwInPassed.removeAll()
            throwInCursor = nextThrowIn(after: playingPlayer, excluding: throwInPassed)
        case .defend(let index, let card):
            removeFromHand(defender, card)
            table[index].defense = card
            tableRanks.increment(card.rank)
        case .transfer(let card):
            let oldDefender = defender
            removeFromHand(oldDefender, card)
            table.append(Pair(attack: card, defense: nil))
            tableRanks.increment(card.rank)
            order.rotate(by: 1)
            roundLimit = min(6, hands[order[1]].count)
            throwInPassed.removeAll()
            throwInCursor = attacker
            defenderTaking = false
        case .take:
            defenderTaking = true
        case .pass:
            if defenderTaking {
                finishRound()
            } else {
                let passingPlayer = actor
                throwInPassed.insert(passingPlayer)
                if let next = nextThrowIn(after: passingPlayer, excluding: throwInPassed) {
                    throwInCursor = next
                } else {
                    finishRound()
                }
            }
        }
        // A hard cap turns pathological card-transfer cycles into a draw.
        if moveCount >= 1_000 && !over {
            over = true
            if drawOnMoveLimit {
                durak = nil
            } else {
                var lastPlayer = 0
                for player in 1..<playerCount where hands[player].count > hands[lastPlayer].count {
                    lastPlayer = player
                }
                durak = lastPlayer
            }
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
        throwInPassed.removeAll()
        throwInCursor = attacker

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

    static func newGame(players: Int, deckSize: Int = 36, transferEnabled: Bool = false, drawOnMoveLimit: Bool = true, throwInScope: ThrowInScope = .neighbors) -> GameState {
        var rng = SystemRandomNumberGenerator()
        return newGame(players: players, deckSize: deckSize, transferEnabled: transferEnabled, drawOnMoveLimit: drawOnMoveLimit, throwInScope: throwInScope, using: &rng)
    }

    static func newGame<G: RandomNumberGenerator>(players n: Int, deckSize: Int = 36, transferEnabled: Bool = false, drawOnMoveLimit: Bool = true, throwInScope: ThrowInScope = .neighbors, using rng: inout G) -> GameState {
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
        return GameState(hands: hands, deck: deck, trump: trump, order: order, deckSize: deckSize, transferEnabled: transferEnabled, drawOnMoveLimit: drawOnMoveLimit, throwInScope: throwInScope)
    }
}
