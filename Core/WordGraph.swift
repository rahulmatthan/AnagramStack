//
//  WordGraph.swift
//  AnagramStack - Core
//
//  Pre-computed graph of all valid anagram progressions
//  Based on signature-based approach from Anagame
//

import Foundation
import Combine

/// Represents the complete graph of possible anagram progressions
@MainActor
final class WordGraph {
    // MARK: - Types

    /// A signature is the sorted letters of a word (e.g., "apt" for "pat", "tap", "apt")
    typealias Signature = String

    // MARK: - Properties

    /// Map of signature → all words that can be formed from those letters
    private var wordsBySignature: [Signature: Set<String>] = [:]

    /// Map of signature → all signatures reachable by adding one letter
    private var nextBySignature: [Signature: [Signature]] = [:]

    /// Cache for canReach queries
    private var canReachCache: [String: Bool] = [:]

    /// All 3-letter signatures that can reach 8 letters
    private(set) var viableStarts: [Signature] = []

    /// Dictionary reference
    private let dictionary: WordDictionary

    // MARK: - Constants

    private let minLength = 3
    private let maxLength = 8

    // MARK: - Initialization

    init(dictionary: WordDictionary) {
        self.dictionary = dictionary
    }

    /// Build the complete word graph
    /// This is computationally expensive but only done once
    func buildGraph() {
        print("🔨 Building word graph...")
        let startTime = Date()

        // Step 1: Group words by signature and length
        var signaturesByLength: [Int: Set<Signature>] = [:]
        for length in minLength...maxLength {
            signaturesByLength[length] = Set<Signature>()
        }

        // Get all words from dictionary and group by signature
        let allWords = dictionary.allWords()
        print("📚 Dictionary contains \(allWords.count) total words")

        for word in allWords {
            let sig = signature(of: word)
            signaturesByLength[word.count]?.insert(sig)

            if wordsBySignature[sig] == nil {
                wordsBySignature[sig] = Set<String>()
            }
            wordsBySignature[sig]?.insert(word)
        }

        print("📊 Found \(wordsBySignature.count) unique signatures")
        for length in minLength...maxLength {
            let count = signaturesByLength[length]?.count ?? 0
            print("   Length \(length): \(count) signatures")
        }

        // Step 2: Build connections (signature → next signatures)
        for length in minLength..<maxLength {
            guard let parentSigs = signaturesByLength[length],
                  let childSigs = signaturesByLength[length + 1] else { continue }

            for childSig in childSigs {
                // For each position, try removing one letter to find parent
                for i in 0..<childSig.count {
                    let parentSig = childSig.removing(at: i)

                    if parentSigs.contains(parentSig) {
                        if nextBySignature[parentSig] == nil {
                            nextBySignature[parentSig] = []
                        }
                        if !nextBySignature[parentSig]!.contains(childSig) {
                            nextBySignature[parentSig]!.append(childSig)
                        }
                    }
                }
            }
        }

        print("🔗 Built \(nextBySignature.count) signature connections")

        // Step 3: Find all 3-letter signatures that can reach 8 letters
        let threeLetterSigs = signaturesByLength[minLength] ?? Set<Signature>()
        print("🔍 Testing \(threeLetterSigs.count) three-letter signatures for viability...")

        var testedCount = 0
        var viableCount = 0
        viableStarts = threeLetterSigs.filter { sig in
            testedCount += 1
            let canReach = canReachLength(signature: sig, currentLength: minLength, targetLength: maxLength)
            if canReach {
                viableCount += 1
                if viableCount <= 5 {
                    print("   ✓ \(sig) can reach 8 letters")
                }
            }
            return canReach
        }.sorted()

        print("✅ Found \(viableStarts.count) viable starting signatures (tested \(testedCount))")

        let elapsed = Date().timeIntervalSince(startTime)
        print("⏱️  Graph built in \(String(format: "%.2f", elapsed))s")
    }

    // MARK: - Query Methods

    /// Get all possible next signatures from a given signature
    func nextSignatures(from signature: Signature) -> [Signature] {
        return nextBySignature[signature] ?? []
    }

    /// Get all words that match a signature
    func words(for signature: Signature) -> [String] {
        guard let words = wordsBySignature[signature] else { return [] }
        return sortWordsByQuality(Array(words))
    }

    /// Get the best representative word for a signature
    func representativeWord(for signature: Signature) -> String? {
        return words(for: signature).first
    }

    /// Check if a signature can reach a target length
    func canReachLength(signature: Signature, currentLength: Int, targetLength: Int) -> Bool {
        let cacheKey = "\(currentLength):\(signature)"

        if let cached = canReachCache[cacheKey] {
            return cached
        }

        if currentLength == targetLength {
            canReachCache[cacheKey] = true
            return true
        }

        let children = nextBySignature[signature] ?? []
        let canReach = children.contains { childSig in
            canReachLength(signature: childSig, currentLength: currentLength + 1, targetLength: targetLength)
        }

        canReachCache[cacheKey] = canReach
        return canReach
    }

    /// Calculate difficulty score for a signature
    func difficultyScore(for signature: Signature) -> Double {
        let wordCount = Double(wordsBySignature[signature]?.count ?? 1)
        let representativeWord = self.representativeWord(for: signature) ?? signature
        let letterPenalty = self.letterPenalty(for: representativeWord)

        // More words = easier (lower score)
        // Common letters = easier (lower score)
        return (10.0 / max(1.0, wordCount)) + letterPenalty
    }

    // MARK: - Helper Methods

    /// Calculate the signature (sorted letters) of a word
    private func signature(of word: String) -> Signature {
        return String(word.uppercased().sorted())
    }

    /// Sort words by quality (common words first)
    private func sortWordsByQuality(_ words: [String]) -> [String] {
        return words.sorted { word1, word2 in
            let penalty1 = letterPenalty(for: word1)
            let penalty2 = letterPenalty(for: word2)

            if penalty1 != penalty2 {
                return penalty1 < penalty2  // Lower penalty = better
            }

            return word1 < word2  // Alphabetical as tiebreaker
        }
    }

    /// Calculate letter penalty (higher = worse)
    /// Penalizes rare letters and duplicates
    private func letterPenalty(for word: String) -> Double {
        let rare: Set<Character> = ["J", "Q", "X", "Z"]
        let uncommon: Set<Character> = ["K", "V", "W", "Y"]

        var score: Double = 0.0
        var letterCounts: [Character: Int] = [:]

        for char in word.uppercased() {
            if rare.contains(char) {
                score += 1.8
            } else if uncommon.contains(char) {
                score += 0.7
            }

            letterCounts[char, default: 0] += 1
        }

        // Penalize duplicate letters
        for (_, count) in letterCounts where count > 1 {
            score += Double(count - 1) * 0.35
        }

        return score
    }
}

// MARK: - String Extension

private extension String {
    /// Remove character at index and return sorted result
    func removing(at index: Int) -> String {
        var chars = Array(self)
        chars.remove(at: index)
        return String(chars)
    }
}
