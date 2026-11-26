import SwiftUI

// MARK: - Root + menu
struct GameConfig: Identifiable {
    let id = UUID()
    let players: Int
    let budget: Double
    let cheaterMode: Bool
    let playerTimeout: Int
    let deckSize: Int
    let transferEnabled: Bool
    let drawOnMoveLimit: Bool
    let throwInScope: ThrowInScope
}

struct RootView: View {
    @State private var config: GameConfig? = nil
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView { withAnimation(.easeInOut(duration: 0.38)) { showSplash = false } }
                    .transition(.opacity)
            } else if let c = config {
                GameView(
                    players: c.players,
                    budget: c.budget,
                    cheaterMode: c.cheaterMode,
                    playerTimeout: c.playerTimeout,
                    deckSize: c.deckSize,
                    transferEnabled: c.transferEnabled,
                    drawOnMoveLimit: c.drawOnMoveLimit,
                    throwInScope: c.throwInScope,
                    onExit: {
                        withAnimation(.easeInOut(duration: 0.36)) { config = nil }
                    }
                )
                .id(c.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                MenuView(onStart: { p, b, cheat, timeout, deck, transferMode, drawOnMoveLimit, throwInScope in
                    withAnimation(.easeInOut(duration: 0.36)) {
                        config = GameConfig(players: p, budget: b, cheaterMode: cheat, playerTimeout: timeout, deckSize: deck, transferEnabled: transferMode, drawOnMoveLimit: drawOnMoveLimit, throwInScope: throwInScope)
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.36), value: showSplash)
        .preferredColorScheme(.dark)
    }
}

struct MenuView: View {
    var onStart: (Int, Double, Bool, Int, Int, Bool, Bool, ThrowInScope) -> Void
    @State private var opponents = 2
    @State private var level = 1
    @State private var showBench = false
    @State private var benchText = ""
    @State private var running = false
    @State private var showInfo = false
    @State private var cheaterMode = false
    @State private var timeout = 30
    @State private var deck = 36
    @State private var transferMode = true
    @State private var drawOnMoveLimit = true
    @State private var throwInScope: ThrowInScope = .neighbors

    var body: some View {
        ZStack {
            Table.background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Color.clear.frame(height: 145).overlay {
                        VStack(spacing: 2) {
                            ZStack {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Palette.gold)
                                    .offset(y: -37)
                                Text("♠")
                                    .font(.system(size: 42, weight: .black))
                                    .foregroundStyle(Palette.gold)
                                    .frame(width: 70, height: 70)
                                    .background(Circle().fill(Color.black.opacity(0.8)))
                                    .overlay(Circle().stroke(Palette.gold, lineWidth: 3))
                                    .shadow(color: Palette.gold.opacity(0.75), radius: 18)
                            }
                            Text("DURAK")
                                .font(.system(size: 43, weight: .black, design: .serif))
                                .tracking(3)
                                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.65, green: 0.68, blue: 0.78)], startPoint: .top, endPoint: .bottom))
                                .shadow(color: .white.opacity(0.25), radius: 8)
                            Text("| MONTE CARLO AI BOTS |")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(3)
                                .foregroundColor(Palette.gold)
                        }
                    }

                    VStack(alignment: .leading, spacing: 17) {
                        HStack {
                            Image(systemName: "slider.horizontal.3").foregroundColor(Palette.gold)
                            Text("GAME SETTINGS").font(.system(size: 19, weight: .bold)).tracking(1)
                                .foregroundColor(.white)
                            Spacer()
                            Button { showInfo = true } label: {
                                Image(systemName: "info.circle").font(.system(size: 22)).foregroundColor(.white)
                            }
                        }
                        settingLabel("Opponents")
                        Picker("Opponents", selection: $opponents) {
                            Text("1").tag(1); Text("2").tag(2); Text("3").tag(3)
                        }.pickerStyle(.segmented)
                        settingLabel("Difficulty")
                        Picker("Difficulty", selection: $level) {
                            Text("Easy").tag(0); Text("Medium").tag(1); Text("Hard").tag(2)
                        }.pickerStyle(.segmented)

                        Divider().overlay(Color.white.opacity(0.12))
                        toggleRow("Cheater bots", subtitle: "Occasional hidden illegal moves", value: $cheaterMode)
                        Divider().overlay(Color.white.opacity(0.12))
                        menuRow("Deck size") {
                            Picker("Deck size", selection: $deck) {
                                Text("24 cards").tag(24); Text("36 cards").tag(36)
                            }.pickerStyle(.menu).tint(Palette.gold)
                        }
                        Divider().overlay(Color.white.opacity(0.12))
                        toggleRow("Transfer Durak", subtitle: "Allow transferring an attack", value: $transferMode)
                        Divider().overlay(Color.white.opacity(0.12))
                        menuRow("Attackers") {
                            Picker("Attackers", selection: $throwInScope) {
                                Text("Neighbors").tag(ThrowInScope.neighbors); Text("All players").tag(ThrowInScope.all)
                            }.pickerStyle(.menu).tint(Palette.gold)
                        }
                        Divider().overlay(Color.white.opacity(0.12))
                        menuRow("Ending rule") {
                            Picker("Ending rule", selection: $drawOnMoveLimit) {
                                Text("Draw on stalemate").tag(true); Text("Classic").tag(false)
                            }.pickerStyle(.menu).tint(Palette.gold)
                        }
                        Divider().overlay(Color.white.opacity(0.12))
                        menuRow("Your turn limit") {
                            Picker("Turn limit", selection: $timeout) {
                                Text("15 sec").tag(15); Text("30 sec").tag(30); Text("60 sec").tag(60)
                            }.pickerStyle(.menu).tint(Palette.gold)
                        }
                    }
                    .padding(20)
                    .background(Glass.panel, in: RoundedRectangle(cornerRadius: 27))
                    .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.white.opacity(0.13), lineWidth: 1))
                    .shadow(color: .black.opacity(0.45), radius: 24, y: 12)

                    Button {
                        onStart(opponents + 1, [0.15, 0.5, 0.9][level], cheaterMode, timeout, deck, transferMode, drawOnMoveLimit, throwInScope)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "suit.spade.fill").font(.title2)
                            Text("START GAME").font(.system(size: 20, weight: .black)).tracking(1)
                        }
                        .foregroundColor(Color(red: 0.12, green: 0.10, blue: 0.08))
                        .frame(maxWidth: .infinity).frame(height: 62)
                        .background(LinearGradient(colors: [Color(red: 1.0, green: 0.88, blue: 0.55), Color(red: 0.88, green: 0.57, blue: 0.17)], startPoint: .top, endPoint: .bottom), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1.2))
                        .shadow(color: Palette.gold.opacity(0.42), radius: 18, y: 5)
                    }
                    Button("Sorting Test") { showBench = true }
                        .font(.footnote.weight(.medium)).foregroundColor(.white.opacity(0.65))
                }
                .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 28)
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
            }.padding().preferredColorScheme(.dark)
        }
        .preferredColorScheme(.dark)
    }

    private func settingLabel(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white.opacity(0.92))
    }

    private func menuRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).foregroundColor(.white).font(.system(size: 15, weight: .medium))
            Spacer()
            content()
        }
    }

    private func toggleRow(_ title: String, subtitle: String, value: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundColor(.white).font(.system(size: 15, weight: .medium))
                Text(subtitle).foregroundColor(.white.opacity(0.48)).font(.caption)
            }
            Spacer()
            Toggle(title, isOn: value).labelsHidden().tint(Palette.gold)
        }
    }
}

