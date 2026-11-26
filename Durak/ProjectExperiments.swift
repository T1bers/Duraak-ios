import Foundation

/// Reproducible experiments described in the DSA final project proposal.
/// The CSV output can be copied into a spreadsheet to create the required plots.
enum ProjectExperiments {
    static func runAll() -> String {
        var sections = [String]()
        sections.append(sortComparisonCSV())
        sections.append(monteCarloScalingCSV())
        sections.append(randomOpponentWinRateCSV(games: 500, playoutsPerMove: 5))
        return sections.joined(separator: "\n\n")
    }

    static func sortComparisonCSV() -> String {
        var rng = FastRNG(seed: 20261126)
        var csv = "SORT_COMPARISON\nn,merge_sort_ms,counting_sort_ms\n"
        for n in [36, 1_000, 10_000, 100_000] {
            var source = [Card]()
            source.reserveCapacity(n)
            for _ in 0..<n { source.append(Card(id: Int.random(in: 0..<36, using: &rng))) }
            var mergeTotal: UInt64 = 0
            var countingTotal: UInt64 = 0
            for _ in 0..<50 {
                var values = DynamicArray<Card>(source)
                let t0 = DispatchTime.now().uptimeNanoseconds
                Sorts.mergeSort(&values, key: { $0.id })
                mergeTotal += DispatchTime.now().uptimeNanoseconds - t0

                let t1 = DispatchTime.now().uptimeNanoseconds
                _ = Sorts.countingSort(source, k: 36, key: { $0.id })
                countingTotal += DispatchTime.now().uptimeNanoseconds - t1
            }
            let mergeMS = Double(mergeTotal) / 50.0 / 1_000_000.0
            let countingMS = Double(countingTotal) / 50.0 / 1_000_000.0
            csv += String(format: "%d,%.6f,%.6f\n", n, mergeMS, countingMS)
        }
        return csv
    }

    static func monteCarloScalingCSV() -> String {
        var rng = FastRNG(seed: 741852)
        let state = GameState.newGame(players: 2, using: &rng)
        let player = state.actor
        var csv = "MONTE_CARLO_DECISION_SCALING\nplayouts_per_move,decision_ms,selected_move\n"
        for count in [10, 100, 1_000, 10_000] {
            let t0 = DispatchTime.now().uptimeNanoseconds
            let move = MonteCarlo.chooseMove(state: state, player: player,
                                             timeBudget: 86_400, maxPlayouts: count,
                                             fixedPlayouts: true, maxPlies: 100,
                                             seed: UInt64(741_852 + count))
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000.0
            csv += String(format: "%d,%.6f,%@\n", count, elapsed, String(describing: move))
        }
        return csv
    }

    static func randomOpponentWinRateCSV(games: Int, playoutsPerMove: Int) -> String {
        var monteCarloWins = 0
        var draws = 0
        var completed = 0
        for game in 0..<games {
            var steps = 0
            var rng = FastRNG(seed: UInt64(900_000 + game))
            var state = GameState.newGame(players: 2, using: &rng)
            while !state.over && steps < 1_000 {
                let moves = state.legalMoves()
                guard !moves.isEmpty else { break }
                let move: Move
                if state.actor == 0 {
                    move = MonteCarlo.chooseMove(state: state, player: 0,
                                                 timeBudget: 86_400,
                                                 maxPlayouts: playoutsPerMove,
                                                 fixedPlayouts: true, maxPlies: 100,
                                                 seed: UInt64(900_000 + game * 10_000 + steps))
                } else {
                    move = moves[Int.random(in: 0..<moves.count, using: &rng)]
                }
                state.apply(move)
                steps += 1
            }
            if state.over {
                completed += 1
                if state.durak == nil { draws += 1 }
                else if state.durak != 0 { monteCarloWins += 1 }
            }
        }
        let rate = completed == 0 ? 0.0 : Double(monteCarloWins) / Double(completed) * 100.0
        return String(format: "MONTE_CARLO_VS_RANDOM\ngames_requested,completed_games,monte_carlo_wins,draws,win_rate_percent,playouts_per_decision\n%d,%d,%d,%d,%.2f,%d",
                      games, completed, monteCarloWins, draws, rate, playoutsPerMove)
    }
}
