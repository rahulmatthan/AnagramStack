//
//  SavedProgress.swift
//  AnagramStackClient
//
//  Model for persisting game progress to UserDefaults
//

import Foundation

struct SavedProgress: Codable {
    let chainId: UUID
    let gameState: GameState
    let timestamp: Date

    private static let storageKey = "com.anagramstack.savedProgressByChain"
    private static let legacyStorageKey = "com.anagramstack.savedProgress"

    private static func loadAll() -> [String: SavedProgress] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let progressByChain = try? JSONDecoder().decode([String: SavedProgress].self, from: data) {
            return progressByChain
        }

        // One-time migration path for older single-progress format.
        if let legacyData = UserDefaults.standard.data(forKey: legacyStorageKey),
           let legacyProgress = try? JSONDecoder().decode(SavedProgress.self, from: legacyData) {
            let migrated = [legacyProgress.chainId.uuidString: legacyProgress]
            saveAll(migrated)
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            return migrated
        }

        return [:]
    }

    private static func saveAll(_ progressByChain: [String: SavedProgress]) {
        guard let encoded = try? JSONEncoder().encode(progressByChain) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    /// Save progress to UserDefaults
    static func save(_ gameState: GameState) {
        let progress = SavedProgress(
            chainId: gameState.chainId,
            gameState: gameState,
            timestamp: Date()
        )
        var allProgress = loadAll()
        allProgress[gameState.chainId.uuidString] = progress
        saveAll(allProgress)
    }

    /// Load saved progress for a specific chain.
    static func load(for chain: AnagramChain) -> SavedProgress? {
        return loadAll()[chain.id.uuidString]
    }

    /// Load resumable game state for a chain.
    static func loadResumableGameState(for chain: AnagramChain) -> GameState? {
        guard let saved = load(for: chain) else { return nil }
        let totalLevels = chain.levels.count
        guard saved.gameState.currentRowIndex < totalLevels else { return nil }
        return saved.gameState
    }

    /// Clear saved progress for a specific chain.
    static func clear(for chainId: UUID) {
        var allProgress = loadAll()
        allProgress.removeValue(forKey: chainId.uuidString)
        saveAll(allProgress)
    }

    /// Check if there's a saved game for a specific chain.
    static func hasSavedGame(for chain: AnagramChain) -> Bool {
        return loadResumableGameState(for: chain) != nil
    }

    /// Check if a chain has been completed.
    static func isCompleted(for chain: AnagramChain) -> Bool {
        guard let saved = load(for: chain) else { return false }
        return saved.gameState.currentRowIndex >= chain.levels.count
    }

    /// Return completion percentage for a chain (0.0-1.0), if any progress exists.
    static func completionRatio(for chain: AnagramChain) -> Double? {
        guard let saved = load(for: chain), chain.levels.count > 0 else { return nil }
        let ratio = Double(saved.gameState.completedRows.count) / Double(chain.levels.count)
        return min(max(ratio, 0.0), 1.0)
    }

    /// Return completed run time in seconds.
    static func completedElapsedSeconds(for chain: AnagramChain) -> Int? {
        guard isCompleted(for: chain), let saved = load(for: chain) else { return nil }
        return max(0, saved.gameState.elapsedSeconds)
    }

    static func formatElapsedTime(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let mins = clamped / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