struct SplashView: View {
    var onContinue: () -> Void
    @State private var visible = false

    var body: some View {
        ZStack {
            Table.background
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.white).frame(width: 82, height: 118).rotationEffect(.degrees(-12)).offset(x: -18)
                    RoundedRectangle(cornerRadius: 14).fill(Color.white).frame(width: 82, height: 118).overlay {
                        VStack(spacing: 4) { Text("A").font(.system(size: 30, weight: .black)); Text("♠").font(.system(size: 34)) }
                            .foregroundColor(.black)
                    }.rotationEffect(.degrees(10)).offset(x: 18)
                }.frame(height: 140)
                Text("DURAK").font(.system(size: 48, weight: .black, design: .serif)).tracking(5).foregroundColor(.white)
                Text("MONTE CARLO AI BOTS").font(.caption.weight(.semibold)).tracking(3).foregroundColor(Palette.gold)
            }
            .opacity(visible ? 1 : 0.35).scaleEffect(visible ? 1 : 0.94)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: onContinue)
        }
    }
}

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("What is Durak?").font(.title.bold())
                    Text("Durak is a traditional card game for 2–4 players. You are not trying to collect points: your goal is to get rid of every card in your hand. The last player who still has cards when the game ends is the Durak, which means “the fool.”")
                    rule("The cards", "Choose a 24-card deck (9 through Ace) or a 36-card deck (6 through Ace). Each player starts with six cards.")
                    rule("Trump suit", "A trump card beats any non-trump card. To beat a trump card, you must play a higher card of the same trump suit.")
                    rule("1. Attack", "The attacker places one card on the table. The defender must cover it with a higher card of the same suit or a trump card.")
                    rule("2. Add cards", "Depending on the selected setting, the neighboring players or all players except the defender may add cards whose rank matches a rank already on the table. The total number of attacking cards cannot exceed the defender’s hand size at the start of the round.")
                    rule("Transfer mode", "When Transfer Durak is enabled, a defender may pass the attack to the next player by playing a card of the same rank, if that player has enough cards to defend.")
                    rule("Cheater bots", "In Cheater mode, bots sometimes make a hidden illegal throw-in without seeing anyone else’s hand. Tap the suspicious card on the table to call it out. The bot must then continue with a legal move.")
                    rule("3. Defend or take", "Cover every attacking card to defend successfully. If you cannot or do not want to defend, choose Take and collect all cards on the table.")
                    rule("4. Finish the round", "When every attack is covered, the attacker chooses Done. If the defender takes the cards, the next player after the defender starts the next attack.")
                    rule("5. Draw cards", "After a round, players draw back up to six cards while the deck lasts. The attacker draws first and the defender draws last.")
                    rule("6. Win or draw", "When the deck is empty, players who get rid of all their cards leave the game. The last player holding cards loses. In Draw on stalemate mode, a game that reaches 1,000 moves ends in a draw; Classic mode assigns the loss to the player holding the most cards.")
                    Divider().overlay(Color.white.opacity(0.25))
                    Text("Developers").font(.title2.bold())
                    developerCard(name: "Alan", id: "250444", telegram: "tg://user?id=6496824057", instagram: "https://www.instagram.com/t1berss?dmpr=MXBkaHdvMDRyZGk2Yg%3D%3D&utm_source=qr")
                    developerCard(name: "Shohrux", id: "250272", telegram: "https://t.me/shohaa_www", instagram: "https://www.instagram.com/shohaa.www?jplx=MXQ0ODlyODhscXdwNg==")
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

    private func developerCard(name: String, id: String, telegram: String, instagram: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name).font(.title3.weight(.semibold)).foregroundColor(Palette.gold)
            Text("Student ID: \(id)").font(.subheadline).foregroundColor(.white.opacity(0.78))
            HStack(spacing: 12) {
                socialLink(title: "Telegram", symbol: "paperplane.fill", address: telegram)
                socialLink(title: "Instagram", symbol: "camera.fill", address: instagram)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Glass.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.13), lineWidth: 1))
    }

    private func socialLink(title: String, symbol: String, address: String) -> some View {
        Group {
            if let url = URL(string: address) {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        socialIcon(for: title)
                            .frame(width: 23, height: 23)
                        Text(title).font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.09), in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func socialIcon(for title: String) -> some View {
        if title == "Telegram" {
            ZStack {
                Circle().fill(Color(red: 0.13, green: 0.65, blue: 0.91))
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -0.5, y: 0.5)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.72, blue: 0.28),
                            Color(red: 0.91, green: 0.25, blue: 0.43),
                            Color(red: 0.48, green: 0.25, blue: 0.72)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ))
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: 1.7)
                    .frame(width: 13, height: 13)
                Circle().stroke(Color.white, lineWidth: 1.7)
                    .frame(width: 5, height: 5)
                Circle().fill(Color.white)
                    .frame(width: 2, height: 2)
                    .offset(x: 5, y: -5)
            }
        }
    }

    private func rule(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).foregroundColor(.yellow)
            Text(detail).font(.body)
        }
    }
}

