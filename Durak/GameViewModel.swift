import SwiftUI

@MainActor
final class GameVM: ObservableObject {
    @Published var state: GameState
    @Published var thinking = false
    @Published var message = "Your turn"

    private(set) var history = Stack<GameState>()
    let playerCount: Int
    let budget: Double
    private var token = 0

    init(players: Int, budget: Double) {
        self.playerCount = players
        self.budget = budget
        self.state = GameState.newGame(players: players)
        schedule()
    }

    func name(_ p: Int) -> String { p == 0 ? "You" : "Bot \(p)" }

    var canUndo: Bool { !history.isEmpty && !state.over }

    func humanPlay(_ card: Card) {
        guard state.actor == 0, !state.over else { return }
        var chosen: Move? = nil
        for m in state.legalMoves() {
            switch m {
            case .attack(let c) where c == card: chosen = m
            case .defend(_, let c) where c == card: chosen = m
            default: break
            }
        }
        guard let m = chosen else {
            message = "You cannot play this card"
            return
        }
        perform(m)
    }

    func humanTake() { if state.actor == 0 && state.legalMoves().contains(.take) { perform(.take) } }
    func humanPass() { if state.actor == 0 && state.legalMoves().contains(.pass) { perform(.pass) } }

    func undo() {
        guard canUndo else { return }
        token += 1
        thinking = false
        state = history.pop()
        message = "Move undone"
        schedule()
    }

    func restart() {
        token += 1
        thinking = false
        history.removeAll()
        state = GameState.newGame(players: playerCount)
        message = "New game"
        schedule()
    }

    private func describe(_ m: Move, by p: Int) -> String {
        switch m {
        case .attack(let c): return "\(name(p)) attacks with \(c.label)"
        case .defend(_, let c): return "\(name(p)) beats with \(c.label)"
        case .take: return "\(name(p)) takes the cards"
        case .pass: return state.defenderTaking ? "\(name(state.defender)) takes the cards" : "All cards beaten"
        }
    }

    private func perform(_ m: Move, record: Bool = true) {
        let actor = state.actor
        if record && actor == 0 { history.push(state) }
        message = describe(m, by: actor)
        token += 1
        state.apply(m)
        schedule()
    }

    private func schedule() {
        guard !state.over else {
            thinking = false
            return
        }
        let actor = state.actor
        let myToken = token
        if actor == 0 {
            thinking = false
            let moves = state.legalMoves()
            if moves.count == 1, case .pass = moves[0] {
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    guard myToken == token else { return }
                    perform(.pass, record: false)
                }
            }
            return
        }
        thinking = true
        let snapshot = state
        let budget = self.budget
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard myToken == token else { return }
            let move = await Task.detached(priority: .userInitiated) {
                MonteCarlo.chooseMove(state: snapshot, player: actor, timeBudget: budget)
            }.value
            guard myToken == token else { return }
            thinking = false
            perform(move)
        }
    }
}
