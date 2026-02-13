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

    static let storageKey = "com.anagramstack.savedProgress"

    /// Save progress to UserDefaults
    static func save(_ gameState: GameState) {
        let progress = SavedProgress(
            chainId: gameState.chainId,
            gameState: gameState,
            timestamp: Date()
        )

        if let encoded = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    /// Load saved progress from UserDefaults
    static func load() -> SavedProgress? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let progress = try? JSONDecoder().decode(SavedProgress.self, from: data) else {
            return nil
        }
        return progress
    }

    /// Clear saved progress
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Check if there's a saved game for a specific chain
    static func hasSavedGame(for chainId: UUID) -> Bool {
        guard let saved = load() else { return false }
        return saved.chainId == chainId && !saved.gameState.isComplete
    }
}
