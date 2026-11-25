import Foundation

enum Move: Equatable, Sendable {
    case attack(Card)
    case defend(Int, Card)   // index of the attack on the table
    case take                // defender takes the cards
    case pass                // attacker ends the round ("бито" / let the defender take)
}

struct Pair: Sendable {
    var attack: Card
    var defense: Card?
}

struct GameState: Sendable {
    var hands: [DynamicArray<Card>]
    var deck: DynamicArray<Card>          // deck[0] = face-up trump card, drawn last
    var trump: Suit
    var table = DynamicArray<Pair>()
    var tableRanks = HashTable()
    var discard = Stack<Card>()
    var order: CircularQueue<Int>         // front = attacker, next = defender
    var defenderTaking = false
    var roundLimit = 6
    var over = false
    var durak: Int? = nil

    init(hands: [DynamicArray<Card>], deck: DynamicArray<Card>, trump: Suit, order: CircularQueue<Int>) {
        self.hands = hands
        self.deck = deck
        self.trump = trump
        self.order = order
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

    func beats(_ c: Card, _ a: Card) -> Bool {
        if c.suit == a.suit { return c.rank > a.rank }
        return c.suit == trump && a.suit != trump
    }

    /// Sort key 0...35: non-trump suits first, trumps last, then by rank
    func sortKey(_ c: Card) -> Int {
        let g = c.suit == trump ? 3 : (c.suit.rawValue < trump.rawValue ? c.suit.rawValue : c.suit.rawValue - 1)
        return g * 9 + (c.rank - 6)
    }

    func legalMoves() -> [Move] {
        if over { return [] }
        var moves = [Move]()
        let a = attacker, d = defender
        if actor == d {
            let idx = firstUndefended
            let atk = table[idx].attack
            for c in hands[d] where beats(c, atk) { moves.append(.defend(idx, c)) }
            moves.append(.take)
        } else {
            if table.count == 0 {
                for c in hands[a] { moves.append(.attack(c)) }
            } else {
                if table.count < roundLimit {
                    for c in hands[a] where tableRanks.contains(c.rank) { moves.append(.attack(c)) }
                }
                moves.append(.pass)
            }
        }
        return moves
    }

    private mutating func removeFromHand(_ p: Int, _ c: Card) {
        for i in 0..<hands[p].count where hands[p][i] == c {
            hands[p].remove(at: i)
            return
        }
    }

    mutating func apply(_ m: Move) {
        switch m {
        case .attack(let c):
            removeFromHand(attacker, c)
            table.append(Pair(attack: c, defense: nil))
            tableRanks.increment(c.rank)
        case .defend(let idx, let c):
            removeFromHand(defender, c)
            table[idx].defense = c
            tableRanks.increment(c.rank)
        case .take:
            defenderTaking = true
        case .pass:
            finishRound()
        }
    }

    private mutating func finishRound() {
        let defended = !defenderTaking
        let a = attacker, d = defender
        for i in 0..<table.count {
            let p = table[i]
            if defended {
                discard.push(p.attack)
                if let df = p.defense { discard.push(df) }
            } else {
                hands[d].append(p.attack)
                if let df = p.defense { hands[d].append(df) }
            }
        }
        table.removeAll()
        tableRanks = HashTable()
        defenderTaking = false

        // draw: attacker first, defender last
        var drawOrder = [a]
        for i in stride(from: 2, to: order.count, by: 1) { drawOrder.append(order[i]) }
        drawOrder.append(d)
        for p in drawOrder {
            while hands[p].count < 6 && !deck.isEmpty {
                hands[p].append(deck.removeLast())
            }
        }

        order.rotate(by: defended ? 1 : 2)

        if deck.isEmpty {
            for p in 0..<playerCount where hands[p].isEmpty && order.contains(p) {
                order.remove(p)
            }
        }

        if order.count <= 1 {
            over = true
            durak = order.count == 1 ? order[0] : nil
        } else {
            roundLimit = min(6, hands[defender].count)
        }
    }

    static func newGame(players n: Int) -> GameState {
        var rng = SystemRandomNumberGenerator()
        var deck = DynamicArray<Card>()
        for id in 0..<36 { deck.append(Card(id: id)) }
        Sorts.fisherYates(&deck, using: &rng)
        let trump = deck[0].suit
        var hands = [DynamicArray<Card>](repeating: DynamicArray<Card>(), count: n)
        for _ in 0..<6 {
            for p in 0..<n { hands[p].append(deck.removeLast()) }
        }
        var first = -1
        var best = 99
        for p in 0..<n {
            for c in hands[p] where c.suit == trump && c.rank < best {
                best = c.rank
                first = p
            }
        }
        if first < 0 { first = Int.random(in: 0..<n, using: &rng) }
        var order = CircularQueue<Int>(capacity: n)
        for k in 0..<n { order.enqueue((first + k) % n) }
        return GameState(hands: hands, deck: deck, trump: trump, order: order)
    }
}
