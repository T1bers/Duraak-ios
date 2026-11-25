import SwiftUI

// MARK: - Root + menu
struct GameConfig: Identifiable {
    let id = UUID()
    let players: Int
    let budget: Double
}

struct RootView: View {
    @State private var config: GameConfig? = nil

    var body: some View {
        if let c = config {
            GameView(players: c.players, budget: c.budget, onExit: { config = nil }).id(c.id)
        } else {
            MenuView(onStart: { p, b in config = GameConfig(players: p, budget: b) })
        }
    }
}

struct MenuView: View {
    var onStart: (Int, Double) -> Void
    @State private var opponents = 1
    @State private var level = 1
    @State private var showBench = false
    @State private var benchText = ""
    @State private var running = false
    @State private var showInfo = false

    var body: some View {
        ZStack {
            Table.background
            VStack(spacing: 22) {
                Text("Durak").font(.system(size: 54, weight: .heavy, design: .serif)).foregroundColor(.white)
                Text("vs Monte Carlo AI").foregroundColor(.white.opacity(0.8))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Opponents").foregroundColor(.white).font(.headline)
                    Picker("", selection: $opponents) {
                        Text("1").tag(1); Text("2").tag(2); Text("3").tag(3)
                    }.pickerStyle(.segmented)
                    Text("Difficulty").foregroundColor(.white).font(.headline).padding(.top, 8)
                    Picker("", selection: $level) {
                        Text("Easy").tag(0); Text("Medium").tag(1); Text("Hard").tag(2)
                    }.pickerStyle(.segmented)
                }.padding(.horizontal, 30)
                Button {
                    onStart(opponents + 1, [0.15, 0.5, 0.9][level])
                } label: {
                    Text("Play").font(.title2.bold()).frame(width: 200, height: 52)
                        .background(Color.yellow).foregroundColor(.black).cornerRadius(26)
                }
                Button("Sorting Test") { showBench = true }.foregroundColor(.white.opacity(0.85))
            }

            .overlay(alignment: .topTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 27, weight: .medium))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.18), in: Circle())
                }
                .padding(.top, 12)
                .padding(.trailing, 18)
                .accessibilityLabel("Game information")
            }
        }
        .sheet(isPresented: $showInfo) { InfoView() }
        .sheet(isPresented: $showBench) {
            VStack(spacing: 16) {
                Text("Merge Sort vs Counting Sort").font(.headline)
                ScrollView { Text(benchText).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) }
                Button(running ? "Testing…" : "Run Test") {
                    running = true
                    Task {
                        let t = await Task.detached { Bench.run() }.value
                        benchText = t
                        running = false
                    }
                }.disabled(running)
            }.padding()
        }
    }
}

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("How to Play").font(.title.bold())
                    Text("Durak is a card game for 2–4 players. The goal is to get rid of all your cards. The last player left holding cards is the Durak.")
                    rule("1. Deal", "Each player starts with 6 cards. The remaining cards form the draw pile. One card is revealed to show the trump suit.")
                    rule("2. Attack", "The attacker plays a card. The defender must beat it with a higher card of the same suit or any trump card.")
                    rule("3. Add cards", "The attacker may add cards matching a rank already on the table. The number of attacking cards cannot exceed the defender’s hand.")
                    rule("4. Take or defend", "If you cannot or do not want to defend, choose Take and collect all cards on the table. If every attack is beaten, choose Done.")
                    rule("5. Refill", "After a round, players draw back up to 6 cards while cards remain in the deck. The attacker draws first and the defender last.")
                    rule("6. Win", "When the deck is empty, players who run out of cards leave the game. The last player with cards loses.")
                    Divider().overlay(Color.white.opacity(0.25))
                    Text("Developers").font(.title2.bold())
                    Text("Alan and Shoxrux").font(.title3).foregroundColor(.yellow)
                }
                .foregroundColor(.white)
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Table.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private func rule(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).foregroundColor(.yellow)
            Text(detail).font(.body)
        }
    }
}

enum Table {
    static var background: some View {
        RadialGradient(colors: [Color(red: 0.10, green: 0.45, blue: 0.25), Color(red: 0.03, green: 0.20, blue: 0.11)],
                       center: .center, startRadius: 20, endRadius: 650).ignoresSafeArea()
    }
}

// MARK: - Card view
struct CardView: View {
    var card: Card? = nil
    var width: CGFloat = 62
    var dimmed = false

    var body: some View {
        let r = width * 0.12
        ZStack {
            if let c = card {
                RoundedRectangle(cornerRadius: r).fill(Color.white)
                VStack {
                    HStack {
                        VStack(spacing: -2) {
                            Text(c.rankLabel).font(.system(size: width * 0.30, weight: .bold))
                            Text(c.suit.symbol).font(.system(size: width * 0.26))
                        }
                        Spacer()
                    }
                    Spacer()
                }.padding(width * 0.07)
                Text(c.suit.symbol).font(.system(size: width * 0.55))
            } else {
                RoundedRectangle(cornerRadius: r)
                    .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.25, blue: 0.65), Color(red: 0.08, green: 0.12, blue: 0.40)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: r * 0.7).stroke(Color.white.opacity(0.6), lineWidth: 2).padding(4)
            }
        }
        .foregroundColor(card?.suit.isRed == true ? Color(red: 0.82, green: 0.10, blue: 0.10) : .black)
        .frame(width: width, height: width * 1.45)
        .overlay(RoundedRectangle(cornerRadius: r).stroke(Color.black.opacity(0.35), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: r).fill(Color.black.opacity(dimmed ? 0.35 : 0)))
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

