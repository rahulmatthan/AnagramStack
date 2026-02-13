//
//  Dictionary.swift
//  AnagramStack - Core
//
//  Trie-based dictionary for fast word validation and anagram finding
//

import Foundation

/// Trie node for efficient word storage and lookup
class TrieNode {
    var children: [Character: TrieNode] = [:]
    var isEndOfWord: Bool = false
}

/// Dictionary service using Trie data structure for O(L) word lookups
final class WordDictionary: @unchecked Sendable {
    private let root = TrieNode()
    private var wordCount = 0

    /// Singleton instance
    static let shared = WordDictionary()

    private init() {}

    // MARK: - Loading

    /// Load dictionary from a text file (one word per line)
    /// - Parameter filename: Name of the file in Resources bundle
    /// - Throws: Error if file not found or cannot be read
    func loadFromFile(filename: String) throws {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            throw DictionaryError.fileNotFound(filename)
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let words = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }

        for word in words {
            insert(word)
        }
    }

    /// Load dictionary from a file path
    /// - Parameter path: Full path to dictionary file
    /// - Throws: Error if file cannot be read
    func loadFromPath(_ path: String) throws {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let words = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }

        for word in words {
            insert(word)
        }
    }

    // MARK: - Insertion

    /// Insert a word into the trie
    /// - Parameter word: Word to insert (will be uppercased)
    func insert(_ word: String) {
        let word = word.uppercased()
        var current = root

        for char in word {
            if current.children[char] == nil {
                current.children[char] = TrieNode()
            }
            current = current.children[char]!
        }

        if !current.isEndOfWord {
            current.isEndOfWord = true
            wordCount += 1
        }
    }

    // MARK: - Lookup

    /// Check if a word exists in the dictionary
    /// - Parameter word: Word to check (case-insensitive)
    /// - Returns: true if word exists
    func contains(_ word: String) -> Bool {
        let word = word.uppercased()
        var current = root

        for char in word {
            guard let next = current.children[char] else {
                return false
            }
            current = next
        }

        return current.isEndOfWord
    }

    // MARK: - Anagram Finding

    /// Find all valid words that can be formed from the given letters
    /// - Parameters:
    ///   - letters: String of available letters
    ///   - length: Optional length filter (returns only words of this length)
    /// - Returns: Array of valid words sorted alphabetically
    func findValidWords(from letters: String, length: Int? = nil) -> [String] {
        let letters = letters.uppercased()
        var results: Set<String> = []

        // Generate all permutations and check against dictionary
        if let targetLength = length {
            findWords(from: Array(letters), targetLength: targetLength, current: "", results: &results)
        } else {
            // Find words of all possible lengths
            for len in 1...letters.count {
                findWords(from: Array(letters), targetLength: len, current: "", results: &results)
            }
        }

        return Array(results).sorted()
    }

    /// Recursive helper to find words of specific length
    private func findWords(from letters: [Character], targetLength: Int, current: String, results: inout Set<String>) {
        // Base case: check if we've reached target length
        if current.count == targetLength {
            if contains(current) {
                results.insert(current)
            }
            return
        }

        // Try each available letter
        var remainingLetters = letters
        for (index, char) in letters.enumerated() {
            let newWord = current + String(char)
            remainingLetters.remove(at: index)
            findWords(from: remainingLetters, targetLength: targetLength, current: newWord, results: &results)
            remainingLetters.insert(char, at: index)
        }
    }

    /// Find all anagrams of exact length using all provided letters
    /// - Parameter letters: String of letters to use
    /// - Returns: Array of valid anagrams
    func findAnagrams(from letters: String) -> [String] {
        return findValidWords(from: letters, length: letters.count)
    }

    // MARK: - Info

    /// Get the number of words in the dictionary
    var count: Int {
        return wordCount
    }

    /// Get all words in the dictionary
    /// - Returns: Array of all words
    func allWords() -> [String] {
        var words: [String] = []
        collectWords(node: root, prefix: "", words: &words)
        return words
    }

    /// Recursively collect all words from the trie
    private func collectWords(node: TrieNode, prefix: String, words: inout [String]) {
        if node.isEndOfWord {
            words.append(prefix)
        }

        for (char, childNode) in node.children {
            collectWords(node: childNode, prefix: prefix + String(char), words: &words)
        }
    }
}

// MARK: - Error Types

enum DictionaryError: Error, LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "Dictionary file not found: \(filename)"
        }
    }
}
