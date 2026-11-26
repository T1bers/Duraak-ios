import SwiftUI

@MainActor
final class GameVM: ObservableObject {
    @Published var state: GameState
    @Published var thinking = false
    @Published var message = "Your turn"
    @Published var remainingTime = 0
    // Incremented on replay so GameView can reset and animate a fresh deal.
    @Published private(set) var restartGeneration = 0

    private(set) var history = Stack<GameState>()
    let playerCount: Int
    let budget: Double
    let cheaterMode: Bool
    let playerTimeout: Int
    let deckSize: Int
    let transferEnabled: Bool
    let drawOnMoveLimit: Bool
    let throwInScope: ThrowInScope
    private var token = 0
    private var forceFairNextBotMove = false

    init(players: Int, budget: Double, cheaterMode: Bool = false, playerTimeout: Int = 30, deckSize: Int = 36, transferEnabled: Bool = false, drawOnMoveLimit: Bool = true, throwInScope: ThrowInScope = .neighbors) {
        self.playerCount = players
        self.budget = budget
        self.cheaterMode = cheaterMode
        self.playerTimeout = playerTimeout
        self.deckSize = deckSize
        self.transferEnabled = transferEnabled
        self.drawOnMoveLimit = drawOnMoveLimit
        self.throwInScope = throwInScope
        self.state = GameState.newGame(players: players, deckSize: deckSize, transferEnabled: transferEnabled, drawOnMoveLimit: drawOnMoveLimit, throwInScope: throwInScope)
        schedule()
    }

    func name(_ p: Int) -> String { p == 0 ? "You" : "Bot \(p)" }

    var canUndo: Bool { !history.isEmpty && !state.over }

    func humanPlay(_ card: Card) {
        guard !state.over else { return }
        if state.actor == 0 {
            for move in state.legalMoves() {
                if move == .attack(card) || move == .defend(state.firstUndefended, card) || move == .transfer(card) {
                    perform(move)
                    return
                }
            }
        }
        // An eligible human attacker can throw in during the bot defender's turn.
        history.push(state)
        if state.playHumanThrowIn(card, by: 0) {
            token += 1
            message = "You throw in \(card.label)"
            schedule()
            return
        }
        _ = history.pop()
        message = "You cannot play this card"
    }
    func humanDefend(_ card: Card) {
        guard state.actor == 0 else { return }
        let index = state.firstUndefended
        let move = Move.defend(index, card)
        guard state.legalMoves().contains(move) else {
            message = "This card cannot beat the attack"
            return
        }
        perform(move)
    }

    /// Explicitly throw in a matching-rank card without letting humanPlay()
    /// reinterpret it as a defense against the first undefended attack.
    func humanThrowIn(_ card: Card) {
        guard !state.over else { return }
        history.push(state)
        guard state.playHumanThrowIn(card, by: 0) else {
            _ = history.pop()
            message = "You cannot throw in this card"
            return
        }
        token += 1
        message = "You throw in \(card.label)"
        schedule()
    }

    func humanTransfer(_ card: Card) {
        guard state.actor == 0 else { return }
        let move = Move.transfer(card)
        guard state.legalMoves().contains(move) else {
            message = "This card cannot transfer the attack"
            return
        }
        perform(move)
    }

    func humanTake() { if state.actor == 0 && state.legalMoves().contains(.take) { perform(.take) } }
    func humanPass() { if state.actor == 0 && state.legalMoves().contains(.pass) { perform(.pass) } }

    func challengeCheat(at tableIndex: Int) {
        guard state.cheatingTableIndex == tableIndex, state.challengeCheat() else { return }
        token += 1
        forceFairNextBotMove = true
        message = "Cheating caught! The card was returned."
        schedule()
    }

    func undo() {
        guard canUndo else { return }
        token += 1
        thinking = false
        state = history.pop()
        message = "Move undone"
        schedule()
    }

    func restart() {
        restartGeneration += 1
        token += 1
        thinking = false
        history.removeAll()
        state = GameState.newGame(players: playerCount, deckSize: deckSize, transferEnabled: transferEnabled, drawOnMoveLimit: drawOnMoveLimit, throwInScope: throwInScope)
        message = "New game"
        schedule()
    }

    private func describe(_ m: Move, by p: Int) -> String {
        switch m {
        case .attack(let c): return "\(name(p)) attacks with \(c.label)"
        case .defend(_, let c): return "\(name(p)) beats with \(c.label)"
        case .transfer(let c): return "\(name(p)) transfers with \(c.label)"
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
            remainingTime = playerTimeout
            Task {
                for second in stride(from: playerTimeout, through: 1, by: -1) {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard myToken == token, !state.over, state.actor == 0 else { return }
                    remainingTime = second - 1
                }
                guard myToken == token, !state.over, state.actor == 0 else { return }
                token += 1
                state.over = true
                state.durak = 0
                message = "Time is up. You lose this game."
                thinking = false
            }
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
        message = "Bot \(actor) is considering its move…"
        let snapshot = state
        let budget = self.budget

        // Keep the decision visibly deliberate. The Monte Carlo calculation still
        // runs off the main thread, and the minimum delay prevents instant bot turns.
        Task {
            let startedAt = DispatchTime.now().uptimeNanoseconds
            let delayRange: ClosedRange<UInt64> = budget < 0.3 ? 700_000_000...1_100_000_000 : (budget < 0.7 ? 1_100_000_000...1_700_000_000 : 1_600_000_000...2_200_000_000)
            let minimumThinkTime = UInt64.random(in: delayRange)

            // Cheater mode is a hidden, occasional rule violation. Bots do not
            // inspect other hands; they only sometimes throw an off-rank card.
            let caughtLastTime = forceFairNextBotMove
            forceFairNextBotMove = false
            var cheatCard: Card? = nil
            if cheaterMode, !caughtLastTime, snapshot.table.count > 0,
               snapshot.table.count < snapshot.roundLimit,
               Double.random(in: 0...1) < 0.16 {
                let candidates = snapshot.hands[actor].toArray().filter { !snapshot.tableRanks.contains($0.rank) }
                cheatCard = candidates.randomElement()
            }

            let move: Move? = await Task.detached(priority: .userInitiated) {
                if cheatCard == nil {
                    return MonteCarlo.chooseMove(state: snapshot, player: actor, timeBudget: budget)
                }
                return nil
            }.value

            let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
            if elapsed < minimumThinkTime {
                try? await Task.sleep(nanoseconds: minimumThinkTime - elapsed)
            }

            guard myToken == token else { return }
            thinking = false
            if let cheatCard, state.playCheat(cheatCard, by: actor) {
                message = "Bot \(actor) added a card…"
                token += 1
                schedule()
            } else if let move {
                perform(move)
            }
        }
    }
}
