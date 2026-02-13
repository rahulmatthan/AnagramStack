//
//  AnagramLevel.swift
//  AnagramStack - Core
//
//  Single level in an anagram chain progression (3-8 letters)
//

import Foundation

struct AnagramLevel: Codable, Identifiable, Equatable, Hashable {
    /// Unique identifier
    let id: UUID

    /// Number of letters in this level (3-8)
    let letterCount: Int

    /// For first level: the starting letters (e.g., "CAT")
    /// For other levels: optional (built from previous + addedLetter)
    var letters: String?

    /// The letter added at this level (nil for first level)
    var addedLetter: String?

    /// Suggested solution word (optional hint, NOT enforced)
    /// Any valid dictionary word that's an anagram of the letters is accepted
    var intendedWord: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        letterCount: Int,
        letters: String? = nil,
        addedLetter: String? = nil,
        intendedWord: String? = nil
    ) {
        self.id = id
        self.letterCount = letterCount
        self.letters = letters?.uppercased()
        self.addedLetter = addedLetter?.uppercased()
        self.intendedWord = intendedWord?.uppercased()
    }

    // MARK: - Validation

    /// Validate that this level is properly configured
    /// - Returns: true if level is valid
    func isValid() -> Bool {
        // Check letter count is in valid range
        guard (3...8).contains(letterCount) else { return false }

        // First level must have letters specified
        if letterCount == 3 {
            guard let letters = letters, letters.count == 3 else { return false }
        } else {
            // Other levels must have addedLetter
            guard let added = addedLetter, added.count == 1 else { return false }
        }

        return true
    }
}