enum Palette {
    static let gold = Color(red: 1.0, green: 0.76, blue: 0.30)
    static let paleGold = Color(red: 1.0, green: 0.89, blue: 0.62)
    static let navy = Color(red: 0.018, green: 0.025, blue: 0.055)
}
enum Glass {
    static var panel: some ShapeStyle {
        LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.19).opacity(0.96), Color(red: 0.025, green: 0.03, blue: 0.07).opacity(0.98)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
enum Table {
    static var background: some View {
        ZStack {
            Palette.navy
            RadialGradient(colors: [Color(red: 0.13, green: 0.15, blue: 0.24).opacity(0.78), .clear], center: .top, startRadius: 20, endRadius: 520)
            GeometryReader { geo in
                ForEach(0..<7, id: \.self) { i in
                    Image(systemName: "suit.spade.fill")
                        .font(.system(size: CGFloat(70 + (i % 3) * 25)))
                        .foregroundColor(.white.opacity(0.025))
                        .position(x: CGFloat((i * 113 + 35) % max(Int(geo.size.width), 1)), y: CGFloat((i * 191 + 80) % max(Int(geo.size.height), 1)))
                }
                Path { p in
                    p.move(to: CGPoint(x: -20, y: geo.size.height * 0.22))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.34, y: -20))
                    p.move(to: CGPoint(x: -20, y: geo.size.height * 0.72))
                    p.addLine(to: CGPoint(x: geo.size.width + 20, y: geo.size.height * 0.48))
                    p.move(to: CGPoint(x: geo.size.width * 0.52, y: geo.size.height + 20))
                    p.addLine(to: CGPoint(x: geo.size.width + 20, y: geo.size.height * 0.82))
                }.stroke(LinearGradient(colors: [.clear, Palette.gold.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing), lineWidth: 1.1)
            }
        }.ignoresSafeArea()
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
                    .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.29, blue: 0.76), Color(red: 0.025, green: 0.07, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: r * 0.7).fill(
                    LinearGradient(colors: [Color.white.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                ).padding(7)
                RoundedRectangle(cornerRadius: r * 0.7).stroke(Color.white.opacity(0.78), lineWidth: 1.8).padding(4)
                Image(systemName: "suit.spade.fill").font(.system(size: width * 0.38)).foregroundColor(.white.opacity(0.34))
            }
        }
        .foregroundColor(card?.suit.isRed == true ? Color(red: 0.82, green: 0.10, blue: 0.10) : .black)
        .frame(width: width, height: width * 1.45)
        .overlay(RoundedRectangle(cornerRadius: r).stroke(card == nil ? Color(red: 0.58, green: 0.72, blue: 1.0) : Color.black.opacity(0.18), lineWidth: card == nil ? 2 : 1))
        .shadow(color: card == nil ? Color.blue.opacity(0.42) : .clear, radius: 7)
        .overlay(RoundedRectangle(cornerRadius: r).fill(Color.black.opacity(dimmed ? 0.35 : 0)))
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

// Pull a card upward onto the table, like playing with physical cards.
private struct DraggableHandCard: View {
    let card: Card
    let width: CGFloat
    let isFloating: Bool
    let isWheelSelected: Bool
    let wheelOffset: CGFloat
    let wheelRotation: Double

