//
//  ChainSelectionView.swift
//  AnagramStackClient
//
//  View for selecting an anagram chain to play
//

import SwiftUI

struct ChainSelectionView: View {
    let chains: [AnagramChain]
    @EnvironmentObject var appState: ClientAppState
    @State private var isRefreshing = false
    @AppStorage("com.anagramstack.savedProgressByChain") private var savedProgressBlob: Data = Data()

    enum ChainPlayStatus {
        case inProgress
        case unplayed
        case completed
    }

    struct ChainDisplayItem: Identifiable {
        let chain: AnagramChain
        let status: ChainPlayStatus
        let completionRatio: Double?
        let completedLabelText: String?

        var id: UUID { chain.id }
    }

    private var chainDisplayItems: [ChainDisplayItem] {
        // Reference persisted progress so this computed property re-evaluates
        // immediately when returning from a game.
        _ = savedProgressBlob

        return chains.map { chain in
            let completionRatio = SavedProgress.completionRatio(for: chain)
            let isCompleted = SavedProgress.isCompleted(for: chain)
            let status: ChainPlayStatus

            if isCompleted {
                status = .completed
            } else if let completionRatio, completionRatio > 0 {
                status = .inProgress
            } else {
                status = .unplayed
            }

            let completedLabelText: String?
            if isCompleted {
                completedLabelText = completedText(for: chain)
            } else {
                completedLabelText = nil
            }

            return ChainDisplayItem(
                chain: chain,
                status: status,
                completionRatio: completionRatio,
                completedLabelText: completedLabelText
            )
        }
    }

    private var activeChains: [ChainDisplayItem] {
        chainDisplayItems
            .filter { $0.status != .completed }
            .sorted { lhs, rhs in
            let lhsRank = statusRank(lhs.status)
            let rhsRank = statusRank(rhs.status)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            return lhs.chain.modifiedDate > rhs.chain.modifiedDate
        }
    }

    private var completedChains: [ChainDisplayItem] {
        chainDisplayItems
            .filter { $0.status == .completed }
            .sorted { $0.chain.modifiedDate > $1.chain.modifiedDate }
    }

    var body: some View {
        NavigationStack {
            if chains.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(Array(activeChains.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: item.chain) {
                            ChainRow(item: item, animationDelay: Double(index) * 0.03)
                        }
                    }

                    if !completedChains.isEmpty {
                        Section("Completed") {
                            ForEach(Array(completedChains.enumerated()), id: \.element.id) { index, item in
                                NavigationLink(value: item.chain) {
                                    ChainRow(
                                        item: item,
                                        animationDelay: Double(activeChains.count + index) * 0.03
                                    )
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Anagram Stack")
                .navigationDestination(for: AnagramChain.self) { chain in
                    GameView(chain: chain)
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                }
                .refreshable {
                    await refreshChains()
                }
                .toolbar {
                    ToolbarItem(placement: refreshToolbarPlacement) {
                        Button {
                            Task {
                                await refreshChains()
                            }
                        } label: {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshing)
                    }
                }
            }
        }
    }

    #if os(iOS)
    private var refreshToolbarPlacement: ToolbarItemPlacement { .navigationBarTrailing }
    #else
    private var refreshToolbarPlacement: ToolbarItemPlacement { .automatic }
    #endif

    private func refreshChains() async {
        isRefreshing = true
        await appState.fetchChains()
        isRefreshing = false
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Chains Available",
            systemImage: "link.badge.plus",
            description: Text("Download chains to get started")
        )
    }

    private func statusRank(_ status: ChainPlayStatus) -> Int {
        switch status {
        case .inProgress:
            return 0
        case .unplayed:
            return 1
        case .completed:
            return 2
        }
    }

    private func completedText(for chain: AnagramChain) -> String {
        if let elapsed = SavedProgress.completedElapsedSeconds(for: chain) {
            if let hints = SavedProgress.completedHintsUsed(for: chain), hints > 0 {
                let hintWord = hints == 1 ? "hint" : "hints"
                return "Completed in \(SavedProgress.formatElapsedTime(elapsed)) • Using \(hints) \(hintWord)"
            }
            return "Completed in \(SavedProgress.formatElapsedTime(elapsed))"
        }
        return "Completed"
    }
}

struct ChainRow: View {
    let item: ChainSelectionView.ChainDisplayItem
    let animationDelay: Double
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.chain.name)
                    .font(.headline)
            }

            Text(item.chain.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if item.status == .completed {
                Label(item.completedLabelText ?? "Completed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(BrandPalette.success)
            } else if let completionRatio = item.completionRatio,
                      completionRatio > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "In Progress (\(Int((completionRatio * 100).rounded()))%)",
                        systemImage: "arrow.right.circle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(BrandPalette.primary)

                    ProgressView(value: completionRatio)
                        .tint(BrandPalette.primary)
                        .animation(.easeInOut(duration: 0.35), value: completionRatio)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity((item.status == .completed ? 0.55 : 1.0) * (hasAppeared ? 1.0 : 0.0))
        .offset(y: hasAppeared ? 0 : 6)
        .animation(.easeOut(duration: 0.28).delay(animationDelay), value: hasAppeared)
        .onAppear {
            hasAppeared = true
        }
    }
}


#Preview {
    ChainSelectionView(chains: [
        AnagramChain(
            name: "Easy Chain 1",
            description: "Perfect for beginners",
            difficulty: AnagramChain.Difficulty.easy,
            levels: []
        ),
        AnagramChain(
            name: "Medium Chain 1",
            description: "A good challenge",
            difficulty: AnagramChain.Difficulty.medium,
            levels: []
        )
    ])
}
