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

    /// Total active solve time in seconds.
    var elapsedSeconds: Int

    /// Total hints used across this chain run.
    var hintsUsedCount: Int

    struct CompletedRow: Codable, Equatable {
        let levelIndex: Int
        let letters: String
        let submittedWord: String
        let timestamp: Date
    }

    init(
        chainId: UUID,
        currentRowIndex: Int = 0,
        completedRows: [CompletedRow] = [],
        lastUpdated: Date = Date(),
        elapsedSeconds: Int = 0,
        hintsUsedCount: Int = 0
    ) {
        self.chainId = chainId
        self.currentRowIndex = currentRowIndex
        self.completedRows = completedRows
        self.lastUpdated = lastUpdated
        self.elapsedSeconds = elapsedSeconds
        self.hintsUsedCount = hintsUsedCount
    }

    private enum CodingKeys: String, CodingKey {
        case chainId
        case currentRowIndex
        case completedRows
        case lastUpdated
        case elapsedSeconds
        case hintsUsedCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chainId = try container.decode(UUID.self, forKey: .chainId)
        currentRowIndex = try container.decode(Int.self, forKey: .currentRowIndex)
        completedRows = try container.decode([CompletedRow].self, forKey: .completedRows)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        elapsedSeconds = try container.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0
        hintsUsedCount = try container.decodeIfPresent(Int.self, forKey: .hintsUsedCount) ?? 0
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
