//
//  LetterSuggestionEngine.swift
//  AnagramStackAdmin
//
//  Engine for suggesting which letters can be added at each level
//  while ensuring a viable path to 8 letters exists.
//

import Foundation
import Combine

/// Suggestion for adding a letter to progress to the next level
struct LetterSuggestion: Identifiable {
    let id = UUID()
    let letter: Character
    let resultingLetters: String
    let validWords: [String]
    let viabilityScore: Double  // 0.0 - 1.0
    let nextLevelViable: Bool
    let vowelRatio: Double
    let letterFrequencyScore: Double

    /// Color indicator based on viability score
    var viabilityColor: String {
        if viabilityScore >= 0.7 { return "green" }
        if viabilityScore >= 0.4 { return "yellow" }
        return "red"
    }
}

@MainActor
class LetterSuggestionEngine: ObservableObject {
    // MARK: - Published Properties

    @Published var suggestions: [LetterSuggestion] = []
    @Published var isGenerating = false

    // MARK: - Dependencies

    private let dictionary: WordDictionary

    // MARK: - Constants

    // Common English letter frequency (E, T, A, O, I, N, S, H, R, D, L, U)
    private let highFrequencyLetters: Set<Character> = ["E", "T", "A", "O", "I", "N", "S", "H", "R", "D", "L", "U"]
    private let vowels: Set<Character> = ["A", "E", "I", "O", "U"]

    // Ideal vowel ratio for word formation
    private let idealVowelRatioMin: Double = 0.30
    private let idealVowelRatioMax: Double = 0.45

    // MARK: - Initialization

    init(dictionary: WordDictionary = .shared) {
        self.dictionary = dictionary
    }

    // MARK: - Dictionary Helpers

    /// Check if a word exists in the dictionary
    func contains(_ word: String) -> Bool {
        return dictionary.contains(word)
    }

    // MARK: - Suggestion Generation

    /// Generate letter suggestions for the next level
    /// - Parameters:
    ///   - currentLetters: Current letters at this level
    ///   - targetLetterCount: Target letter count for next level
    /// - Returns: Array of suggestions sorted by viability score
    func generateSuggestions(from currentLetters: String, targetLetterCount: Int) async -> [LetterSuggestion] {
        isGenerating = true
        defer { isGenerating = false }

        var results: [LetterSuggestion] = []
        let currentLetters = currentLetters.uppercased()

        // Try adding each letter A-Z
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            let newLetters = currentLetters + String(letter)

            // Find all valid words at this level
            var validWords = dictionary.findAnagrams(from: newLetters)

            // Sort words to show most common/recognizable first
            validWords = sortWordsByCommonality(validWords)

            // Skip if no valid words can be formed
            guard !validWords.isEmpty else { continue }

            // Calculate scores
            let vowelRatio = calculateVowelRatio(newLetters)
            let vowelScore = calculateVowelScore(vowelRatio)
            let letterFreqScore = calculateLetterFrequencyScore(letter)

            // Check viability of next level (if not at final level)
            var nextLevelScore: Double = 1.0
            var nextLevelViable = true

            if targetLetterCount < 8 {
                // For each valid word at current level, check if we can progress
                var viablePathsCount = 0
                let sampleSize = min(validWords.count, 5) // Sample up to 5 words for performance

                for word in validWords.prefix(sampleSize) {
                    if await hasViableNextLevel(from: word, targetCount: targetLetterCount + 1) {
                        viablePathsCount += 1
                    }
                }

                nextLevelScore = Double(viablePathsCount) / Double(sampleSize)
                nextLevelViable = viablePathsCount > 0
            }

            // Calculate overall viability score (weighted average)
            let viabilityScore = (
                vowelScore * 0.35 +
                nextLevelScore * 0.45 +
                letterFreqScore * 0.20
            )

            let suggestion = LetterSuggestion(
                letter: letter,
                resultingLetters: newLetters,
                validWords: validWords,
                viabilityScore: viabilityScore,
                nextLevelViable: nextLevelViable,
                vowelRatio: vowelRatio,
                letterFrequencyScore: letterFreqScore
            )

            results.append(suggestion)
        }

        // Sort by viability score (highest first)
        results.sort { $0.viabilityScore > $1.viabilityScore }