    var body: some View {
        CardView(card: card, width: width)
            .opacity(isFloating ? 0.08 : 1)
            .offset(y: isFloating ? -22 : (isWheelSelected ? -13 : wheelOffset))
            .rotationEffect(.degrees(isFloating ? 0 : wheelRotation))
            .scaleEffect(isFloating ? 1.08 : (isWheelSelected ? 1.045 : 1))
            .shadow(color: isFloating || isWheelSelected ? Palette.gold.opacity(0.42) : .clear, radius: isFloating ? 13 : 7, y: 5)
            .contentShape(Rectangle())
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.72), value: isFloating)
            .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.76), value: isWheelSelected)
            .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.76), value: wheelOffset)
            .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.76), value: wheelRotation)
    }
}
private struct TransferDropTarget: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9).fill(Color.clear)
            RoundedRectangle(cornerRadius: 9).stroke(Palette.gold.opacity(0.98), lineWidth: 3)
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.78), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                .padding(5)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 29, weight: .black))
                .foregroundColor(Palette.gold)
                .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            Text("TRANSFER")
                .font(.system(size: 7, weight: .black, design: .rounded))
                .tracking(0.7)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.58), in: Capsule())
                .offset(y: 27)
        }
        .frame(width: 64, height: 104)
        .shadow(color: Palette.gold.opacity(0.3), radius: 5, y: 2)
        .allowsHitTesting(false)
    }
}

