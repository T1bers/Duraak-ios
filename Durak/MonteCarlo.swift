import Foundation

enum MonteCarlo {
    /// For each legal move plays many random games to the end; picks the best win rate.
    /// Rollouts use a lightweight card-cost policy instead of choosing every move uniformly at random.
    static func chooseMove(state: GameState, player: Int, timeBudget: Double, maxPlayouts: Int = 4000) -> Move {
        let moves = state.legalMoves()
        if moves.count <= 1 { return moves.first ?? .pass }

        var rng = FastRNG(seed: UInt64.random(in: 1...UInt64.max))

        // Seen cards -> hash table; unseen = opponents' hands + deck (without the face-up trump)
        var seen = HashTable()
        for c in state.hands[player] { seen.set(c.id, 1) }
        for i in 0..<state.table.count {
            seen.set(state.table[i].attack.id, 1)
            if let d = state.table[i].defense { seen.set(d.id, 1) }
        }
        for c in state.discard.items { seen.set(c.id, 1) }
        var trumpCard: Card? = nil
        if !state.deck.isEmpty {
            trumpCard = state.deck[0]
            seen.set(state.deck[0].id, 1)
        }
        var unseen = DynamicArray<Card>()
        for id in 0..<36 where !seen.contains(id) { unseen.append(Card(id: id)) }

        var wins = [Double](repeating: 0, count: moves.count)
        var plays = 0
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeBudget * 1_000_000_000)

        while plays < maxPlayouts {
            for (i, m) in moves.enumerated() {
                var s = determinize(state, me: player, unseen: unseen, trumpCard: trumpCard, rng: &rng)
                s.apply(m)
                wins[i] += playout(s, me: player, rng: &rng)
            }
            plays += 1
            if plays >= 5 && DispatchTime.now().uptimeNanoseconds >= deadline { break }
        }

        var best = 0
        for i in 1..<moves.count where wins[i] > wins[best] { best = i }
        return moves[best]
    }

    private static func determinize(_ s: GameState, me: Int, unseen: DynamicArray<Card>,
                                    trumpCard: Card?, rng: inout FastRNG) -> GameState {
        var st = s
        var pool = unseen
        Sorts.fisherYates(&pool, using: &rng)
        var idx = 0
        for p in 0..<st.playerCount where p != me {
            let need = st.hands[p].count
            st.hands[p].removeAll()
            for _ in 0..<need {
                st.hands[p].append(pool[idx])
                idx += 1
            }
        }
        st.deck.removeAll()
        if let t = trumpCard { st.deck.append(t) }
        while idx < pool.count {
            st.deck.append(pool[idx])
            idx += 1
        }
        return st
    }

    private static func playout(_ s: GameState, me: Int, rng: inout FastRNG) -> Double {
        var st = s
        var plies = 0
        while !st.over && plies < 400 {
            let moves = st.legalMoves()
            guard !moves.isEmpty else { break }
            let selected = rolloutMove(moves, state: st, rng: &rng)
            st.apply(selected)
            plies += 1
        }
        if !st.over { return 0.5 }
        guard let loser = st.durak else { return 0.5 }
        return loser == me ? 0 : 1
    }

    /// A small stochastic policy for simulated games:
    /// spend low cards first, preserve trumps when possible, and avoid wasteful attacks.
    private static func rolloutMove(_ moves: [Move], state: GameState, rng: inout FastRNG) -> Move {
        var bestMove = moves[0]
        var bestScore = Double.greatestFiniteMagnitude

        for move in moves {
            var score: Double
            switch move {
            case .attack(let card):
                score = Double(card.rank - 6)
                if card.suit == state.trump { score += 5.0 }
                if state.table.count > 0 { score += 1.5 }
            case .defend(let index, let card):
                let attack = state.table[index].attack
                score = Double(card.rank - attack.rank)
                if card.suit == state.trump && attack.suit != state.trump { score += 5.0 }
            case .take:
                score = 7.5 + Double(state.undefendedCount) * 0.6
                if state.hands[state.defender].count >= 5 { score -= 1.0 }
            case .pass:
                score = 1.8
            }

            // Small noise keeps simulated opponents varied without making their play random.
            score += Double.random(in: 0...1.2, using: &rng)
            if score < bestScore {
                bestScore = score
                bestMove = move
            }
        }
        return bestMove
    }
}
