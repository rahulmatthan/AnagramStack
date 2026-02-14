//
//  LetterTile.swift
//  AnagramStackClient
//
//  Model representing a single letter tile in the game
//

import Foundation

struct LetterTile: Identifiable, Equatable {
    let id: UUID
    var letter: Character
    var position: Int
    var isLocked: Bool // true for completed rows
    var isHintLocked: Bool // true for hint-fixed letters in current row

    init(id: UUID = UUID(), letter: Character, position: Int, isLocked: Bool = false, isHintLocked: Bool = false) {
        self.id = id
        self.letter = letter
        self.position = position
        self.isLocked = isLocked
        self.isHintLocked = isHintLocked
    }
}

extension LetterTile {
    /// Create tiles from a string
    static func tiles(from letters: String, startPosition: Int = 0, isLocked: Bool = false) -> [LetterTile] {
        return letters.enumerated().map { index, char in
            LetterTile(
                letter: char.uppercased().first ?? " ",
                position: startPosition + index,
                isLocked: isLocked,
                isHintLocked: false
            )
        }
    }
}
