import XCTest
@testable import DurakCore

final class DurakCoreTests: XCTestCase {
    func testDeckAndDealForTwoToFourPlayers() {
        for players in 2...4 {
            var rng = FastRNG(seed: UInt64(players))
            let state = GameState.newGame(players: players, using: &rng)
            XCTAssertEqual(state.hands.count, players)
            XCTAssertTrue(state.hands.allSatisfy { $0.count == 6 })
            XCTAssertEqual(state.deck.count, 36 - players * 6)
            XCTAssertEqual(state.deck[0].suit, state.trump)
        }
    }

    func testTenThousandGamesPreserveAllCardsAndFinish() {
        for game in 0..<10_000 {
            var rng = FastRNG(seed: UInt64(game + 1))
            var state = GameState.newGame(players: 2 + game % 3, using: &rng)
            var steps = 0
            while !state.over && steps < 1_000 {
                let moves = state.legalMoves()
                XCTAssertFalse(moves.isEmpty, "No legal move in game \(game)")
                state.apply(chooseMove(moves, state))
                steps += 1
                let ids = allCardIDs(state)
                XCTAssertEqual(ids.count, 36, "Card count changed in game \(game)")
                XCTAssertEqual(Set(ids).count, 36, "Duplicate/missing card in game \(game)")
            }
            XCTAssertTrue(state.over, "Game \(game) did not finish")
        }
    }

    func testMonteCarloReturnsLegalMove() {
        for seed in 1...30 {
            var rng = FastRNG(seed: UInt64(seed))
            let state = GameState.newGame(players: 2 + seed % 3, using: &rng)
            let legal = state.legalMoves()
            let move = MonteCarlo.chooseMove(state: state, player: state.actor, timeBudget: 0.01, maxPlayouts: 2)
            XCTAssertTrue(legal.contains(move))
        }
    }

    func testMergeAndCountingSortAgree() {
        var rng = FastRNG(seed: 987)
        let values = (0..<500).map { _ in Card(id: Int.random(in: 0..<36, using: &rng)) }
        var merge = DynamicArray<Card>(values)
        Sorts.mergeSort(&merge, key: { $0.id })
        let counting = Sorts.countingSort(values, k: 36, key: { $0.id })
        XCTAssertEqual(merge.toArray().map(\.id), counting.map(\.id))
    }

    func testShufflePreservesDeck() {
        var rng = FastRNG(seed: 123)
        var cards = DynamicArray<Card>((0..<36).map { Card(id: $0) })
        Sorts.fisherYates(&cards, using: &rng)
        XCTAssertEqual(Set(cards.toArray().map(\.id)), Set(0..<36))
    }

    private func chooseMove(_ moves: [Move], _ state: GameState) -> Move {
        var selected = moves[0]
        var best = Double.greatestFiniteMagnitude
        for move in moves {
            let score: Double
            switch move {
            case .attack(let card):
                score = Double(card.rank - 6) + (card.suit == state.trump ? 6 : 0)
            case .defend(let index, let card):
                let attack = state.table[index].attack
                score = Double(card.rank - attack.rank) + (card.suit == state.trump && attack.suit != state.trump ? 5 : 0)
            case .take: score = 7 + Double(state.undefendedCount)
            case .pass: score = 6
            }
            if score < best { best = score; selected = move }
        }
        return selected
    }

    private func allCardIDs(_ state: GameState) -> [Int] {
        var ids = [Int]()
        for hand in state.hands { for card in hand { ids.append(card.id) } }
        for card in state.deck { ids.append(card.id) }
        for pair in state.table {
            ids.append(pair.attack.id)
            if let defense = pair.defense { ids.append(defense.id) }
        }
        for card in state.discard.items { ids.append(card.id) }
        return ids
    }
}