// MARK: - Game view
struct GameView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var vm: GameVM
    @State private var tableDropFrame: CGRect = .zero
    @State private var defendDropFrame: CGRect = .zero
    @State private var transferDropFrame: CGRect = .zero
    @State private var handFrame: CGRect = .zero
    @State private var draggedCard: Card? = nil
    @State private var candidateCard: Card? = nil
    @State private var isSelectionLocked = false
    @State private var selectionLockID = UUID()
    @State private var lastSelectionX: CGFloat = .zero
    @State private var selectionStartPoint: CGPoint = .zero
    @State private var dragPoint: CGPoint = .zero
    @State private var hasMovedAboveHand = false
    @State private var flyingCard: Card? = nil
    @State private var flightPosition: CGPoint = .zero
    @State private var flightID = UUID()
    var onExit: () -> Void

    init(players: Int, budget: Double, cheaterMode: Bool, playerTimeout: Int, deckSize: Int, transferEnabled: Bool, drawOnMoveLimit: Bool, throwInScope: ThrowInScope, onExit: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: GameVM(players: players, budget: budget, cheaterMode: cheaterMode, playerTimeout: playerTimeout, deckSize: deckSize, transferEnabled: transferEnabled, drawOnMoveLimit: drawOnMoveLimit, throwInScope: throwInScope))
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            Table.background
            Group {
                if verticalSizeClass == .compact {
                    VStack(spacing: 3) {
                        topBar
                            .frame(height: 42)
                        opponents
                            .frame(height: 80, alignment: .top)
                        Spacer(minLength: 0)
                        tableArea
                            .frame(height: 100)
                            .background(tableDropGeometry)
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            statusPill
                                .frame(maxWidth: .infinity)
                                .layoutPriority(0)
                            actionButtons
                                .frame(width: 224, height: 40)
                                .layoutPriority(1)
                        }
                        handView(isLandscape: true)
                    }
                } else {
                    VStack(spacing: 8) {
                        topBar
                        opponents
                        Spacer(minLength: 0)
                        tableArea.background(tableDropGeometry)
                        Spacer(minLength: 0)
                        statusPill
                        actionButtons
                        handView(isLandscape: false)
                    }
                }
            }
            .padding(.horizontal, 8)
            if isSelectionLocked, let card = draggedCard {
                CardView(card: card, width: 68)
                    .scaleEffect(1.08)
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                    .position(dragPoint)
                    .transaction { $0.animation = nil }
                    .allowsHitTesting(false)
                    .zIndex(1000)
            }
            if let card = flyingCard {
                CardView(card: card, width: 68)
                    .scaleEffect(1.06)
                    .shadow(color: Palette.gold.opacity(0.32), radius: 12, y: 6)
                    .position(flightPosition)
                    .allowsHitTesting(false)
                    .zIndex(1100)
            }
            if vm.state.over { overlay }
        }
        .coordinateSpace(name: "gameBoard")
    }

    private var tableDropGeometry: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    tableDropFrame = proxy.frame(in: .named("gameBoard")).insetBy(dx: -55, dy: -75)
                }
                .onChange(of: proxy.size) { _ in
                    tableDropFrame = proxy.frame(in: .named("gameBoard")).insetBy(dx: -55, dy: -75)
                }
        }
    }

    private var statusPill: some View {
        Text(vm.state.actor == 0 && !vm.state.over ? "YOUR TURN  ·  \(vm.remainingTime)s" : (vm.thinking ? "BOT IS THINKING…" : vm.message.uppercased()))
            .font(.system(size: verticalSizeClass == .compact ? 9 : 13, weight: .bold)).tracking(verticalSizeClass == .compact ? 0.3 : 1)
            .foregroundColor(Palette.paleGold).lineLimit(1).minimumScaleFactor(0.72)
            .padding(.horizontal, 16).padding(.vertical, verticalSizeClass == .compact ? 6 : 8)
            .background(Glass.panel, in: Capsule())
            .overlay(Capsule().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
    }

    private var topBar: some View {
        HStack {
            Button { onExit() } label: {
                Label("Menu", systemImage: "line.3.horizontal")
                    .font(.system(size: verticalSizeClass == .compact ? 11 : 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, verticalSizeClass == .compact ? 10 : 14)
                    .padding(.vertical, verticalSizeClass == .compact ? 7 : 10)
                    .background(Glass.panel, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
            }
            Spacer()
            HStack(spacing: 7) {
                Text("TRUMP").font(.caption2.weight(.black)).tracking(1).foregroundColor(.white.opacity(0.65))
                Text(vm.state.trump.symbol).font(.title2.bold())
                    .foregroundColor(vm.state.trump.isRed ? .red : Palette.paleGold)
            }
            .padding(.horizontal, 15).padding(.vertical, 8)
            .background(Glass.panel, in: Capsule())
            .overlay(Capsule().stroke(Palette.gold.opacity(0.65), lineWidth: 1))
        }
        .padding(.top, verticalSizeClass == .compact ? 0 : 7)
    }

    private var opponents: some View {
        let compactLayout = verticalSizeClass == .compact
        let avatarSize: CGFloat = compactLayout ? 28 : 48
        let backWidth: CGFloat = compactLayout ? 19 : 30
        let backHeight: CGFloat = compactLayout ? 27 : 44
        return HStack(alignment: .top, spacing: compactLayout ? 22 : 14) {
            ForEach(1..<vm.state.playerCount, id: \.self) { p in
                let st = vm.state
                let out = st.hands[p].isEmpty && st.deck.isEmpty
                let active = st.actor == p
                VStack(spacing: compactLayout ? 1 : 4) {
                    ZStack {
                        Circle().fill(Glass.panel).frame(width: avatarSize, height: avatarSize)
                        Text(out ? "✓" : "🤖").font(compactLayout ? .system(size: 16) : .title2)
                        Circle().stroke(active ? Palette.gold : Color.white.opacity(0.18), lineWidth: active ? 2.5 : 1)
                            .frame(width: avatarSize, height: avatarSize)
                    }.shadow(color: active ? Palette.gold.opacity(0.4) : .clear, radius: 9)
                    Text("AI \(p)\(st.over ? "" : (st.attacker == p ? " ⚔️" : (st.defender == p ? " 🛡️" : "")))")
                        .font(.system(size: compactLayout ? 9 : 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                    HStack(spacing: compactLayout ? -14 : -20) {
                        ForEach(0..<min(st.hands[p].count, 8), id: \.self) { _ in
                            CardView(width: backWidth).frame(height: backHeight)
                        }
                    }.frame(height: backHeight)
                    Text("\(st.hands[p].count)")
                        .font(.system(size: compactLayout ? 8 : 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                }
                .frame(minWidth: compactLayout ? 62 : 76)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: compactLayout ? 78 : nil, alignment: .top)
    }

    private func updatePairDropFrames(index: Int, frame: CGRect) {
        guard index == vm.state.firstUndefended else { return }
        defendDropFrame = frame.insetBy(dx: -8, dy: -8)
        transferDropFrame = CGRect(
            x: frame.maxX + 34,
            y: frame.minY,
            width: 64,
            height: 104
        )
    }

    private var tableArea: some View {
        HStack(alignment: .center, spacing: 10) {
            deckView
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(64), spacing: 2), count: 3), spacing: 8) {
                ForEach(0..<vm.state.table.count, id: \.self) { i in
                    let p = vm.state.table[i]
                    ZStack(alignment: .topLeading) {
                        CardView(card: p.attack, width: 56)
                        if let d = p.defense {
                            CardView(card: d, width: 56).offset(x: 16, y: 18).rotationEffect(.degrees(6))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { vm.challengeCheat(at: i) }
                    .frame(width: 64, height: 104, alignment: .topLeading)
                    .overlay(alignment: .trailing) {
                        if i == vm.state.firstUndefended && shouldShowTransferTarget {
                            TransferDropTarget()
                                .frame(width: 64, height: 104)
                                .offset(x: 66)
                        }
                    }
                    .background(GeometryReader { pairProxy in
                        Color.clear
                            .onAppear { updatePairDropFrames(index: i, frame: pairProxy.frame(in: .named("gameBoard"))) }
                            .onChange(of: vm.state.firstUndefended) { _ in
                                updatePairDropFrames(index: i, frame: pairProxy.frame(in: .named("gameBoard")))
                            }
                            .onChange(of: vm.state.table.count) { _ in
                                updatePairDropFrames(index: i, frame: pairProxy.frame(in: .named("gameBoard")))
                            }
                    })
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var shouldShowTransferTarget: Bool {
        // Keep the transfer cue visible whenever Transfer Durak is enabled.
        // The move itself is still validated by GameState when the card is dropped.
        return vm.state.actor == 0 && !vm.state.defenderTaking && vm.state.transferEnabled && vm.state.firstUndefended >= 0
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
        return HStack(spacing: verticalSizeClass == .compact ? 5 : 10) {
            Button { vm.undo() } label: { pill("↩︎ Undo", Color.white.opacity(0.85)) }.disabled(!vm.canUndo)
            if moves.contains(.take) {
                Button { vm.humanTake() } label: { pill("Take", Color.orange) }
            }
            if moves.contains(.pass) {
                Button { vm.humanPass() } label: { pill(vm.state.defenderTaking ? "Let take" : "Done", Color.yellow) }
            }
        }
        .frame(height: verticalSizeClass == .compact ? 38 : 46)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func pill(_ t: String, _ c: Color) -> some View {
        Text(t.uppercased())
            .font(.system(size: verticalSizeClass == .compact ? 10 : 14, weight: .black))
            .tracking(verticalSizeClass == .compact ? 0 : 0.5)
            .lineLimit(1).minimumScaleFactor(0.72)
            .foregroundColor(.black)
            .padding(.horizontal, verticalSizeClass == .compact ? 9 : 19)
            .padding(.vertical, verticalSizeClass == .compact ? 7 : 10)
            .background(Capsule().fill(c))
            .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1))
            .shadow(color: c.opacity(0.28), radius: 7, y: 3)
    }

    private func handleHandDragChanged(_ point: CGPoint, cards: [Card], firstCenter: CGFloat, step: CGFloat) {
        guard !cards.isEmpty else { return }
        if isSelectionLocked && point.y < handFrame.minY + 18 {
            hasMovedAboveHand = true
        }
        let handSelectionZone = handFrame.insetBy(dx: 0, dy: -24)
        if handSelectionZone.contains(point) {
            let localX = point.x - handFrame.minX - 14
            let index = Int(round((localX - firstCenter) / max(step, 1)))
            let selected = cards[min(max(index, 0), cards.count - 1)]

            // With a small, non-overlapping hand, allow immediate pick-up and drag.
            if cards.count <= 7 {
                selectionLockID = UUID()
                candidateCard = selected
                draggedCard = selected
                isSelectionLocked = true
                hasMovedAboveHand = false
                dragPoint = point
                return
            }

            // With an overlapping hand, browse first and lock only after pausing.
            if candidateCard != selected {
                withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.76)) {
                    candidateCard = selected
                }
                lastSelectionX = point.x
                selectionStartPoint = point
                isSelectionLocked = false
                draggedCard = nil
                let lockID = UUID()
                selectionLockID = lockID
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    guard selectionLockID == lockID, candidateCard == selected else { return }
                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.72)) {
                        isSelectionLocked = true
                        draggedCard = selected
                        dragPoint = point
                    }
                }
            } else if !isSelectionLocked {
                // A clear upward movement means the player is dragging this card
                // toward the table, not browsing horizontally through the fan.
                if selectionStartPoint.y - point.y > 22 {
                    selectionLockID = UUID()
                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.72)) {
                        isSelectionLocked = true
                        draggedCard = candidateCard
                        hasMovedAboveHand = true
                        dragPoint = point
                    }
                    return
                }
                if abs(point.x - lastSelectionX) > 8 {
                    lastSelectionX = point.x
                    let lockID = UUID()
                    selectionLockID = lockID
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        guard selectionLockID == lockID, candidateCard == selected else { return }
                        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.72)) {
                            isSelectionLocked = true
                            draggedCard = selected
                            dragPoint = point
                        }
                    }
                }
            } else {
                dragPoint = point
            }
        } else if isSelectionLocked {
            dragPoint = point
        } else if candidateCard != nil, selectionStartPoint.y - point.y > 22 {
            // Keep the currently highlighted card fixed once the gesture leaves
            // the hand vertically; never recalculate its index during the drag.
            selectionLockID = UUID()
            withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.72)) {
                isSelectionLocked = true
                draggedCard = candidateCard
                dragPoint = point
            }
        }
    }

    private func handleHandDragEnded(_ point: CGPoint) {
        dragPoint = point
        if isSelectionLocked, let selected = draggedCard {
            let destination: CGPoint
            let play: () -> Void

            if transferDropFrame.contains(point) {
                destination = CGPoint(x: transferDropFrame.midX, y: transferDropFrame.midY)
                play = { vm.humanTransfer(selected) }
            } else if defendDropFrame.contains(point) {
                destination = CGPoint(x: defendDropFrame.midX, y: defendDropFrame.midY)
                play = { vm.humanDefend(selected) }
            } else if hasMovedAboveHand || point.y < handFrame.minY + 18 {
                // Register the upward release reliably in portrait layout.
                destination = CGPoint(x: tableDropFrame.midX, y: tableDropFrame.midY)
                play = { vm.humanPlay(selected) }
            } else {
                destination = point
                play = {}
            }

            if destination != point || point.y < handFrame.minY {
                let id = UUID()
                flightID = id
                flyingCard = selected
                flightPosition = point
                withAnimation(.easeInOut(duration: 0.24)) {
                    flightPosition = destination
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    guard flightID == id else { return }
                    play()
                    flyingCard = nil
                }
            }
        }
        selectionLockID = UUID()
        candidateCard = nil
        draggedCard = nil
        isSelectionLocked = false
        hasMovedAboveHand = false
    }

    private func handView(isLandscape: Bool) -> some View {
        let st = vm.state
        var sorted = st.hands[0]
        Sorts.mergeSort(&sorted, key: { st.sortKey($0) })
        let cards = sorted.toArray()

        return GeometryReader { proxy in
            let available = max(1, proxy.size.width - 28)
            let count = max(cards.count, 1)
            // In landscape, keep the cards visually spread because there is enough room.
            // The browsing/one-second lock behavior still depends only on card count.
            let needsWheelSelection = count > 7
            let groupedLayout = needsWheelSelection && !isLandscape
            let cardWidth = groupedLayout
                ? min(68, max(38, available / (CGFloat(count) * 0.58 + 0.42)))
                : min(68, max(38, (available - CGFloat(max(0, count - 1)) * 6) / CGFloat(count)))
            let spacing: CGFloat = groupedLayout ? -cardWidth * 0.42 : 6
            let step = cardWidth + spacing
            let totalWidth = cardWidth + CGFloat(max(0, count - 1)) * step
            let firstCenter = proxy.size.width / 2 - totalWidth / 2 + cardWidth / 2

            HStack(spacing: spacing) {
                ForEach(cards, id: \.id) { card in
                    let cardIndex = cards.firstIndex(of: card) ?? 0
                    let selectedIndex = candidateCard.flatMap { cards.firstIndex(of: $0) }
                    let distanceFromSelection = CGFloat(cardIndex - (selectedIndex ?? cardIndex))
                    DraggableHandCard(
                        card: card,
                        width: cardWidth,
                        isFloating: (isSelectionLocked && draggedCard == card) || flyingCard == card,
                        isWheelSelected: needsWheelSelection && !isSelectionLocked && candidateCard == card,
                        wheelOffset: needsWheelSelection && !isSelectionLocked ? min(8, abs(distanceFromSelection) * 2.2) : 0,
                        wheelRotation: needsWheelSelection && !isSelectionLocked ? Double(max(-1, min(1, distanceFromSelection))) * 4.5 : 0
                    )
                    .zIndex(isSelectionLocked && draggedCard == card ? 100 : (candidateCard == card ? 90 : Double(cardIndex)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("gameBoard"))
                    .onChanged { value in
                        handleHandDragChanged(value.location, cards: cards, firstCenter: firstCenter, step: step)
                    }
                    .onEnded { value in
                        handleHandDragEnded(value.location)
                    }
            )
            .onAppear { handFrame = proxy.frame(in: .named("gameBoard")) }
            .onChange(of: proxy.size) { _ in handFrame = proxy.frame(in: .named("gameBoard")) }
        }
        .frame(height: isLandscape ? 96 : 150)
        .background(Glass.panel, in: RoundedRectangle(cornerRadius: 27))
        .overlay(RoundedRectangle(cornerRadius: 27).stroke(Palette.gold.opacity(0.28), lineWidth: 1))
        .shadow(color: Palette.gold.opacity(0.08), radius: 15)
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
