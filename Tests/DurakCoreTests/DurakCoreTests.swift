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

    func testTenThousandGamesPreserveAllCards() {
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
            XCTAssertTrue(state.over, "Game \\(game) did not finish or reach the draw limit")
        }
    }




    func testNeighborAndAllThrowInScopesChooseDifferentNextPlayers() {
        func preparedState(scope: ThrowInScope) -> GameState {
            var queue = CircularQueue<Int>(capacity: 4)
            queue.enqueue(0); queue.enqueue(1); queue.enqueue(2); queue.enqueue(3)
            let hands = [
                DynamicArray<Card>([Card(id: 0), Card(id: 1)]),
                DynamicArray<Card>([Card(id: 2), Card(id: 3)]),
                DynamicArray<Card>([Card(id: 9), Card(id: 10)]),
                DynamicArray<Card>([Card(id: 18), Card(id: 19)])
            ]
            var state = GameState(hands: hands, deck: DynamicArray<Card>(), trump: .hearts,
                                  order: queue, throwInScope: scope)
            state.apply(.attack(Card(id: 0)))
            state.apply(.defend(0, Card(id: 2)))
            return state
        }

        var neighbors = preparedState(scope: .neighbors)
        XCTAssertEqual(neighbors.actor, 2)
        neighbors.apply(.pass)
        XCTAssertEqual(neighbors.actor, 0)

        var all = preparedState(scope: .all)
        XCTAssertEqual(all.actor, 2)
        all.apply(.pass)
        XCTAssertEqual(all.actor, 3)
    }

    func testCheaterCardCanBeCalledOutAndReturnedToBot() {
        var queue = CircularQueue<Int>(capacity: 2)
        queue.enqueue(1); queue.enqueue(0)
        let hands = [
            DynamicArray<Card>([Card(id: 11), Card(id: 20)]),
            DynamicArray<Card>([Card(id: 9), Card(id: 12)])
        ]
        var state = GameState(hands: hands, deck: DynamicArray<Card>(), trump: .hearts, order: queue)
        state.apply(.attack(Card(id: 9)))
        state.apply(.defend(0, Card(id: 11)))
        XCTAssertTrue(state.playCheat(Card(id: 12), by: 1))
        XCTAssertEqual(state.cheatingPlayer, 1)
        XCTAssertTrue(state.challengeCheat())
        XCTAssertNil(state.cheatingPlayer)
        XCTAssertEqual(state.table.count, 1)
        XCTAssertTrue(state.hands[1].toArray().contains(Card(id: 12)))
    }

    func testTransferMovesAttackToNextDefender() {
        var queue = CircularQueue<Int>(capacity: 3)
        queue.enqueue(0); queue.enqueue(1); queue.enqueue(2)
        let hands = [
            DynamicArray<Card>([Card(id: 0), Card(id: 3)]),
            DynamicArray<Card>([Card(id: 9), Card(id: 10)]),
            DynamicArray<Card>([Card(id: 18), Card(id: 19)])
        ]
        var state = GameState(hands: hands, deck: DynamicArray<Card>(), trump: .hearts,
                              order: queue, transferEnabled: true)
        state.apply(.attack(Card(id: 0)))
        XCTAssertTrue(state.legalMoves().contains(.transfer(Card(id: 9))))
        state.apply(.transfer(Card(id: 9)))
        XCTAssertEqual(state.attacker, 1)
        XCTAssertEqual(state.defender, 2)
        XCTAssertEqual(state.actor, 2)
        XCTAssertEqual(state.table.count, 2)
    }

    func testTwentyFourCardDeckUsesNineThroughAce() {
        var rng = FastRNG(seed: 2400)
        let state = GameState.newGame(players: 3, deckSize: 24, using: &rng)
        XCTAssertEqual(state.deck.count + state.hands.reduce(0) { $0 + $1.count }, 24)
        let allCards = (0..<24).map { Card(id: $0, deckSize: 24) }
        XCTAssertEqual(Set(allCards.map(\.suit)).count, 4)
        XCTAssertEqual(allCards.map(\.rank).min(), 9)
        XCTAssertEqual(allCards.map(\.rank).max(), 14)
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

    func testTrumpAndSameSuitBeatingRules() {
        var queue = CircularQueue<Int>(capacity: 2)
        queue.enqueue(0); queue.enqueue(1)
        let hands = [
            DynamicArray<Card>([Card(id: 0)]),
            DynamicArray<Card>([Card(id: 2)])
        ]
        let state = GameState(hands: hands, deck: DynamicArray<Card>(), trump: .hearts, order: queue)
        XCTAssertTrue(state.beats(Card(id: 2), Card(id: 0)))
        XCTAssertTrue(state.beats(Card(id: 27), Card(id: 0)))
        XCTAssertTrue(state.beats(Card(id: 28), Card(id: 27)))
        XCTAssertFalse(state.beats(Card(id: 27), Card(id: 28)))
        XCTAssertFalse(state.beats(Card(id: 11), Card(id: 27)))
    }

    func testAttackerCanOnlyAddRanksAlreadyOnTable() {
        var queue = CircularQueue<Int>(capacity: 2)
        queue.enqueue(0); queue.enqueue(1)
        let hands = [
            DynamicArray<Card>([Card(id: 0), Card(id: 9), Card(id: 10)]),
            DynamicArray<Card>([Card(id: 2), Card(id: 3)])
        ]
        var state = GameState(hands: hands, deck: DynamicArray<Card>(), trump: .hearts, order: queue)
        state.apply(.attack(Card(id: 0)))
        state.apply(.defend(0, Card(id: 2)))
        let moves = state.legalMoves()
        XCTAssertTrue(moves.contains(.attack(Card(id: 9))))
        XCTAssertFalse(moves.contains(.attack(Card(id: 10))))
    }

    func testAllPlayersOutTogetherIsADraw() {
        var queue = CircularQueue<Int>(capacity: 2)
        queue.enqueue(0); queue.enqueue(1)
        let hands = [
            DynamicArray<Card>([Card(id: 0)]),
            DynamicArray<Card>([Card(id: 1)])
        ]
        var state = GameState(hands: hands, deck: DynamicArray<Card>(), trump: .hearts, order: queue)
        state.apply(.attack(Card(id: 0)))
        state.apply(.defend(0, Card(id: 1)))
        state.apply(.pass)
        XCTAssertTrue(state.over)
        XCTAssertNil(state.durak)
    }

    func testStackQueueAndHashTableOperations() {
        var stack = Stack<Int>()
        XCTAssertTrue(stack.isEmpty)
        stack.push(10); stack.push(20)
        XCTAssertEqual(stack.pop(), 20)
        XCTAssertEqual(stack.peek(), 10)

        var queue = CircularQueue<Int>(capacity: 4)
        for value in 0..<4 { queue.enqueue(value) }
        queue.rotate(by: 2)
        XCTAssertEqual((0..<queue.count).map { queue[$0] }, [2, 3, 0, 1])
        queue.remove(3)
        XCTAssertEqual((0..<queue.count).map { queue[$0] }, [2, 0, 1])

        var table = HashTable(capacity: 2)
        for value in 0..<100 { table.set(value, value * 2) }
        for value in 0..<100 { XCTAssertEqual(table.get(value), value * 2) }
        XCTAssertTrue(table.remove(50))
        XCTAssertFalse(table.contains(50))
    }

    func testShufflePositionDistributionWithChiSquare() {
        var rng = FastRNG(seed: 20261125)
        var counts = [Int](repeating: 0, count: 36)
        let samples = 2_000
        for _ in 0..<samples {
            var cards = DynamicArray<Card>((0..<36).map { Card(id: $0) })
            Sorts.fisherYates(&cards, using: &rng)
            counts[cards[0].id] += 1
        }
        let expected = Double(samples) / 36.0
        let chiSquare = counts.reduce(0.0) { partial, observed in
            let delta = Double(observed) - expected
            return partial + delta * delta / expected
        }
        XCTAssertLessThan(chiSquare, 70.0)
    }

    func testRequiredProposalExperiments() {
        let sorting = ProjectExperiments.sortComparisonCSV()
        XCTAssertTrue(sorting.contains("100000"))
        print("\n" + sorting)

        let scaling = ProjectExperiments.monteCarloScalingCSV()
        XCTAssertTrue(scaling.contains("10000"))
        print("\n" + scaling)

        let strength = ProjectExperiments.randomOpponentWinRateCSV(games: 500, playoutsPerMove: 10)
        XCTAssertTrue(strength.contains("500"))
        print("\n" + strength)
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
            case .transfer(let card): score = Double(card.rank - 6) + (card.suit == state.trump ? 5 : 0)
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
