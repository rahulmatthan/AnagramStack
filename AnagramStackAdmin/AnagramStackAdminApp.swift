//
//  AnagramStackAdminApp.swift
//  AnagramStackAdmin
//
//  Main entry point for the macOS admin app
//

import SwiftUI
import Combine

@main
struct AnagramStackAdminApp: App {
    @StateObject private var appState = AdminAppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.loadDictionary()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chain") {
                    // Handled in ChainEditorView
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

@MainActor
class AdminAppState: ObservableObject {
    @Published var isDictionaryLoaded = false
    @Published var isGraphBuilt = false
    @Published var loadingError: String?
    @Published var loadingStatus: String = "Loading dictionary..."

    let wordGraph = WordGraph(dictionary: .shared)

    func loadDictionary() async {
        // Get the dictionary file path
        guard let path = Bundle.main.path(forResource: "dictionary", ofType: "txt") else {
            loadingError = "Dictionary file not found in bundle"
            return
        }

        do {
            // Load dictionary
            loadingStatus = "Loading dictionary..."
            try WordDictionary.shared.loadFromPath(path)
            isDictionaryLoaded = true
            print("✅ Dictionary loaded: \(WordDictionary.shared.count) words")

            // Build word graph
            loadingStatus = "Building word graph..."
            wordGraph.buildGraph()
            isGraphBuilt = true
            print("✅ Word graph ready!")

        } catch {
            loadingError = "Failed to load dictionary: \(error.localizedDescription)"
        }
    }

}

struct ContentView: View {
    @EnvironmentObject var appState: AdminAppState
    @State private var showingWizard = false

    var body: some View {
        Group {
            if appState.isGraphBuilt {
                SimpleAdminView(wordGraph: appState.wordGraph, showingWizard: $showingWizard)
            } else if let error = appState.loadingError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)

                    Text("Failed to Load")
                        .font(.title)

                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(appState.loadingStatus)
                        .font(.headline)
                }
                .padding()
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
    }
}
