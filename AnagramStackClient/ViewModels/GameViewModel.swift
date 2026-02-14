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
    @Published var helpModeEnabled = false
    @Published var hintUses = 0

    // MARK: - Dependencies

    private let chain: AnagramChain
    private let dictionary: WordDictionary
    private var totalLevels: Int { chain.levels.count }
    private var timerTask: Task<Void, Never>?

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

    deinit {
        timerTask?.cancel()
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
        if isGameComplete {
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

        guard isTileMovable(at: sourceIndex),
              isTileMovable(at: targetIndex) else {
            return
        }

        swapTiles(at: sourceIndex, with: targetIndex)
    }

    /// Handle tap-to-swap interaction
    func handleTileTap(_ tileId: UUID) {
        guard tapToSwapMode else { return }
        guard let tappedIndex = currentTiles.firstIndex(where: { $0.id == tileId }) else { return }
        guard isTileMovable(at: tappedIndex) else { return }

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
        guard index1 != index2 else { return }
        guard isTileMovable(at: index1),
              isTileMovable(at: index2) else {
            return
        }

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
        let movableIndices = currentTiles.indices.filter { isTileMovable(at: $0) }
        guard movableIndices.count > 1 else { return }

        var movableLetters = movableIndices.map { currentTiles[$0].letter }
        movableLetters.shuffle()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            for (offset, tileIndex) in movableIndices.enumerated() {
                currentTiles[tileIndex].letter = movableLetters[offset]
            }
        }
        firstTappedTile = nil // Clear any selection
    }

    func activateHelp() {
        guard !isGameComplete else { return }
        helpModeEnabled = true
        firstTappedTile = nil
    }

    func applyShuffleHint() {
        guard helpModeEnabled, canUseShuffleHint else { return }
        guard let targetWord = currentIntendedWord()?.uppercased() else { return }
        let targetLetters = Array(targetWord)
        guard targetLetters.count == currentTiles.count else { return }

        let existingLocked = Set(currentTiles.indices.filter { currentTiles[$0].isHintLocked })
        let incorrectMovable = currentTiles.indices.filter {
            !currentTiles[$0].isHintLocked && currentTiles[$0].letter != targetLetters[$0]
        }

        if incorrectMovable.isEmpty {
            hintUses = min(2, hintUses + 1)
            gameState.hintsUsedCount += 1
            gameState.lastUpdated = Date()
            SavedProgress.save(gameState)
            return
        }

        let revealCount = max(1, Int(ceil(Double(currentTiles.count) / 3.0)))
        let newlyLocked = Set(incorrectMovable.shuffled().prefix(revealCount))
        let lockedIndices = existingLocked.union(newlyLocked)

        var letterCounts: [Character: Int] = [:]
        for tile in currentTiles {
            letterCounts[tile.letter, default: 0] += 1
        }

        // Reserve required target letters for locked positions.
        for index in lockedIndices.sorted() {
            let target = targetLetters[index]
            let available = letterCounts[target, default: 0]
            guard available > 0 else { return }
            letterCounts[target] = available - 1
        }

        var remainingLetters: [Character] = []
        for (letter, count) in letterCounts where count > 0 {
            remainingLetters.append(contentsOf: Array(repeating: letter, count: count))
        }
        remainingLetters.shuffle()

        var remainingIndex = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            for index in currentTiles.indices {
                if lockedIndices.contains(index) {
                    currentTiles[index].letter = targetLetters[index]
                    currentTiles[index].isHintLocked = true
                } else {
                    currentTiles[index].letter = remainingLetters[remainingIndex]
                    currentTiles[index].isHintLocked = false
                    remainingIndex += 1
                }
                currentTiles[index].position = index
            }
        }

        hintUses = min(2, hintUses + 1)
        gameState.hintsUsedCount += 1
        gameState.lastUpdated = Date()
        firstTappedTile = nil
        SavedProgress.save(gameState)
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
        if isGameComplete {
            pauseSolvingTimer()
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
                    helpModeEnabled = false
                    hintUses = 0
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
        pauseSolvingTimer()
        gameState = GameState(chainId: chain.id)
        completedRows.removeAll()
        currentTiles.removeAll()
        showingWinScreen = false
        firstTappedTile = nil
        helpModeEnabled = false
        hintUses = 0

        SavedProgress.clear(for: chain.id)
        setupGame()
    }

    /// Start (or resume) the active solving timer.
    func startSolvingTimer() {
        guard timerTask == nil, !isGameComplete else { return }

        timerTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                guard !self.isGameComplete else {
                    self.pauseSolvingTimer()
                    return
                }

                self.gameState.elapsedSeconds += 1
                self.gameState.lastUpdated = Date()
                SavedProgress.save(self.gameState)
            }
        }
    }

    /// Pause timer when user leaves the game screen.
    func pauseSolvingTimer() {
        timerTask?.cancel()
        timerTask = nil
        SavedProgress.save(gameState)
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
        guard totalLevels > 0 else { return 0 }
        return Double(gameState.completedRows.count) / Double(totalLevels)
    }

    /// Elapsed solve time text.
    var formattedElapsedTime: String {
        SavedProgress.formatElapsedTime(gameState.elapsedSeconds)
    }

    var canUseShuffleHint: Bool {
        return helpModeEnabled && hintUses < 2 && currentIntendedWord() != nil
    }

    /// Check if game is complete using the chain's actual level count.
    var isGameComplete: Bool {
        return gameState.currentRowIndex >= totalLevels || gameState.completedRows.count >= totalLevels
    }

    /// Get the current level number using the chain's actual level count.
    var currentLevelNumber: Int {
        return min(gameState.currentRowIndex + 1, max(totalLevels, 1))
    }

    private func currentIntendedWord() -> String? {
        guard gameState.currentRowIndex < chain.levels.count else { return nil }
        return chain.levels[gameState.currentRowIndex].intendedWord
    }

    private func isTileMovable(at index: Int) -> Bool {
        guard currentTiles.indices.contains(index) else { return false }
        let tile = currentTiles[index]
        return !tile.isLocked && !tile.isHintLocked
    }
}
