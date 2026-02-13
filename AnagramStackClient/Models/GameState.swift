//
//  GameState.swift
//  AnagramStackClient
//
//  Model representing the current game state
//

import Foundation

struct GameState: Codable, Equatable {
    /// The anagram chain being played
    var chainId: UUID

    /// Current row index (0-5 for levels 1-6)
    var currentRowIndex: Int

    /// Completed rows with their letters
    var completedRows: [CompletedRow]

    /// Current progress timestamp
    var lastUpdated: Date

    struct CompletedRow: Codable, Equatable {
        let levelIndex: Int
        let letters: String
        let submittedWord: String
        let timestamp: Date
    }

    init(chainId: UUID, currentRowIndex: Int = 0, completedRows: [CompletedRow] = [], lastUpdated: Date = Date()) {
        self.chainId = chainId
        self.currentRowIndex = currentRowIndex
        self.completedRows = completedRows
        self.lastUpdated = lastUpdated
    }

    /// Check if game is complete
    var isComplete: Bool {
        return currentRowIndex >= 6 || completedRows.count >= 6
    }

    /// Get the current level number (1-6)
    var currentLevel: Int {
        return currentRowIndex + 1
    }

    /// Get progress percentage (0.0 - 1.0)
    var progress: Double {
        return Double(completedRows.count) / 6.0
    }
}
