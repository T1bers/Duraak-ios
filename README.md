# Durak — iOS card game with a Monte Carlo opponent

A native SwiftUI version of the classic Durak card game. Play against one to three computer opponents.

## Game features

- English interface, including the game information screen.
- Info introduces Durak to first-time players, explains the rules, and credits the developers: Alan and Shoxrux.
- No playable-card highlighting or move suggestions: players choose their own cards.
- Three difficulty settings.
- Computer turns include a visible thinking pause.
- Monte Carlo move selection evaluates legal moves over sampled hidden-card distributions. Simulated games use a lightweight card-cost policy: prefer low cards, preserve trumps when possible, and avoid wasteful attacks.
- Undo, hand sorting, and a sorting benchmark.

## Data structures and algorithms

Custom implementations are in `DataStructures.swift` and `Algorithms.swift`:

- Circular queue — player turn order.
- Stack — discard pile and move history.
- Hash table with separate chaining — table ranks and seen-card tracking.
- Dynamic array — deck, hands, and table.
- Merge sort and counting sort — hand sorting and benchmark comparison.
- Fisher–Yates shuffle — deck shuffling.
- Monte Carlo move selection — computer decision-making.

## Build an unsigned IPA

1. Open the repository's Actions tab.
2. Run **Build unsigned IPA** (or merge changes into `main`).
3. Download the `Durak-unsigned-ipa` artifact.
4. Sign the IPA with your own signing method before installing it on an iPhone.

The project is generated with XcodeGen from `project.yml` and targets iOS 16.0 or later.

## Coursework compatibility note

The submitted Fall 2026 proposal lists **Python 3**, while this repository contains the **Swift/iOS implementation**. Confirm with the instructor whether the iOS version is accepted as the implementation or should be presented as a separate port. Do not describe this Swift app as a Python 3 submission.