// MARK: - Game view
struct GameView: View {
    @StateObject private var vm: GameVM
    var onExit: () -> Void

    init(players: Int, budget: Double, onExit: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: GameVM(players: players, budget: budget))
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            Table.background
            VStack(spacing: 8) {
                topBar
                opponents
                Spacer(minLength: 0)
                tableArea
                Spacer(minLength: 0)
                Text(vm.thinking ? "\(vm.message) · AI is thinking…" : vm.message)
                    .font(.subheadline).foregroundColor(.white.opacity(0.9)).lineLimit(1)
                actionButtons
                handView
            }
            .padding(.horizontal, 8)
            if vm.state.over { overlay }
        }
    }

    private var topBar: some View {
        HStack {
            Button("‹ Menu") { onExit() }.foregroundColor(.white)
            Spacer()
            Text("Trump: \(vm.state.trump.symbol)")
                .font(.headline).foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.3)))
        }.padding(.top, 4)
    }

    private var opponents: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(1..<vm.state.playerCount, id: \.self) { p in
                let st = vm.state
                let out = st.hands[p].isEmpty && st.deck.isEmpty
                let active = st.actor == p
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.35)).frame(width: 46, height: 46)
                        Text(out ? "✓" : "🤖").font(.title2)
                        Circle().stroke(active ? Color.yellow : Color.clear, lineWidth: 3).frame(width: 46, height: 46)
                    }
                    Text("AI \(p)\(st.over ? "" : (st.attacker == p ? " ⚔️" : (st.defender == p ? " 🛡️" : "")))")
                        .font(.caption.bold()).foregroundColor(.white)
                    HStack(spacing: -20) {
                        ForEach(0..<min(st.hands[p].count, 8), id: \.self) { _ in CardView(width: 30) }
                    }.frame(height: 44)
                    Text("\(st.hands[p].count)").font(.caption2.bold()).foregroundColor(.white.opacity(0.85))
                }
            }
        }
    }

    private var tableArea: some View {
        HStack(alignment: .center, spacing: 10) {
            deckView
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 8) {
                ForEach(0..<vm.state.table.count, id: \.self) { i in
                    let p = vm.state.table[i]
                    ZStack(alignment: .topLeading) {
                        CardView(card: p.attack, width: 56)
                        if let d = p.defense {
                            CardView(card: d, width: 56).offset(x: 16, y: 18).rotationEffect(.degrees(6))
                        }
                    }.frame(width: 84, height: 104, alignment: .topLeading)
                }
            }
        }
    }

    private var deckView: some View {
        ZStack {
            if vm.state.deck.count > 0 {
                CardView(card: vm.state.deck[0], width: 48).rotationEffect(.degrees(90)).offset(x: 16)
                if vm.state.deck.count > 1 { CardView(width: 48) }
                Text("\(vm.state.deck.count)").font(.caption.bold()).foregroundColor(.white)
                    .padding(6).background(Circle().fill(Color.black.opacity(0.65)))
            } else {
                Text(vm.state.trump.symbol).font(.system(size: 44)).foregroundColor(.white.opacity(0.9))
            }
        }.frame(width: 96, height: 100)
    }

    private var actionButtons: some View {
        let moves = vm.state.actor == 0 ? vm.state.legalMoves() : []
        return HStack(spacing: 10) {
            Button { vm.undo() } label: { pill("↩︎ Undo", Color.white.opacity(0.85)) }.disabled(!vm.canUndo)
            if moves.contains(.take) {
                Button { vm.humanTake() } label: { pill("Take", Color.orange) }
            }
            if moves.contains(.pass) {
                Button { vm.humanPass() } label: { pill(vm.state.defenderTaking ? "Let take" : "Done", Color.yellow) }
            }
        }.frame(height: 40)
    }

    private func pill(_ t: String, _ c: Color) -> some View {
        Text(t).font(.headline).foregroundColor(.black)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(Capsule().fill(c))
    }

    private var handView: some View {
        let st = vm.state
        var h = st.hands[0]
        Sorts.mergeSort(&h, key: { st.sortKey($0) })
        let cards = h.toArray()
                return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -22) {
                ForEach(cards, id: \.id) { c in
                    CardView(card: c, width: 64)
                        .onTapGesture { vm.humanPlay(c) }
                }
            }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 6)
        }.frame(height: 130)
    }

    private var overlay: some View {
        let d = vm.state.durak
        let title = d == 0 ? "You are the Durak 🤡" : (d == nil ? "Draw 🤝" : "You win! 🎉")
        return ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(title).font(.title.bold()).foregroundColor(.white)
                if let d = d, d != 0 { Text("Durak: AI \(d)").foregroundColor(.white.opacity(0.85)) }
                Button { vm.restart() } label: { pill("Play Again", .yellow) }
                Button { onExit() } label: { pill("Main Menu", .white) }
            }
        }
    }
}
