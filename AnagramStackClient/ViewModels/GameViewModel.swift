//
//  GameViewModel.swift
//  AnagramStackClient
//
//  Main game logic and state management
//

import Foundation
import SwiftUI
import Combine

@MainActor
class GameViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var gameState: GameState
    @Published var currentTiles: [LetterTile] = []
    @Published var completedRows: [[LetterTile]] = []

    // UI State
    @Published var showingValidFeedback = false
    @Published var showingInvalidFeedback = false
    @Published var feedbackMessage = ""
    @Published var droppingToNextRow = false
    @Published var showingWinScreen = false

    // Interaction Mode
    @Published var tapToSwapMode = true // Default to tap mode
    @Published var firstTappedTile: UUID?

    // MARK: - Dependencies

    private let chain: AnagramChain
    private let dictionary: WordDictionary

    // MARK: - Initialization

    init(chain: AnagramChain, dictionary: WordDictionary = .shared, savedState: GameState? = nil) {
        self.chain = chain
        self.dictionary = dictionary

        if let saved = savedState {
            self.gameState = saved
        } else {
            self.gameState = GameState(chainId: chain.id)
        }

        setupGame()
    }

    // MARK: - Game Setup

    private func setupGame() {
        // Restore completed rows
        completedRows.removeAll()
        for completedRow in gameState.completedRows {
            let tiles = LetterTile.tiles(from: completedRow.submittedWord, isLocked: true)
            completedRows.append(tiles)
        }

        // Setup current row
        if gameState.currentRowIndex < chain.levels.count {
            let currentLevel = chain.levels[gameState.currentRowIndex]

            // First level: use the defined letters
            if gameState.currentRowIndex == 0 {
                if let letters = currentLevel.letters {
                    currentTiles = LetterTile.tiles(from: letters)
                }
            } else {
                // Subsequent levels: use previous solved word + added letter
                if let previousRow = gameState.completedRows.last,
                   let addedLetter = currentLevel.addedLetter {
                    let newLetters = previousRow.submittedWord + addedLetter
                    currentTiles = LetterTile.tiles(from: newLetters)
                }
            }
        }

        // Check if game is already won
        if gameState.isComplete {
            showingWinScreen = true
        }
    }

    // MARK: - Tile Interaction

    /// Handle drag and drop tile swap
    func handleDrop(from sourceId: UUID, to targetId: UUID) {
        guard let sourceIndex = currentTiles.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = currentTiles.firstIndex(where: { $0.id == targetId }) else {
            return
        }

        swapTiles(at: sourceIndex, with: targetIndex)
    }

    /// Handle tap-to-swap interaction
    func handleTileTap(_ tileId: UUID) {
        guard tapToSwapMode else { return }

        if let firstTile = firstTappedTile {
            // Second tap - swap tiles
            if firstTile != tileId {
                guard let firstIndex = currentTiles.firstIndex(where: { $0.id == firstTile }),
                      let secondIndex = currentTiles.firstIndex(where: { $0.id == tileId }) else {
                    return
                }

                swapTiles(at: firstIndex, with: secondIndex)
            }

            // Clear selection
            firstTappedTile = nil
        } else {
            // First tap - select tile
            firstTappedTile = tileId
        }
    }

    /// Swap two tiles with animation
    private func swapTiles(at index1: Int, with index2: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentTiles.swapAt(index1, index2)

            // Update positions
            currentTiles[index1].position = index1
            currentTiles[index2].position = index2
        }
    }

    /// Toggle interaction mode
    func toggleInteractionMode() {
        tapToSwapMode.toggle()
        firstTappedTile = nil
    }

    /// Shuffle the current tiles for inspiration
    func shuffleTiles() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            currentTiles.shuffle()
            // Update positions after shuffle
            for (index, _) in currentTiles.enumerated() {
                currentTiles[index].position = index
            }
        }
        firstTappedTile = nil // Clear any selection
    }

    // MARK: - Word Submission

    /// Submit the current word for validation
    func submitWord() async {
        let submittedWord = String(currentTiles.map { $0.letter })

        // Validate word
        if isValidSubmission(submittedWord) {
            await handleValidWord(submittedWord)
        } else {
            await handleInvalidWord()
        }
    }

    /// Check if the submitted word is valid
    private func isValidSubmission(_ word: String) -> Bool {
        // Must exist in dictionary
        guard dictionary.contains(word) else {
            return false
        }

        // Must be a valid anagram of current letters
        let currentLetters = currentTiles.map { $0.letter }
        return isValidAnagram(word, letters: currentLetters)
    }

    /// Check if word is a valid anagram of the letters
    private func isValidAnagram(_ word: String, letters: [Character]) -> Bool {
        let wordChars = Array(word.uppercased())
        var availableLetters = letters.map { Character($0.uppercased()) }

        for char in wordChars {
            if let index = availableLetters.firstIndex(of: char) {
                availableLetters.remove(at: index)
            } else {
                return false
            }
        }

        return availableLetters.isEmpty
    }

    /// Handle valid word submission
    private func handleValidWord(_ word: String) async {
        // Show valid feedback
        feedbackMessage = "Great! \(word) is valid!"
        showingValidFeedback = true

        // Wait for feedback
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s

        showingValidFeedback = false

        // Lock current tiles
        let lockedTiles = currentTiles.map { tile in
            var locked = tile
            locked.isLocked = true
            return locked
        }

        // Animate drop to next row
        droppingToNextRow = true

        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s

        // Update game state
        completedRows.append(lockedTiles)

        let completedRow = GameState.CompletedRow(
            levelIndex: gameState.currentRowIndex,
            letters: String(currentTiles.map { $0.letter }),
            submittedWord: word,
            timestamp: Date()
        )
        gameState.completedRows.append(completedRow)
        gameState.currentRowIndex += 1
        gameState.lastUpdated = Date()

        // Save progress
        SavedProgress.save(gameState)

        droppingToNextRow = false

        // Check if won
        if gameState.isComplete {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            showingWinScreen = true
        } else {
            // Setup next level using the SOLVED word + new letter
            if gameState.currentRowIndex < chain.levels.count {
                let nextLevel = chain.levels[gameState.currentRowIndex]

                // Get the added letter from the level definition
                if let addedLetter = nextLevel.addedLetter {
                    // Create next level as: solved word + new letter
                    let newLetters = word.uppercased() + addedLetter.uppercased()
                    currentTiles = LetterTile.tiles(from: newLetters)
                }
            }
        }
    }

    /// Handle invalid word submission
    private func handleInvalidWord() async {
        feedbackMessage = "Not a valid word!"
        showingInvalidFeedback = true

        // Shake animation handled in view

        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s

        showingInvalidFeedback = false
    }

    // MARK: - Game Actions

    /// Restart the current chain
    func restartGame() {
        gameState = GameState(chainId: chain.id)
        completedRows.removeAll()
        currentTiles.removeAll()
        showingWinScreen = false
        firstTappedTile = nil

        SavedProgress.clear()
        setupGame()
    }

    /// Get current level info
    var currentLevelInfo: String {
        if gameState.currentRowIndex < chain.levels.count {
            let level = chain.levels[gameState.currentRowIndex]
            return "\(level.letterCount) Letters"
        }
        return ""
    }

    /// Get progress percentage
    var progressPercentage: Double {
        return gameState.progress
    }
}
