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
        // Prefer broader dictionary; fall back to the smaller list.
        let path = Bundle.main.path(forResource: "words_alpha", ofType: "txt")
            ?? Bundle.main.path(forResource: "dictionary", ofType: "txt")

        guard let path else {
            loadingError = "Dictionary files not found in bundle"
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
    @State private var showingSplash = true

    var body: some View {
        if showingSplash {
            LaunchSplashView {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showingSplash = false
                }
            }
            .transition(.opacity)
        } else {
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
}

struct LaunchSplashView: View {
    let onContinue: () -> Void
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BrandPalette.backgroundTop,
                    BrandPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(BrandPalette.primary.opacity(0.14))
                        .frame(width: 130, height: 130)

                    Text("A8")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [BrandPalette.primary, BrandPalette.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(hasAppeared ? 1 : 0.92)
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: hasAppeared)

                VStack(spacing: 8) {
                    Text("Anagram Stack")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(BrandPalette.textPrimary)
                    Text("Build words. Unlock letters. Reach 8.")
                        .font(.subheadline)
                        .foregroundColor(BrandPalette.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Rearrange the letters to form a valid word.", systemImage: "checkmark.circle")
                    Label("Each success unlocks one new letter.", systemImage: "plus.circle")
                    Label("Use Help when stuck, and race the timer to 8 letters.", systemImage: "timer")
                }
                .font(.subheadline)
                .foregroundColor(BrandPalette.textPrimary)
                .padding(16)
                .frame(maxWidth: 520, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(BrandPalette.primary.opacity(0.12), lineWidth: 1)
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 8)
                .animation(.easeOut(duration: 0.3).delay(0.08), value: hasAppeared)

                Spacer()

                Button {
                    onContinue()
                } label: {
                    Text("Start Playing")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(BrandPalette.primary)
                        .cornerRadius(12)
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 20)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)

                Spacer()
                    .frame(height: 24)
            }
            .padding(.horizontal, 18)
        }
        .onAppear {
            hasAppeared = true
        }
    }
}

enum BrandPalette {
    static let backgroundTop = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let backgroundBottom = Color(red: 0.98, green: 0.95, blue: 0.95)

    static let primary = Color(red: 0.12, green: 0.42, blue: 0.79)
    static let secondary = Color(red: 0.16, green: 0.57, blue: 0.67)
    static let control = Color(red: 0.16, green: 0.49, blue: 0.72)

    static let success = Color(red: 0.20, green: 0.58, blue: 0.36)
    static let hint = Color(red: 0.78, green: 0.38, blue: 0.40)
    static let trophy = Color(red: 0.90, green: 0.70, blue: 0.20)

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let disabled = Color.gray
}
