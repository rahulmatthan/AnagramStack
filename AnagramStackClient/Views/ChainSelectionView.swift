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

    var body: some View {
        NavigationStack {
            if chains.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(chains) { chain in
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
}

struct ChainRow: View {
    let chain: AnagramChain

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

            // Show saved progress if available
            if SavedProgress.hasSavedGame(for: chain.id) {
                Label("Continue", systemImage: "arrow.right.circle.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
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
