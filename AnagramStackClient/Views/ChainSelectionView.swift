//
//  ChainSelectionView.swift
//  AnagramStackClient
//
//  View for selecting an anagram chain to play
//

import SwiftUI
import Combine

struct ChainSelectionView: View {
    let chains: [AnagramChain]
    @EnvironmentObject var appState: ClientAppState
    @State private var selectedChain: AnagramChain?
    @State private var isRefreshing = false
    @AppStorage("com.anagramstack.savedProgressByChain") private var savedProgressBlob: Data = Data()

    private enum ChainPlayStatus {
        case inProgress
        case unplayed
        case completed
    }

    private var sortedChains: [AnagramChain] {
        // Reference persisted progress so this computed property re-evaluates
        // immediately when returning from a game.
        _ = savedProgressBlob
        return chains.sorted { lhs, rhs in
            let lhsStatus = status(for: lhs)
            let rhsStatus = status(for: rhs)

            let lhsRank = statusRank(lhsStatus)
            let rhsRank = statusRank(rhsStatus)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            return lhs.modifiedDate > rhs.modifiedDate
        }
    }

    var body: some View {
        NavigationStack {
            if chains.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sortedChains) { chain in
                        NavigationLink(value: chain) {
                            ChainRow(chain: chain)
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
                    ToolbarItem(placement: .navigationBarTrailing) {
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

    private func status(for chain: AnagramChain) -> ChainPlayStatus {
        if SavedProgress.isCompleted(for: chain) {
            return .completed
        }

        if let completionRatio = SavedProgress.completionRatio(for: chain),
           completionRatio > 0 {
            return .inProgress
        }

        return .unplayed
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
}

struct ChainRow: View {
    let chain: AnagramChain

    private var isCompleted: Bool {
        SavedProgress.isCompleted(for: chain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(chain.name)
                    .font(.headline)

                Spacer()

                DifficultyBadge(difficulty: chain.difficulty)
            }

            Text(chain.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if SavedProgress.isCompleted(for: chain) {
                Label(completedLabelText, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if let completionRatio = SavedProgress.completionRatio(for: chain),
                      completionRatio > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "In Progress (\(Int((completionRatio * 100).rounded()))%)",
                        systemImage: "arrow.right.circle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(.blue)

                    ProgressView(value: completionRatio)
                        .tint(.blue)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isCompleted ? 0.55 : 1.0)
    }

    private var completedLabelText: String {
        if let elapsed = SavedProgress.completedElapsedSeconds(for: chain) {
            return "Completed in \(SavedProgress.formatElapsedTime(elapsed))"
        }
        return "Completed"
    }
}

struct DifficultyBadge: View {
    let difficulty: AnagramChain.Difficulty

    var body: some View {
        Text(difficulty.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }

    private var color: Color {
        switch difficulty {
        case .easy:
            return .green
        case .medium:
            return .orange
        case .hard:
            return .red
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
