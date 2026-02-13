//
//  AnagramStackClientApp.swift
//  AnagramStackClient
//
//  Main entry point for the iOS game client
//

import SwiftUI
import Combine

@main
struct AnagramStackClientApp: App {
    @StateObject private var appState = ClientAppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.loadDictionary()
                }
        }
    }
}

@MainActor
class ClientAppState: ObservableObject {
    @Published var isDictionaryLoaded = false
    @Published var loadingError: String?
    @Published var availableChains: [AnagramChain] = []
    @Published var isFetchingChains = false

    let chainService = ChainDownloadService.shared

    func loadDictionary() async {
        // Get the dictionary file path
        guard let path = Bundle.main.path(forResource: "dictionary", ofType: "txt") else {
            loadingError = "Dictionary file not found in bundle"
            return
        }

        do {
            try WordDictionary.shared.loadFromPath(path)
            isDictionaryLoaded = true
            print("✅ Dictionary loaded: \(WordDictionary.shared.count) words")

            // Fetch latest chains from GitHub
            await fetchChains()
        } catch {
            loadingError = "Failed to load dictionary: \(error.localizedDescription)"
        }
    }

    func fetchChains() async {
        print("🎯 fetchChains() called")
        isFetchingChains = true
        defer { isFetchingChains = false }

        // Fetch latest chains from GitHub (runs in background)
        print("📲 Calling chainService.fetchLatestChains()...")
        await chainService.fetchLatestChains()

        // Get all chains (bundled + downloaded)
        print("📚 Getting all chains...")
        availableChains = chainService.getAllChains()

        print("✅ Total chains available: \(availableChains.count)")
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: ClientAppState

    var body: some View {
        Group {
            if appState.isDictionaryLoaded {
                VStack {
                    if appState.isFetchingChains {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Fetching latest chains from GitHub...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }

                    ChainSelectionView(chains: appState.availableChains)
                }
            } else if let error = appState.loadingError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)

                    Text("Failed to Load Dictionary")
                        .font(.title)

                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading dictionary...")
                        .font(.headline)
                }
                .padding()
            }
        }
    }
}