        await MainActor.run {
            self.suggestions = results
        }

        return results
    }

    // MARK: - Scoring Algorithms

    /// Calculate vowel ratio in the letters
    private func calculateVowelRatio(_ letters: String) -> Double {
        let letterCount = Double(letters.count)
        guard letterCount > 0 else { return 0.0 }

        let vowelCount = Double(letters.filter { vowels.contains($0) }.count)
        return vowelCount / letterCount
    }

    /// Score based on proximity to ideal vowel ratio
    private func calculateVowelScore(_ ratio: Double) -> Double {
        if ratio >= idealVowelRatioMin && ratio <= idealVowelRatioMax {
            return 1.0
        }

        // Calculate distance from ideal range
        let distance: Double
        if ratio < idealVowelRatioMin {
            distance = idealVowelRatioMin - ratio
        } else {
            distance = ratio - idealVowelRatioMax
        }

        // Exponential penalty for distance
        return max(0.0, 1.0 - (distance * 2.5))
    }

    /// Score based on letter frequency in English
    private func calculateLetterFrequencyScore(_ letter: Character) -> Double {
        return highFrequencyLetters.contains(letter) ? 1.0 : 0.5
    }

    /// Check if adding another letter to current word can form valid words
    private func hasViableNextLevel(from letters: String, targetCount: Int) async -> Bool {
        // Try adding a few common letters to see if we can form words
        let testLetters: [Character] = ["E", "S", "R", "T", "A", "I", "N"]

        for letter in testLetters {
            let testWord = letters + String(letter)
            let words = dictionary.findAnagrams(from: testWord)

            if !words.isEmpty {
                return true
            }
        }

        return false
    }

    // MARK: - Helper Methods

    /// Sort words to prioritize common/recognizable words
    /// Strategy: Prefer words that are alphabetically earlier (tend to be more common)
    /// and use all available letters (no weird short forms)
    private func sortWordsByCommonality(_ words: [String]) -> [String] {
        return words.sorted { word1, word2 in
            // First priority: prefer words that use all letters (longer is better)
            if word1.count != word2.count {
                return word1.count > word2.count
            }
            // Second priority: alphabetical (earlier words tend to be more common)
            return word1 < word2
        }
    }

    /// Get top N suggestions
    func topSuggestions(_ count: Int) -> [LetterSuggestion] {
        return Array(suggestions.prefix(count))
    }

    /// Get only viable suggestions (score >= 0.4)
    func viableSuggestions() -> [LetterSuggestion] {
        return suggestions.filter { $0.viabilityScore >= 0.4 }
    }

    /// Get suggestions by color category
    func suggestions(by color: String) -> [LetterSuggestion] {
        return suggestions.filter { $0.viabilityColor == color }
    }
}

// MARK: - Batch Processing

extension LetterSuggestionEngine {
    /// Generate a complete chain suggestion from a starting word
    /// - Parameter startWord: 3-letter starting word
    /// - Returns: Array of suggested levels (best path)
    func generateCompleteChain(from startWord: String) async -> [AnagramLevel]? {
        guard startWord.count == 3 else { return nil }
        guard dictionary.contains(startWord) else { return nil }

        var levels: [AnagramLevel] = []

        // Create first level
        let firstLevel = AnagramLevel(
            letterCount: 3,
            letters: startWord.uppercased(),
            intendedWord: startWord.uppercased()
        )
        levels.append(firstLevel)

        // Generate levels 4-8
        var currentIntendedWord = startWord.uppercased()
        for targetCount in 4...8 {
            let suggestions = await generateSuggestions(from: currentIntendedWord, targetLetterCount: targetCount)

            // Get the best viable suggestion
            guard let best = suggestions.first(where: { $0.viabilityScore >= 0.4 }) else {
                // No viable path found
                return nil
            }

            // Get the added letter
            let addedLetter = String(best.letter)

            // Get an intended word for this level
            guard let intendedWord = best.validWords.first else {
                return nil
            }

            let level = AnagramLevel(
                letterCount: targetCount,
                addedLetter: addedLetter,
                intendedWord: intendedWord
            )

            levels.append(level)
            currentIntendedWord = intendedWord
        }

        return levels
    }
}
