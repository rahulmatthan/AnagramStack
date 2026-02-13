//
//  AnagramChain.swift
//  AnagramStack - Core
//
//  Container model for a complete 6-level anagram progression (3→8 letters)
//

import Foundation

struct AnagramChain: Codable, Identifiable, Equatable, Hashable {
    /// Unique identifier
    let id: UUID

    /// Display name for the chain
    var name: String

    /// Description of the chain
    var description: String

    /// Difficulty rating
    var difficulty: Difficulty

    /// Exactly 6 levels (3, 4, 5, 6, 7, 8 letters)
    var levels: [AnagramLevel]

    /// Creation timestamp
    let createdDate: Date

    /// Last modification timestamp
    var modifiedDate: Date

    /// Version identifier
    var version: String

    // MARK: - Nested Types

    enum Difficulty: String, Codable, CaseIterable {
        case easy = "easy"
        case medium = "medium"
        case hard = "hard"

        var displayName: String {
            rawValue.capitalized
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        difficulty: Difficulty = .medium,
        levels: [AnagramLevel] = [],
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        version: String = "1.0"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.levels = levels
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.version = version
    }

    // MARK: - Validation

    /// Check if the chain is complete and valid
    /// - Returns: true if all 6 levels are properly configured
    func isComplete() -> Bool {
        // Must have exactly 6 levels
        guard levels.count == 6 else { return false }

        // Check each level
        for (index, level) in levels.enumerated() {
            // Verify letter count matches expected progression (3, 4, 5, 6, 7, 8)
            let expectedLetterCount = index + 3
            guard level.letterCount == expectedLetterCount else { return false }

            // Validate the level itself
            guard level.isValid() else { return false }

            // First level must have letters defined
            if index == 0 {
                guard level.letters != nil else { return false }
            } else {
                // Subsequent levels must have addedLetter defined
                guard level.addedLetter != nil else { return false }
            }
        }

        return true
    }

    /// Get validation errors for debugging
    /// - Returns: Array of error descriptions
    func validationErrors() -> [String] {
        var errors: [String] = []

        if levels.count != 6 {
            errors.append("Chain must have exactly 6 levels (has \(levels.count))")
        }

        for (index, level) in levels.enumerated() {
            let expectedLetterCount = index + 3

            if level.letterCount != expectedLetterCount {
                errors.append("Level \(index + 1): Expected \(expectedLetterCount) letters, has \(level.letterCount)")
            }

            if !level.isValid() {
                errors.append("Level \(index + 1): Invalid level configuration")
            }

            // First level must have letters
            if index == 0 {
                if level.letters == nil {
                    errors.append("Level 1: Must have starting letters defined")
                }
            } else {
                // Subsequent levels must have addedLetter
                if level.addedLetter == nil {
                    errors.append("Level \(index + 1): Must have addedLetter defined")
                }
            }
        }

        return errors
    }

    // MARK: - Helper Methods

    /// Get a specific level by letter count
    /// - Parameter letterCount: Number of letters (3-8)
    /// - Returns: The level if found
    func level(withLetterCount letterCount: Int) -> AnagramLevel? {
        return levels.first { $0.letterCount == letterCount }
    }

    /// Get progress percentage (0.0 - 1.0)
    /// - Returns: Ratio of complete levels to total levels
    func progress() -> Double {
        let completeLevels = levels.filter { $0.isValid() }.count
        return Double(completeLevels) / 6.0
    }
}

// MARK: - JSON Encoding/Decoding Extensions

extension AnagramChain {
    /// Encode to JSON data
    /// - Throws: Encoding error
    /// - Returns: JSON data
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Decode from JSON data
    /// - Parameter data: JSON data
    /// - Throws: Decoding error
    /// - Returns: AnagramChain instance
    static func fromJSON(_ data: Data) throws -> AnagramChain {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AnagramChain.self, from: data)
    }

    /// Save to file
    /// - Parameter url: File URL to save to
    /// - Throws: Encoding or file writing error
    func save(to url: URL) throws {
        let data = try toJSON()
        try data.write(to: url)
    }

    /// Load from file
    /// - Parameter url: File URL to load from
    /// - Throws: File reading or decoding error
    /// - Returns: AnagramChain instance
    static func load(from url: URL) throws -> AnagramChain {
        let data = try Data(contentsOf: url)
        return try fromJSON(data)
    }
}
